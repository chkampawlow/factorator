<?php

function requireTenantProduct(mysqli $conn, int $userId, int $productId): void
{
    if ($productId <= 0) return;
    $stmt = $conn->prepare('SELECT id FROM products WHERE id = ? AND user_id = ? LIMIT 1');
    $stmt->bind_param('ii', $productId, $userId);
    $stmt->execute();
    $found = (bool)$stmt->get_result()->fetch_assoc();
    $stmt->close();
    if (!$found) throw new Exception('Product not found or unauthorized');
}

function requireTenantSupplierOrderCatalogItem(mysqli $conn, int $userId, int $catalogId): void
{
    if ($catalogId <= 0) return;
    requireTenantProduct($conn, $userId, $catalogId);
}

function requireTenantSupplier(mysqli $conn, int $userId, int $supplierId): void
{
    $stmt = $conn->prepare('SELECT id FROM suppliers WHERE id = ? AND user_id = ? LIMIT 1');
    $stmt->bind_param('ii', $supplierId, $userId); $stmt->execute();
    $found = (bool)$stmt->get_result()->fetch_assoc(); $stmt->close();
    if (!$found) throw new Exception('Supplier not found or unauthorized');
}

function requireTenantClient(mysqli $conn, int $userId, int $clientId): void
{
    if ($clientId <= 0) return;
    $stmt = $conn->prepare('SELECT id FROM clients WHERE id = ? AND user_id = ? LIMIT 1');
    $stmt->bind_param('ii', $clientId, $userId); $stmt->execute();
    $found = (bool)$stmt->get_result()->fetch_assoc(); $stmt->close();
    if (!$found) throw new Exception('Client not found or unauthorized');
}

function requireTenantExpenseSource(mysqli $conn, int $userId, string $type, int $sourceId, int $supplierId = 0): void
{
    if ($sourceId <= 0) return;
    if ($type === 'SUPPLIER_ORDER') {
        if ($supplierId <= 0) throw new Exception('A supplier is required for the source order');
        requireTenantSupplierOrder($conn, $userId, $sourceId, $supplierId);
        return;
    }
    if ($type === 'SUPPLIER_RECEPTION') {
        $stmt = $conn->prepare('SELECT id FROM erp_supplier_receptions WHERE id=? AND user_id=? AND (?=0 OR supplier_id=?) LIMIT 1');
        $stmt->bind_param('iiii', $sourceId, $userId, $supplierId, $supplierId); $stmt->execute();
        $found = (bool)$stmt->get_result()->fetch_assoc(); $stmt->close();
        if (!$found) throw new Exception('Supplier reception not found or unauthorized');
        return;
    }
    throw new Exception('Unsupported expense source document');
}

function requireTenantSupplierOrder(mysqli $conn, int $userId, int $orderId, int $supplierId): void
{
    if ($orderId <= 0) return;
    $stmt = $conn->prepare('SELECT id FROM erp_supplier_orders WHERE id = ? AND user_id = ? AND supplier_id = ? LIMIT 1');
    $stmt->bind_param('iii', $orderId, $userId, $supplierId); $stmt->execute();
    $found = (bool)$stmt->get_result()->fetch_assoc(); $stmt->close();
    if (!$found) throw new Exception('Supplier order not found or unauthorized');
}

function requireTenantSupplierReceptionItem(mysqli $conn, int $userId, int $itemId, int $productId = 0): void
{
    if ($itemId <= 0) return;
    $sql = 'SELECT sri.id, sri.catalog_id FROM erp_supplier_reception_items sri JOIN erp_supplier_receptions sr ON sr.id = sri.supplier_reception_id WHERE sri.id = ? AND sr.user_id = ? LIMIT 1';
    $stmt = $conn->prepare($sql); $stmt->bind_param('ii', $itemId, $userId); $stmt->execute();
    $row = $stmt->get_result()->fetch_assoc(); $stmt->close();
    if (!$row || ($productId > 0 && (int)$row['catalog_id'] !== $productId)) {
        throw new Exception('Supplier reception item not found or unauthorized');
    }
}

function requireTenantSupplierReturn(mysqli $conn, int $userId, int $returnId): void
{
    if ($returnId <= 0) return;
    $stmt = $conn->prepare('SELECT id FROM erp_supplier_returns WHERE id = ? AND user_id = ? LIMIT 1');
    $stmt->bind_param('ii', $returnId, $userId); $stmt->execute();
    $found = (bool)$stmt->get_result()->fetch_assoc(); $stmt->close();
    if (!$found) throw new Exception('Supplier return not found or unauthorized');
}
