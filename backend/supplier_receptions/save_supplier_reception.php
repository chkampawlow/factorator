<?php

header('Content-Type: application/json');

require_once __DIR__ . '/../config/response.php';
require_once __DIR__ . '/../config/db.php';
require_once __DIR__ . '/../config/idempotency.php';
require_once __DIR__ . '/../config/audit.php';
require_once __DIR__ . '/../auth/auth_required.php';
require_once __DIR__ . '/../auth/role_helper.php';
require_once __DIR__ . '/../config/tenant_scope.php';

require_once __DIR__ . '/../suppliers/supplier_service.php';
require_once __DIR__ . '/../supplier_orders/order_service.php';
require_once __DIR__ . '/reception_service.php';



function normalizeOptionalMysqlDateTime(string $value): string
{
    $trimmed = trim($value);
    if ($trimmed === '') {
        return '';
    }

    try {
        $dateTime = new DateTimeImmutable($trimmed);
        return $dateTime->format('Y-m-d H:i:s');
    } catch (Throwable $ignored) {
        return $trimmed;
    }
}

function normalizeSupplierReceptionMatchKeyPart(string $value): string
{
    return mb_strtolower(trim($value));
}

function supplierOrderMatchKeyFromRow(array $row): string
{
    $catalogId = (int)($row['catalog_id'] ?? 0);
    if ($catalogId > 0) {
        return 'catalog:' . $catalogId;
    }

    $code = normalizeSupplierReceptionMatchKeyPart((string)($row['product_code'] ?? ''));
    if ($code !== '') {
        return 'code:' . $code . '|type:' . normalizeSupplierOrderItemType((string)($row['item_type'] ?? 'PRODUCT'));
    }

    return 'manual:'
        . normalizeSupplierReceptionMatchKeyPart((string)($row['description'] ?? ''))
        . '|type:' . normalizeSupplierOrderItemType((string)($row['item_type'] ?? 'PRODUCT'))
        . '|unit:' . normalizeSupplierReceptionMatchKeyPart((string)($row['unit'] ?? 'piece'))
        . '|price:' . number_format((float)($row['price'] ?? 0), 3, '.', '')
        . '|vat:' . number_format((float)($row['tva_rate'] ?? 0), 3, '.', '');
}

function supplierReceptionMatchKeyFromLine(array $line): string
{
    $catalogId = (int)($line['catalogId'] ?? 0);
    if ($catalogId > 0) {
        return 'catalog:' . $catalogId;
    }

    $code = normalizeSupplierReceptionMatchKeyPart((string)($line['code'] ?? ''));
    if ($code !== '') {
        return 'code:' . $code . '|type:' . normalizeSupplierOrderItemType((string)($line['itemType'] ?? 'PRODUCT'));
    }

    return 'manual:'
        . normalizeSupplierReceptionMatchKeyPart((string)($line['name'] ?? ''))
        . '|type:' . normalizeSupplierOrderItemType((string)($line['itemType'] ?? 'PRODUCT'))
        . '|unit:' . normalizeSupplierReceptionMatchKeyPart((string)($line['unit'] ?? 'piece'))
        . '|price:' . number_format((float)($line['price'] ?? 0), 3, '.', '')
        . '|vat:' . number_format((float)($line['tvaRate'] ?? 0), 3, '.', '');
}

function supplierReceptionLineMatchesOrderRow(array $line, array $orderRow): bool
{
    $lineType = normalizeSupplierOrderItemType((string)($line['itemType'] ?? 'PRODUCT'));
    $orderType = normalizeSupplierOrderItemType((string)($orderRow['item_type'] ?? 'PRODUCT'));
    if ($lineType !== $orderType) {
        return false;
    }

    $lineCatalogId = (int)($line['catalogId'] ?? 0);
    $orderCatalogId = (int)($orderRow['catalog_id'] ?? 0);
    if ($lineCatalogId > 0 && $orderCatalogId > 0) {
        return $lineCatalogId === $orderCatalogId;
    }

    $lineCode = normalizeSupplierReceptionMatchKeyPart((string)($line['code'] ?? ''));
    $orderCode = normalizeSupplierReceptionMatchKeyPart((string)($orderRow['product_code'] ?? ''));
    if ($lineCode !== '' && $orderCode !== '') {
        return $lineCode === $orderCode;
    }

    $lineName = normalizeSupplierReceptionMatchKeyPart((string)($line['name'] ?? ''));
    $orderName = normalizeSupplierReceptionMatchKeyPart((string)($orderRow['description'] ?? ''));
    if ($lineName === '' || $lineName !== $orderName) {
        return false;
    }

    $lineUnit = normalizeSupplierReceptionMatchKeyPart((string)($line['unit'] ?? 'piece'));
    $orderUnit = normalizeSupplierReceptionMatchKeyPart((string)($orderRow['unit'] ?? 'piece'));
    return $lineUnit === $orderUnit
        && abs((float)($line['price'] ?? 0) - (float)($orderRow['price'] ?? 0)) < 0.0005
        && abs((float)($line['tvaRate'] ?? 0) - (float)($orderRow['tva_rate'] ?? 0)) < 0.0005;
}

function supplierReceptionResolveOrderKey(array $line, array $orderedByKey, array $orderRowsByKey): string
{
    $directKey = supplierReceptionMatchKeyFromLine($line);
    if (array_key_exists($directKey, $orderedByKey)) {
        return $directKey;
    }

    foreach ($orderRowsByKey as $orderKey => $orderRows) {
        foreach ($orderRows as $orderRow) {
            if (supplierReceptionLineMatchesOrderRow($line, $orderRow)) {
                return $orderKey;
            }
        }
    }

    return $directKey;
}

function assertReceptionQuantitiesWithinSupplierOrder(
    mysqli $conn,
    int $userId,
    int $sourceSupplierOrderId,
    int $currentReceptionId,
    array $lines,
    bool $allowOverdelivery
): void {
    $orderItemsStmt = $conn->prepare('
        SELECT catalog_id, product_code, description, item_type, qty, price, tva_rate, unit
        FROM erp_supplier_order_items
        WHERE supplier_order_id = ?
        ORDER BY id ASC
        FOR UPDATE
    ');
    if (!$orderItemsStmt) {
        throw new Exception('Failed to prepare supplier order lines lookup: ' . $conn->error);
    }
    $orderItemsStmt->bind_param('i', $sourceSupplierOrderId);
    $orderItemsStmt->execute();
    $orderItemsResult = $orderItemsStmt->get_result();

    $orderedByKey = [];
    $orderRowsByKey = [];
    $totalOrderedQty = 0.0;
    while ($row = $orderItemsResult->fetch_assoc()) {
        $key = supplierOrderMatchKeyFromRow($row);
        $orderedByKey[$key] = round((float)($orderedByKey[$key] ?? 0) + (float)($row['qty'] ?? 0), 3);
        $orderRowsByKey[$key][] = $row;
        $totalOrderedQty = round($totalOrderedQty + (float)($row['qty'] ?? 0), 3);
    }
    $orderItemsStmt->close();

    if (!$orderedByKey) {
        throw new Exception('Source supplier order has no valid lines to receive');
    }

    $existingItemsStmt = $conn->prepare('
        SELECT sri.catalog_id, sri.code, sri.name, sri.item_type, sri.qty, sri.accepted_qty, sri.price, sri.tva_rate, sri.unit
        FROM erp_supplier_reception_items sri
        INNER JOIN erp_supplier_receptions sr ON sr.id = sri.supplier_reception_id
        WHERE sr.user_id = ?
          AND sr.supplier_order_id = ?
          AND sr.id <> ?
          AND sr.stock_applied = 1
        FOR UPDATE
    ');
    if (!$existingItemsStmt) {
        throw new Exception('Failed to prepare existing supplier reception lines lookup: ' . $conn->error);
    }
    $existingItemsStmt->bind_param('iii', $userId, $sourceSupplierOrderId, $currentReceptionId);
    $existingItemsStmt->execute();
    $existingItemsResult = $existingItemsStmt->get_result();

    $alreadyReceivedByKey = [];
    $totalAlreadyReceivedQty = 0.0;
    while ($row = $existingItemsResult->fetch_assoc()) {
        $existingLine = [
            'catalogId' => (int)($row['catalog_id'] ?? 0),
            'code' => (string)($row['code'] ?? ''),
            'name' => (string)($row['name'] ?? ''),
            'itemType' => (string)($row['item_type'] ?? 'PRODUCT'),
            'price' => (float)($row['price'] ?? 0),
            'tvaRate' => (float)($row['tva_rate'] ?? 0),
            'unit' => (string)($row['unit'] ?? 'piece'),
        ];
        $key = supplierReceptionResolveOrderKey($existingLine, $orderedByKey, $orderRowsByKey);
        $alreadyReceivedByKey[$key] = round((float)($alreadyReceivedByKey[$key] ?? 0) + (float)($row['accepted_qty'] ?? $row['qty'] ?? 0), 3);
        $totalAlreadyReceivedQty = round($totalAlreadyReceivedQty + (float)($row['accepted_qty'] ?? $row['qty'] ?? 0), 3);
    }
    $existingItemsStmt->close();

    $currentByKey = [];
    $totalCurrentQty = 0.0;
    foreach ($lines as $line) {
        $key = supplierReceptionResolveOrderKey($line, $orderedByKey, $orderRowsByKey);
        if (!array_key_exists($key, $orderedByKey)) {
            $name = trim((string)($line['name'] ?? 'this line')) ?: 'this line';
            throw new Exception('Reception line "' . $name . '" does not exist on the source supplier order');
        }

        $currentByKey[$key] = round((float)($currentByKey[$key] ?? 0) + (float)($line['acceptedQty'] ?? $line['qty'] ?? 0), 3);
        $totalCurrentQty = round($totalCurrentQty + (float)($line['acceptedQty'] ?? $line['qty'] ?? 0), 3);
    }

    if (!$allowOverdelivery && $totalAlreadyReceivedQty + $totalCurrentQty > $totalOrderedQty + 0.0005) {
        throw new Exception(
            'This reception would exceed the remaining purchase-order quantity '
            . '(ordered: ' . number_format($totalOrderedQty, 3, '.', '')
            . ', already received: ' . number_format($totalAlreadyReceivedQty, 3, '.', '')
            . ', this reception: ' . number_format($totalCurrentQty, 3, '.', '') . ')'
        );
    }

    foreach ($currentByKey as $key => $currentQty) {
        $orderedQty = round((float)($orderedByKey[$key] ?? 0), 3);
        $receivedQty = round((float)($alreadyReceivedByKey[$key] ?? 0), 3);
        $nextQty = round($receivedQty + $currentQty, 3);

        if (!$allowOverdelivery && $nextQty > $orderedQty + 0.0005) {
            throw new Exception(
                'Received quantity exceeds the ordered quantity for one of the supplier order lines '
                . '(ordered: ' . number_format($orderedQty, 3, '.', '')
                . ', already received: ' . number_format($receivedQty, 3, '.', '')
                . ', this reception: ' . number_format($currentQty, 3, '.', '') . ')'
            );
        }
    }
}

$debugStage = 'request';
$isNewReception = false;
try {
    if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
        jsonResponse(['success' => false, 'message' => 'Method not allowed'], 405);
    }

    $debugStage = 'authentication';
    $principal = requireAuth();
    $userId = authTenantId($principal);
    $actorId = authActorId($principal);
    $debugStage = 'payload_validation';
    $data = requireJsonBody();
    $id = (int)($data['id'] ?? 0);
    $supplierId = getRequiredInt($data, 'supplierId', 'Supplier');
    $invoiceDate = getRequiredString($data, 'invoiceDate', 'Invoice date');
    $invoiceNumber = trim((string)($data['invoiceNumber'] ?? ''));
    $supplierDeliveryNoteNumber = trim((string)($data['supplierDeliveryNoteNumber'] ?? ''));
    $supplierDeliveryNoteDate = trim((string)($data['supplierDeliveryNoteDate'] ?? ''));
    $receivedDate = getRequiredString($data, 'receivedDate', 'Received date');
    $notes = trim((string)($data['notes'] ?? ''));
    $exceptionType = normalizeSupplierReceptionExceptionType((string)($data['exceptionType'] ?? 'NONE'));
    $exceptionReason = trim((string)($data['exceptionReason'] ?? ''));
    $status = normalizeSupplierReceptionStatus((string)($data['status'] ?? 'DRAFT'));
    if ($status !== 'DRAFT') {
        throw new Exception('Use the supplier reception confirmation action to review and apply this reception');
    }
    $sourceSupplierOrderId = (int)($data['sourceSupplierOrderId'] ?? 0);
    $stockApplied = false;
    $stockAppliedAt = '';
    $lines = validateSupplierReceptionLines($data['lines'] ?? []);
    if (!$lines) {
        throw new Exception('At least one reception line is required');
    }
    $totalHt = round(array_sum(array_map(static fn(array $line): float => (float)$line['subtotal'], $lines)), 3);
    $totalVat = round(array_sum(array_map(static fn(array $line): float => round((float)$line['subtotal'] * (float)$line['tvaRate'] / 100, 3), $lines)), 3);
    $totalTtc = round($totalHt + $totalVat, 3);
    $idempotencyKey = $id <= 0 ? requiredIdempotencyKey($data) : '';

    validateDate($invoiceDate, 'Invoice date');
    validateDate($receivedDate, 'Received date');
    if ($supplierDeliveryNoteDate !== '') validateDate($supplierDeliveryNoteDate, 'Supplier delivery note date');
    if ($exceptionType !== 'NONE' && $exceptionReason === '') {
        throw new Exception('An exception reason is required');
    }
    if ($sourceSupplierOrderId > 0 && $exceptionType === 'NO_ORDER') {
        throw new Exception('NO_ORDER can only be used when no source purchase order is linked');
    }
    if ($sourceSupplierOrderId <= 0 && $exceptionType === 'OVERDELIVERY') {
        throw new Exception('OVERDELIVERY requires a linked source purchase order');
    }

    $debugStage = 'authorization';
    $conn = db();
    requirePermission($conn, $userId, $id > 0 ? 'supplierReceptions.edit' : 'supplierReceptions.create');
    ensureSupplierReceptionsSchema($conn);

    if (!getSupplierById($conn, $userId, $supplierId)) {
        throw new Exception('Supplier not found or unauthorized');
    }

    if ($sourceSupplierOrderId > 0) {
        $debugStage = 'source_order_validation';
        $orderStmt = $conn->prepare("
            SELECT id, supplier_id, status
            FROM erp_supplier_orders
            WHERE id = ? AND user_id = ?
            LIMIT 1
        ");
        if (!$orderStmt) {
            throw new Exception('Failed to prepare supplier order lookup: ' . $conn->error);
        }
        $orderStmt->bind_param('ii', $sourceSupplierOrderId, $userId);
        $orderStmt->execute();
        $sourceOrder = $orderStmt->get_result()->fetch_assoc();
        $orderStmt->close();

        if (!$sourceOrder) {
            throw new Exception('Source supplier order not found or unauthorized');
        }
        if ((int)$sourceOrder['supplier_id'] !== $supplierId) {
            throw new Exception('Supplier reception must match the selected supplier order');
        }
        if (!in_array((string)$sourceOrder['status'], ['SENT', 'PARTIALLY_RECEIVED'], true)) {
            throw new Exception('Receptions require a sent or partially received supplier order');
        }
    }

    $debugStage = 'transaction';
    $conn->begin_transaction();

    if ($id <= 0) {
        $requestHash = idempotencyRequestHash(['supplier_id' => $supplierId, 'supplier_order_id' => $sourceSupplierOrderId, 'invoice_number' => $invoiceNumber, 'supplier_delivery_note_number' => $supplierDeliveryNoteNumber, 'supplier_delivery_note_date' => $supplierDeliveryNoteDate, 'invoice_date' => $invoiceDate, 'received_date' => $receivedDate, 'notes' => $notes, 'exception_type' => $exceptionType, 'exception_reason' => $exceptionReason, 'status' => $status, 'lines' => $lines]);
        $replayedId = claimIdempotencyKey($conn, $userId, 'supplier.reception.create', $idempotencyKey, $requestHash);
        if ($replayedId !== null) {
            $conn->commit();
            structuredLog('INFO', 'SUPPLIER_RECEPTION.CREATE_REPLAYED', [
                'supplier_reception_id' => $replayedId,
                'supplier_order_id' => $sourceSupplierOrderId,
            ]);
            jsonResponse(['success' => true, 'id' => $replayedId, 'replayed' => true]);
        }
    }

    if ($sourceSupplierOrderId > 0) {
        $debugStage = 'quantity_validation';
        assertReceptionQuantitiesWithinSupplierOrder($conn, $userId, $sourceSupplierOrderId, $id, $lines, $exceptionType === 'OVERDELIVERY');
    }

    $isNewReception = $id <= 0;
    if ($id > 0) {
        $debugStage = 'reception_update';
        $lock = $conn->prepare("
            SELECT id, status, stock_applied
            FROM erp_supplier_receptions
            WHERE id = ? AND user_id = ?
            LIMIT 1
            FOR UPDATE
        ");
        if (!$lock) {
            throw new Exception('Failed to prepare supplier reception lock: ' . $conn->error);
        }
        $lock->bind_param('ii', $id, $userId);
        $lock->execute();
        $existing = $lock->get_result()->fetch_assoc();
        $lock->close();

        if (!$existing) {
            throw new Exception('Supplier reception not found or unauthorized');
        }

        if ((int)($existing['stock_applied'] ?? 0) === 1) {
            throw new Exception('This supplier reception is already applied to stock and can no longer be updated');
        }
        if ((string)$existing['status'] !== 'DRAFT') {
            throw new Exception('Only draft supplier receptions can be updated');
        }

        $stmt = $conn->prepare("
            UPDATE erp_supplier_receptions
            SET supplier_id = ?, supplier_order_id = NULLIF(?, 0), invoice_number = ?, supplier_delivery_note_number = NULLIF(?, ''), supplier_delivery_note_date = NULLIF(?, ''), invoice_date = ?, received_date = ?, notes = ?, exception_type = ?, exception_reason = NULLIF(?, ''), status = 'DRAFT', total_ht = ?, total_vat = ?, total_ttc = ?
            WHERE id = ? AND user_id = ?
        ");
        if (!$stmt) {
            throw new Exception('Failed to prepare supplier reception update: ' . $conn->error);
        }
        $stmt->bind_param(
            'iissssssssdddii',
            $supplierId,
            $sourceSupplierOrderId,
            $invoiceNumber,
            $supplierDeliveryNoteNumber,
            $supplierDeliveryNoteDate,
            $invoiceDate,
            $receivedDate,
            $notes,
            $exceptionType,
            $exceptionReason,
            $totalHt,
            $totalVat,
            $totalTtc,
            $id,
            $userId
        );
        $stmt->execute();
        $stmt->close();

        $clear = $conn->prepare('DELETE FROM erp_supplier_reception_items WHERE supplier_reception_id = ?');
        if (!$clear) {
            throw new Exception('Failed to prepare supplier reception lines cleanup: ' . $conn->error);
        }
        $clear->bind_param('i', $id);
        $clear->execute();
        $clear->close();
    } else {
        $debugStage = 'reception_insert';
        $stmt = $conn->prepare("
            INSERT INTO erp_supplier_receptions (
                supplier_id,
                supplier_order_id,
                invoice_number,
                supplier_delivery_note_number,
                supplier_delivery_note_date,
                invoice_date,
                received_date,
                notes,
                exception_type,
                exception_reason,
                status,
                total_ht,
                total_vat,
                total_ttc,
                user_id
            )
            VALUES (?, NULLIF(?, 0), ?, NULLIF(?, ''), NULLIF(?, ''), ?, ?, ?, ?, NULLIF(?, ''), 'DRAFT', ?, ?, ?, ?)
        ");
        if (!$stmt) {
            throw new Exception('Failed to prepare supplier reception insert: ' . $conn->error);
        }
        $stmt->bind_param(
            'iissssssssdddi',
            $supplierId,
            $sourceSupplierOrderId,
            $invoiceNumber,
            $supplierDeliveryNoteNumber,
            $supplierDeliveryNoteDate,
            $invoiceDate,
            $receivedDate,
            $notes,
            $exceptionType,
            $exceptionReason,
            $totalHt,
            $totalVat,
            $totalTtc,
            $userId
        );
        $stmt->execute();
        $id = (int)$stmt->insert_id;
        $stmt->close();
    }

    $debugStage = 'reception_lines';
    $itemStmt = $conn->prepare("
        INSERT INTO erp_supplier_reception_items (
            supplier_reception_id,
            catalog_id,
            code,
            name,
            item_type,
            ordered_qty,
            qty,
            accepted_qty,
            damaged_qty,
            rejected_qty,
            discrepancy_reason,
            stock_impact,
            price,
            selling_price,
            subtotal,
            tva_rate,
            unit
        )
        VALUES (?, NULLIF(?, 0), ?, ?, ?, ?, ?, ?, ?, ?, NULLIF(?, ''), ?, ?, ?, ?, ?, ?)
    ");
    if (!$itemStmt) {
        throw new Exception('Failed to prepare supplier reception line insert: ' . $conn->error);
    }

    foreach ($lines as $line) {
        $catalogId = (int)$line['catalogId'];
        requireTenantProduct($conn, $userId, $catalogId);
        $code = (string)$line['code'];
        $name = (string)$line['name'];
        $itemType = (string)$line['itemType'];
        $orderedQty = (float)$line['orderedQty'];
        $qty = (float)$line['qty'];
        $acceptedQty = (float)$line['acceptedQty'];
        $damagedQty = (float)$line['damagedQty'];
        $rejectedQty = (float)$line['rejectedQty'];
        $discrepancyReason = (string)$line['discrepancyReason'];
        $stockImpact = (float)$line['stockImpact'];
        $price = (float)$line['price'];
        $sellingPrice = (float)($line['sellingPrice'] ?? 0);
        $subtotal = (float)$line['subtotal'];
        $tvaRate = (float)$line['tvaRate'];
        $unit = (string)$line['unit'];

        $itemStmt->bind_param(
            'iisssdddddsddddds',
            $id,
            $catalogId,
            $code,
            $name,
            $itemType,
            $orderedQty,
            $qty,
            $acceptedQty,
            $damagedQty,
            $rejectedQty,
            $discrepancyReason,
            $stockImpact,
            $price,
            $sellingPrice,
            $subtotal,
            $tvaRate,
            $unit
        );
        $itemStmt->execute();
    }
    $itemStmt->close();

    if ($isNewReception) {
        completeIdempotencyKey($conn, $userId, 'supplier.reception.create', $idempotencyKey, $id);
    }

    $debugStage = 'audit';
    $auditAction = $isNewReception ? 'SUPPLIER_RECEPTION.DRAFT_CREATED' : 'SUPPLIER_RECEPTION.DRAFT_UPDATED';
    $acceptedTotal = round(array_sum(array_map(static fn(array $line): float => (float)$line['acceptedQty'], $lines)), 3);
    $damagedTotal = round(array_sum(array_map(static fn(array $line): float => (float)$line['damagedQty'], $lines)), 3);
    $rejectedTotal = round(array_sum(array_map(static fn(array $line): float => (float)$line['rejectedQty'], $lines)), 3);
    try {
        auditLog($conn, $userId, $actorId, $auditAction, 'SUPPLIER_RECEPTION', $id, null, [
            'supplier_id' => $supplierId,
            'supplier_order_id' => $sourceSupplierOrderId ?: null,
            'item_count' => count($lines),
            'accepted_qty' => $acceptedTotal,
            'damaged_qty' => $damagedTotal,
            'rejected_qty' => $rejectedTotal,
            'exception_type' => $exceptionType,
        ]);
    } catch (Throwable $auditError) {
        structuredLog('WARNING', 'SUPPLIER_RECEPTION.AUDIT_FAILED', [
            'supplier_reception_id' => $id,
            'action' => $auditAction,
            'exception' => get_class($auditError),
        ]);
    }

    $debugStage = 'commit';
    $conn->commit();
    structuredLog('INFO', $auditAction, [
        'supplier_reception_id' => $id,
        'supplier_order_id' => $sourceSupplierOrderId,
        'item_count' => count($lines),
        'accepted_qty' => $acceptedTotal,
        'damaged_qty' => $damagedTotal,
        'rejected_qty' => $rejectedTotal,
    ]);

    jsonResponse([
        'success' => true,
        'id' => $id,
        'replayed' => false,
        'message' => 'Supplier reception saved',
    ]);
} catch (Throwable $e) {
    if (isset($conn)) {
        try { $conn->rollback(); } catch (Throwable $ignored) {}
    }
    structuredLog('ERROR', 'SUPPLIER_RECEPTION.SAVE_FAILED', [
        'stage' => $debugStage,
        'supplier_reception_id' => isset($id) ? (int)$id : 0,
        'supplier_order_id' => isset($sourceSupplierOrderId) ? (int)$sourceSupplierOrderId : 0,
        'supplier_id' => isset($supplierId) ? (int)$supplierId : 0,
        'exception' => get_class($e),
        'message' => $e->getMessage(),
    ]);
    jsonResponse(['success' => false, 'message' => $e->getMessage()], 400);
}
