<?php

require_once __DIR__ . '/../config/validator.php';
require_once __DIR__ . '/../suppliers/supplier_service.php';
require_once __DIR__ . '/../supplier_orders/order_service.php';

function ensureSupplierReceptionsSchema(mysqli $conn): void
{
    static $ensured = false;
    if ($ensured) return;
    ensureSupplierOrdersSchema($conn);
    $conn->query("SELECT supplier_id,supplier_order_id,supplier_delivery_note_number,supplier_delivery_note_date,exception_type,exception_reason,discrepancy_attachment_path,status,stock_applied,confirmed_at,confirmed_by,confirmation_hash,user_id FROM erp_supplier_receptions LIMIT 0");
    $conn->query("SELECT supplier_reception_id,catalog_id,ordered_qty,qty,accepted_qty,damaged_qty,rejected_qty,discrepancy_reason,selling_price FROM erp_supplier_reception_items LIMIT 0");
    $ensured = true;
}

function normalizeSupplierReceptionStatus(string $value): string
{
    $status = strtoupper(trim($value));
    if (!in_array($status, ['DRAFT', 'REVIEWED'], true)) {
        throw new Exception('Invalid supplier reception status');
    }
    return $status;
}

function normalizeSupplierReceptionItemType(string $value): string
{
    return strtoupper(trim($value)) === 'SERVICE' ? 'SERVICE' : 'PRODUCT';
}

function normalizeSupplierReceptionExceptionType(string $value): string
{
    $type = strtoupper(trim($value));
    if (!in_array($type, ['NONE', 'OVERDELIVERY', 'NO_ORDER'], true)) {
        throw new Exception('Invalid supplier reception exception type');
    }
    return $type;
}

function validateSupplierReceptionLines(array $lines): array
{
    $normalized = [];
    foreach ($lines as $line) {
        if (!is_array($line)) {
            continue;
        }

        $catalogId = (int)($line['catalogId'] ?? 0);
        $code = trim((string)($line['code'] ?? ''));
        $name = trim((string)($line['name'] ?? ''));
        $itemType = normalizeSupplierReceptionItemType((string)($line['itemType'] ?? 'PRODUCT'));
        $qty = round((float)($line['qty'] ?? 0), 3);
        $orderedQty = round((float)($line['orderedQty'] ?? $qty), 3);
        $acceptedQty = round((float)($line['acceptedQty'] ?? $qty), 3);
        $damagedQty = round((float)($line['damagedQty'] ?? 0), 3);
        $rejectedQty = round((float)($line['rejectedQty'] ?? 0), 3);
        $discrepancyReason = trim((string)($line['discrepancyReason'] ?? ''));
        $price = round((float)($line['price'] ?? 0), 3);
        $sellingPrice = round((float)($line['sellingPrice'] ?? 0), 3);
        // Financial totals are authoritative on the server. Never trust a
        // subtotal supplied by a mobile or web client.
        $subtotal = round($qty * $price, 3);
        $tvaRate = round((float)($line['tvaRate'] ?? 0), 3);
        $unit = trim((string)($line['unit'] ?? 'piece')) ?: 'piece';

        if ($catalogId <= 0 && $name === '') {
            continue;
        }
        if ($qty <= 0 || $orderedQty < 0 || $acceptedQty < 0 || $damagedQty < 0 || $rejectedQty < 0) {
            throw new Exception('Supplier reception quantity must be greater than 0');
        }
        if (abs(($acceptedQty + $damagedQty + $rejectedQty) - $qty) > 0.0005) {
            throw new Exception('Accepted, damaged and rejected quantities must equal the received quantity');
        }
        if (($damagedQty > 0 || $rejectedQty > 0) && $discrepancyReason === '') {
            throw new Exception('A discrepancy reason is required for damaged or rejected quantities');
        }
        if ($price < 0 || $sellingPrice < 0 || $subtotal < 0 || $tvaRate < 0) {
            throw new Exception('Supplier reception line values are invalid');
        }
        validateMaxLength($code, 100, 'Product code');
        validateMaxLength($name, 255, 'Product name');
        validateMaxLength($discrepancyReason, 255, 'Discrepancy reason');
        validateMaxLength($unit, 50, 'Unit');

        $normalized[] = [
            'catalogId' => $catalogId,
            'code' => $code,
            'name' => $name,
            'itemType' => $itemType,
            'orderedQty' => $orderedQty,
            'qty' => $qty,
            'acceptedQty' => $acceptedQty,
            'damagedQty' => $damagedQty,
            'rejectedQty' => $rejectedQty,
            'discrepancyReason' => $discrepancyReason,
            'stockImpact' => $itemType === 'PRODUCT' ? $acceptedQty : 0.0,
            'price' => $price,
            'sellingPrice' => $itemType === 'PRODUCT' ? $sellingPrice : 0.0,
            'subtotal' => $subtotal,
            'tvaRate' => $tvaRate,
            'unit' => $unit,
        ];
    }

    return $normalized;
}

function supplierReceptionLineRow(array $row): array
{
    return [
        'id' => isset($row['id']) ? (int)$row['id'] : 0,
        'catalogId' => isset($row['catalog_id']) ? (int)$row['catalog_id'] : 0,
        'code' => (string)($row['code'] ?? ''),
        'name' => (string)($row['name'] ?? ''),
        'itemType' => normalizeSupplierReceptionItemType((string)($row['item_type'] ?? 'PRODUCT')),
        'orderedQty' => round((float)($row['ordered_qty'] ?? $row['qty'] ?? 0), 3),
        'qty' => round((float)($row['qty'] ?? 0), 3),
        'acceptedQty' => round((float)($row['accepted_qty'] ?? $row['qty'] ?? 0), 3),
        'damagedQty' => round((float)($row['damaged_qty'] ?? 0), 3),
        'rejectedQty' => round((float)($row['rejected_qty'] ?? 0), 3),
        'discrepancyReason' => (string)($row['discrepancy_reason'] ?? ''),
        'stockImpact' => round((float)($row['stock_impact'] ?? 0), 3),
        'price' => round((float)($row['price'] ?? 0), 3),
        'sellingPrice' => round((float)($row['selling_price'] ?? 0), 3),
        'subtotal' => round((float)($row['subtotal'] ?? 0), 3),
        'tvaRate' => round((float)($row['tva_rate'] ?? 0), 3),
        'unit' => (string)($row['unit'] ?? 'piece'),
    ];
}

function supplierReceptionRow(array $row, array $lines = []): array
{
    return [
        'id' => (int)($row['id'] ?? 0),
        'supplierId' => (int)($row['supplier_id'] ?? 0),
        'supplierName' => (string)($row['supplier_name'] ?? ''),
        'invoiceNumber' => (string)($row['invoice_number'] ?? ''),
        'supplierDeliveryNoteNumber' => (string)($row['supplier_delivery_note_number'] ?? ''),
        'supplierDeliveryNoteDate' => (string)($row['supplier_delivery_note_date'] ?? ''),
        'invoiceDate' => (string)($row['invoice_date'] ?? ''),
        'receivedDate' => (string)($row['received_date'] ?? ''),
        'notes' => (string)($row['notes'] ?? ''),
        'exceptionType' => normalizeSupplierReceptionExceptionType((string)($row['exception_type'] ?? 'NONE')),
        'exceptionReason' => (string)($row['exception_reason'] ?? ''),
        'hasDiscrepancyAttachment' => !empty($row['discrepancy_attachment_path']),
        'discrepancyAttachmentName' => (string)($row['discrepancy_attachment_name'] ?? ''),
        'status' => normalizeSupplierReceptionStatus((string)($row['status'] ?? 'DRAFT')),
        'stockApplied' => (bool)($row['stock_applied'] ?? false),
        'stockAppliedAt' => $row['stock_applied_at'] ? (string)$row['stock_applied_at'] : '',
        'confirmedAt' => $row['confirmed_at'] ? (string)$row['confirmed_at'] : '',
        'confirmedBy' => isset($row['confirmed_by']) ? (int)$row['confirmed_by'] : null,
        'confirmationHash' => (string)($row['confirmation_hash'] ?? ''),
        'createdExpenseId' => isset($row['created_expense_id']) && (int)$row['created_expense_id'] > 0 ? (int)$row['created_expense_id'] : null,
        'expenseCreatedAt' => $row['expense_created_at'] ? (string)$row['expense_created_at'] : '',
        'totalHt' => round((float)($row['total_ht'] ?? 0), 3),
        'totalVat' => round((float)($row['total_vat'] ?? 0), 3),
        'totalTtc' => round((float)($row['total_ttc'] ?? 0), 3),
        'sourceSupplierOrderId' => isset($row['supplier_order_id']) && (int)$row['supplier_order_id'] > 0 ? (int)$row['supplier_order_id'] : null,
        'sourceSupplierOrderNumber' => (string)($row['order_number'] ?? ''),
        'lines' => $lines,
        'createdAt' => (string)($row['created_at'] ?? ''),
    ];
}

function listSupplierReceptionsForUser(mysqli $conn, int $userId): array
{
    ensureSupplierReceptionsSchema($conn);

    $stmt = $conn->prepare("
        SELECT sr.*, s.name AS supplier_name, so.order_number
        FROM erp_supplier_receptions sr
        INNER JOIN suppliers s ON s.id = sr.supplier_id AND s.user_id = sr.user_id
        LEFT JOIN erp_supplier_orders so ON so.id = sr.supplier_order_id AND so.user_id = sr.user_id
        WHERE sr.user_id = ?
        ORDER BY sr.id DESC
    ");
    if (!$stmt) {
        throw new Exception('Failed to prepare supplier receptions list: ' . $conn->error);
    }
    $stmt->bind_param('i', $userId);
    $stmt->execute();
    $receptions = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);
    $stmt->close();

    if (!$receptions) {
        return [];
    }

    $receptionIds = array_map(static fn(array $row): int => (int)$row['id'], $receptions);
    $receptionIdsSql = implode(',', $receptionIds);

    $itemsResult = $conn->query("
        SELECT *
        FROM erp_supplier_reception_items
        WHERE supplier_reception_id IN ($receptionIdsSql)
        ORDER BY id ASC
    ");
    if (!$itemsResult) {
        throw new Exception('Failed to load supplier reception items: ' . $conn->error);
    }

    $itemsByReception = [];
    while ($item = $itemsResult->fetch_assoc()) {
        $receptionId = (int)$item['supplier_reception_id'];
        $itemsByReception[$receptionId][] = supplierReceptionLineRow($item);
    }
    $itemsResult->close();

    return array_map(
        static fn(array $row): array => supplierReceptionRow(
            $row,
            $itemsByReception[(int)$row['id']] ?? []
        ),
        $receptions
    );
}

function supplierReceptionsForUser(mysqli $conn, int $userId, int $receptionId = 0, int $supplierOrderId = 0): array
{
    ensureSupplierReceptionsSchema($conn);
    $where = ['sr.user_id=?'];
    $types = 'i';
    $args = [$userId];
    if ($receptionId > 0) {
        $where[] = 'sr.id=?';
        $types .= 'i';
        $args[] = $receptionId;
    }
    if ($supplierOrderId > 0) {
        $where[] = 'sr.supplier_order_id=?';
        $types .= 'i';
        $args[] = $supplierOrderId;
    }
    $whereSql = implode(' AND ', $where);
    $stmt = $conn->prepare("SELECT sr.*,s.name supplier_name,so.order_number FROM erp_supplier_receptions sr JOIN suppliers s ON s.id=sr.supplier_id AND s.user_id=sr.user_id LEFT JOIN erp_supplier_orders so ON so.id=sr.supplier_order_id AND so.user_id=sr.user_id WHERE $whereSql ORDER BY sr.id DESC LIMIT 100");
    $stmt->bind_param($types, ...$args);
    $stmt->execute();
    $headers = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);
    $stmt->close();
    if (!$headers) return [];

    $ids = array_map(static fn(array $row): int => (int)$row['id'], $headers);
    $idSql = implode(',', $ids);
    $itemsResult = $conn->query("SELECT * FROM erp_supplier_reception_items WHERE supplier_reception_id IN($idSql) ORDER BY id");
    $itemsByReception = [];
    while ($item = $itemsResult->fetch_assoc()) {
        $itemsByReception[(int)$item['supplier_reception_id']][] = supplierReceptionLineRow($item);
    }
    $itemsResult->close();
    return array_map(static fn(array $row): array => supplierReceptionRow($row, $itemsByReception[(int)$row['id']] ?? []), $headers);
}
