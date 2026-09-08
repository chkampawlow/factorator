<?php

require_once __DIR__ . '/../config/validator.php';
require_once __DIR__ . '/../suppliers/supplier_service.php';

function ensureSupplierOrdersSchema(mysqli $conn): void
{
    static $ensured = false;
    if ($ensured) return;
    ensureSuppliersTable($conn);
    $conn->query("SELECT order_number,supplier_id,status,user_id FROM erp_supplier_orders LIMIT 0");
    $conn->query("SELECT supplier_order_id,catalog_id,qty FROM erp_supplier_order_items LIMIT 0");
    $ensured = true;
}

function supplierOrderNumberForId(int $id): string
{
    return 'PO-' . date('Y') . '-' . str_pad((string)$id, 6, '0', STR_PAD_LEFT);
}

function normalizeSupplierOrderItemType(string $value): string
{
    return strtoupper(trim($value)) === 'SERVICE' ? 'SERVICE' : 'PRODUCT';
}

function normalizeSupplierOrderStatus(string $value): string
{
    $status = strtoupper(trim($value));
    return in_array($status, ['DRAFT', 'SENT', 'PARTIALLY_RECEIVED', 'RECEIVED', 'CANCELLED'], true)
        ? $status
        : 'DRAFT';
}

function persistedSupplierOrderStatus(string $value): string
{
    $status = strtoupper(trim($value));
    if (!in_array($status, ['DRAFT', 'SENT', 'CANCELLED'], true)) {
        throw new Exception('Invalid supplier order status');
    }
    return $status;
}

function validateSupplierOrderItems(array $items): array
{
    if (!$items) {
        throw new Exception('At least one supplier order line is required');
    }

    $normalized = [];
    foreach ($items as $item) {
        if (!is_array($item)) {
            continue;
        }

        $catalogId = (int)($item['catalogId'] ?? 0);
        $code = trim((string)($item['code'] ?? ''));
        $description = trim((string)($item['description'] ?? ''));
        $itemType = normalizeSupplierOrderItemType((string)($item['itemType'] ?? 'PRODUCT'));
        $qty = round((float)($item['qty'] ?? 0), 3);
        $price = round((float)($item['price'] ?? 0), 3);
        $tvaRate = round((float)($item['tvaRate'] ?? 0), 3);
        $unit = trim((string)($item['unit'] ?? 'piece')) ?: 'piece';

        if ($description === '') {
            throw new Exception('Supplier order line description is required');
        }
        if ($qty <= 0) {
            throw new Exception('Supplier order quantity must be greater than 0');
        }
        if ($price < 0 || $tvaRate < 0) {
            throw new Exception('Supplier order line values are invalid');
        }

        $lineHt = round($qty * $price, 3);
        $lineTotal = round($lineHt * (1 + $tvaRate / 100), 3);

        $normalized[] = [
            'catalogId' => $catalogId,
            'code' => $code,
            'description' => $description,
            'itemType' => $itemType,
            'qty' => $qty,
            'price' => $price,
            'tvaRate' => $tvaRate,
            'unit' => $unit,
            'lineTotal' => $lineTotal,
        ];
    }

    if (!$normalized) {
        throw new Exception('At least one valid supplier order line is required');
    }

    return $normalized;
}

function supplierOrderItemRow(array $row): array
{
    return [
        'catalogId' => isset($row['catalog_id']) ? (int)$row['catalog_id'] : 0,
        'code' => (string)($row['product_code'] ?? ''),
        'description' => (string)($row['description'] ?? ''),
        'itemType' => normalizeSupplierOrderItemType((string)($row['item_type'] ?? 'PRODUCT')),
        'qty' => round((float)($row['qty'] ?? 0), 3),
        'price' => round((float)($row['price'] ?? 0), 3),
        'tvaRate' => round((float)($row['tva_rate'] ?? 0), 3),
        'unit' => (string)($row['unit'] ?? 'piece'),
    ];
}

function supplierOrderRow(array $row, array $items = [], array $receptions = []): array
{
    $linkedBillIds = array_values(array_map('intval', array_column($receptions, 'id')));
    $latestReception = end($receptions) ?: null;

    return [
        'id' => (int)($row['id'] ?? 0),
        'supplierId' => (int)($row['supplier_id'] ?? 0),
        'supplierName' => (string)($row['supplier_name'] ?? ''),
        'orderDate' => (string)($row['order_date'] ?? ''),
        'expectedDate' => (string)($row['expected_date'] ?? ''),
        'notes' => (string)($row['notes'] ?? ''),
        'orderNumber' => (string)($row['order_number'] ?? ''),
        'receivedDate' => $latestReception ? (string)($latestReception['received_date'] ?? '') : '',
        'status' => normalizeSupplierOrderStatus((string)($row['status'] ?? 'DRAFT')),
        'total' => round((float)($row['total'] ?? 0), 3),
        'orderedQty' => round((float)($row['ordered_qty'] ?? 0), 3),
        'receivedQty' => round((float)($row['received_qty'] ?? 0), 3),
        'items' => $items,
        'linkedSupplierBillId' => $linkedBillIds ? (int)end($linkedBillIds) : null,
        'linkedSupplierBillIds' => $linkedBillIds,
    ];
}

function listSupplierOrdersForUser(mysqli $conn, int $userId): array
{
    ensureSupplierOrdersSchema($conn);

    $stmt = $conn->prepare("
        SELECT so.*, s.name AS supplier_name
        FROM erp_supplier_orders so
        INNER JOIN suppliers s ON s.id = so.supplier_id AND s.user_id = so.user_id
        WHERE so.user_id = ?
        ORDER BY so.id DESC
    ");
    if (!$stmt) {
        throw new Exception('Failed to prepare supplier orders list: ' . $conn->error);
    }
    $stmt->bind_param('i', $userId);
    $stmt->execute();
    $orders = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);
    $stmt->close();

    if (!$orders) {
        return [];
    }

    $orderIds = array_map(static fn(array $row): int => (int)$row['id'], $orders);
    $orderIdsSql = implode(',', $orderIds);

    $itemsResult = $conn->query("
        SELECT *
        FROM erp_supplier_order_items
        WHERE supplier_order_id IN ($orderIdsSql)
        ORDER BY id ASC
    ");
    if (!$itemsResult) {
        throw new Exception('Failed to load supplier order items: ' . $conn->error);
    }

    $itemsByOrder = [];
    while ($item = $itemsResult->fetch_assoc()) {
        $orderId = (int)$item['supplier_order_id'];
        $itemsByOrder[$orderId][] = supplierOrderItemRow($item);
    }
    $itemsResult->close();

    $receptionsResult = $conn->query("
        SELECT id, supplier_order_id, received_date
        FROM erp_supplier_receptions
        WHERE user_id = $userId AND supplier_order_id IN ($orderIdsSql)
        ORDER BY received_date ASC, id ASC
    ");

    $receptionsByOrder = [];
    if ($receptionsResult instanceof mysqli_result) {
        while ($reception = $receptionsResult->fetch_assoc()) {
            $orderId = (int)$reception['supplier_order_id'];
            $receptionsByOrder[$orderId][] = $reception;
        }
        $receptionsResult->close();
    }

    return array_map(
        static fn(array $row): array => supplierOrderRow(
            $row,
            $itemsByOrder[(int)$row['id']] ?? [],
            $receptionsByOrder[(int)$row['id']] ?? []
        ),
        $orders
    );
}

function getSupplierOrderForUser(mysqli $conn, int $userId, int $orderId): ?array
{
    ensureSupplierOrdersSchema($conn);
    $stmt = $conn->prepare("SELECT so.*,s.name supplier_name,
        (SELECT COALESCE(SUM(soi.qty),0) FROM erp_supplier_order_items soi WHERE soi.supplier_order_id=so.id) ordered_qty,
        (SELECT COALESCE(SUM(sri.accepted_qty),0)
         FROM erp_supplier_receptions sr
         JOIN erp_supplier_reception_items sri ON sri.supplier_reception_id=sr.id
         WHERE sr.supplier_order_id=so.id AND sr.user_id=so.user_id AND sr.stock_applied=1) received_qty
        FROM erp_supplier_orders so
        JOIN suppliers s ON s.id=so.supplier_id AND s.user_id=so.user_id
        WHERE so.id=? AND so.user_id=? LIMIT 1");
    $stmt->bind_param('ii', $orderId, $userId);
    $stmt->execute();
    $order = $stmt->get_result()->fetch_assoc();
    $stmt->close();
    if (!$order) return null;

    $stmt = $conn->prepare('SELECT * FROM erp_supplier_order_items WHERE supplier_order_id=? ORDER BY id');
    $stmt->bind_param('i', $orderId);
    $stmt->execute();
    $items = array_map('supplierOrderItemRow', $stmt->get_result()->fetch_all(MYSQLI_ASSOC));
    $stmt->close();

    $stmt = $conn->prepare('SELECT id,supplier_order_id,received_date FROM erp_supplier_receptions WHERE supplier_order_id=? AND user_id=? ORDER BY received_date,id');
    $stmt->bind_param('ii', $orderId, $userId);
    $stmt->execute();
    $receptions = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);
    $stmt->close();
    return supplierOrderRow($order, $items, $receptions);
}
