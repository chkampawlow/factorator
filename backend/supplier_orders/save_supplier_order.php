<?php

header('Content-Type: application/json');

require_once __DIR__ . '/../config/response.php';
require_once __DIR__ . '/../config/db.php';
require_once __DIR__ . '/../auth/auth_required.php';
require_once __DIR__ . '/../auth/role_helper.php';
require_once __DIR__ . '/../config/tenant_scope.php';
require_once __DIR__ . '/../config/audit.php';

require_once __DIR__ . '/../suppliers/supplier_service.php';
require_once __DIR__ . '/order_service.php';

$debugStage = 'request';
$orderWasNew = false;
$previousStatus = null;
try {
    if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
        jsonResponse(['success' => false, 'message' => 'Method not allowed'], 405);
    }

    $debugStage = 'authentication';
    $userId = (int)requireAuth()->id;
    $debugStage = 'payload_validation';
    $data = requireJsonBody();
    $id = (int)($data['id'] ?? 0);
    $orderWasNew = $id <= 0;
    $supplierId = getRequiredInt($data, 'supplierId', 'Supplier');
    $orderDate = getRequiredString($data, 'orderDate', 'Order date');
    $expectedDate = trim((string)($data['expectedDate'] ?? ''));
    $notes = trim((string)($data['notes'] ?? ''));
    $items = validateSupplierOrderItems($data['items'] ?? []);
    $status = persistedSupplierOrderStatus((string)($data['status'] ?? 'DRAFT'));

    validateDate($orderDate, 'Order date');
    if ($expectedDate !== '') {
        validateDate($expectedDate, 'Expected date');
    }

    $debugStage = 'authorization';
    $conn = db();
    if ($id <= 0) {
        requirePermission($conn, $userId, 'supplierOrders.create');
    } else {
        requirePermission($conn, $userId, 'supplierOrders.edit');
        if ($status === 'SENT') {
            requirePermission($conn, $userId, 'supplierOrders.send');
        }
    }
    ensureSupplierOrdersSchema($conn);

    if (!getSupplierById($conn, $userId, $supplierId)) {
        throw new Exception('Supplier not found or unauthorized');
    }

    $subtotal = 0.0;
    $totalVat = 0.0;
    $total = 0.0;
    foreach ($items as $item) {
        $lineHt = round((float)$item['qty'] * (float)$item['price'], 3);
        $lineVat = round($lineHt * ((float)$item['tvaRate'] / 100), 3);
        $subtotal += $lineHt;
        $totalVat += $lineVat;
        $total += round($lineHt + $lineVat, 3);
    }
    $subtotal = round($subtotal, 3);
    $totalVat = round($totalVat, 3);
    $total = round($total, 3);

    $debugStage = 'transaction';
    $conn->begin_transaction();

    if ($id > 0) {
        $lock = $conn->prepare("
            SELECT id, status
            FROM erp_supplier_orders
            WHERE id = ? AND user_id = ?
            LIMIT 1
            FOR UPDATE
        ");
        if (!$lock) {
            throw new Exception('Failed to prepare supplier order lock: ' . $conn->error);
        }
        $lock->bind_param('ii', $id, $userId);
        $lock->execute();
        $existing = $lock->get_result()->fetch_assoc();
        $lock->close();

        if (!$existing) {
            throw new Exception('Supplier order not found or unauthorized');
        }

        $previousStatus = (string)$existing['status'];
        if ($previousStatus !== 'DRAFT') {
            throw new Exception('Sent supplier orders are immutable and can no longer be updated');
        }
        $allowedTransitions = [
            'DRAFT' => ['DRAFT', 'SENT', 'CANCELLED'],
        ];
        if (!in_array($status, $allowedTransitions[(string)$existing['status']], true)) {
            throw new Exception('Invalid supplier order status transition');
        }

        $debugStage = 'order_update';
        $stmt = $conn->prepare("
            UPDATE erp_supplier_orders
            SET supplier_id = ?, order_date = ?, expected_date = NULLIF(?, ''), notes = ?, status = ?, subtotal = ?, total_vat = ?, total = ?
            WHERE id = ? AND user_id = ?
        ");
        if (!$stmt) {
            throw new Exception('Failed to prepare supplier order update: ' . $conn->error);
        }
        $stmt->bind_param(
            'issssdddii',
            $supplierId,
            $orderDate,
            $expectedDate,
            $notes,
            $status,
            $subtotal,
            $totalVat,
            $total,
            $id,
            $userId
        );
        $stmt->execute();
        $stmt->close();

        $clear = $conn->prepare('DELETE FROM erp_supplier_order_items WHERE supplier_order_id = ?');
        if (!$clear) {
            throw new Exception('Failed to prepare supplier order items cleanup: ' . $conn->error);
        }
        $clear->bind_param('i', $id);
        $clear->execute();
        $clear->close();
    } else {
        if ($status !== 'DRAFT') {
            throw new Exception('New supplier orders must start as drafts');
        }
        $debugStage = 'order_insert';
        $temporaryNumber = 'PO-TMP-' . bin2hex(random_bytes(5));
        $stmt = $conn->prepare("
            INSERT INTO erp_supplier_orders (
                order_number,
                supplier_id,
                order_date,
                expected_date,
                notes,
                status,
                subtotal,
                total_vat,
                total,
                user_id
            )
            VALUES (?, ?, ?, NULLIF(?, ''), ?, ?, ?, ?, ?, ?)
        ");
        if (!$stmt) {
            throw new Exception('Failed to prepare supplier order insert: ' . $conn->error);
        }
        $stmt->bind_param(
            'sissssdddi',
            $temporaryNumber,
            $supplierId,
            $orderDate,
            $expectedDate,
            $notes,
            $status,
            $subtotal,
            $totalVat,
            $total,
            $userId
        );
        $stmt->execute();
        $id = (int)$stmt->insert_id;
        $stmt->close();

        $orderNumber = supplierOrderNumberForId($id);
        $numberStmt = $conn->prepare('UPDATE erp_supplier_orders SET order_number = ? WHERE id = ?');
        if (!$numberStmt) {
            throw new Exception('Failed to prepare supplier order number update: ' . $conn->error);
        }
        $numberStmt->bind_param('si', $orderNumber, $id);
        $numberStmt->execute();
        $numberStmt->close();
    }

    $debugStage = 'order_lines';
    $itemStmt = $conn->prepare("
        INSERT INTO erp_supplier_order_items (
            supplier_order_id,
            catalog_id,
            product_code,
            description,
            item_type,
            qty,
            price,
            tva_rate,
            unit,
            line_total
        )
        VALUES (?, NULLIF(?, 0), ?, ?, ?, ?, ?, ?, ?, ?)
    ");
    if (!$itemStmt) {
        throw new Exception('Failed to prepare supplier order item insert: ' . $conn->error);
    }

    foreach ($items as $item) {
        $catalogId = (int)$item['catalogId'];
        requireTenantSupplierOrderCatalogItem($conn, $userId, $catalogId);
        $code = (string)$item['code'];
        $description = (string)$item['description'];
        $itemType = (string)$item['itemType'];
        $qty = (float)$item['qty'];
        $price = (float)$item['price'];
        $tvaRate = (float)$item['tvaRate'];
        $unit = (string)$item['unit'];
        $lineTotal = (float)$item['lineTotal'];

        $itemStmt->bind_param(
            'iisssdddss',
            $id,
            $catalogId,
            $code,
            $description,
            $itemType,
            $qty,
            $price,
            $tvaRate,
            $unit,
            $lineTotal
        );
        $itemStmt->execute();
    }
    $itemStmt->close();

    $debugStage = 'audit';
    $auditAction = $orderWasNew
        ? 'SUPPLIER_ORDER.CREATED'
        : (($previousStatus !== 'SENT' && $status === 'SENT') ? 'SUPPLIER_ORDER.SENT' : 'SUPPLIER_ORDER.UPDATED');
    try {
        auditLog($conn, $userId, $userId, $auditAction, 'SUPPLIER_ORDER', $id, null, [
            'supplier_id' => $supplierId,
            'status' => $status,
            'item_count' => count($items),
            'total' => $total,
        ]);
    } catch (Throwable $auditError) {
        structuredLog('WARNING', 'SUPPLIER_ORDER.AUDIT_FAILED', [
            'supplier_order_id' => $id,
            'action' => $auditAction,
            'exception' => get_class($auditError),
        ]);
    }

    $debugStage = 'commit';
    $conn->commit();
    structuredLog('INFO', $auditAction, [
        'supplier_order_id' => $id,
        'supplier_id' => $supplierId,
        'status' => $status,
        'item_count' => count($items),
        'total' => $total,
    ]);

    jsonResponse([
        'success' => true,
        'id' => $id,
        'message' => 'Supplier purchase order saved',
    ]);
} catch (Throwable $e) {
    if (isset($conn)) {
        try { $conn->rollback(); } catch (Throwable $ignored) {}
    }
    structuredLog('ERROR', 'SUPPLIER_ORDER.SAVE_FAILED', [
        'stage' => $debugStage,
        'supplier_order_id' => isset($id) ? (int)$id : 0,
        'supplier_id' => isset($supplierId) ? (int)$supplierId : 0,
        'exception' => get_class($e),
        'message' => $e->getMessage(),
    ]);
    jsonResponse(['success' => false, 'message' => $e->getMessage()], 400);
}
