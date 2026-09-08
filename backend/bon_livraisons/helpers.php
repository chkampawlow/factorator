<?php

require_once __DIR__ . '/../products/product_inventory.php';

function ensureDeliverySchema(mysqli $conn): void
{
    static $checked = false;
    if ($checked) return;
    $conn->query("SELECT document_type,sales_order_id,vehicle_registration,movement_reason,stock_applied FROM erp_delivery_notes LIMIT 0");
    $conn->query("SELECT price,discount,tva_rate,subtotal,montant_tva,total FROM erp_delivery_note_items LIMIT 0");
    $checked = true;
}

function recalculateSalesOrderDeliveryStatus(mysqli $conn, int $salesOrderId, int $userId): void
{
    if ($salesOrderId <= 0) {
        return;
    }

    $orderStmt = $conn->prepare("SELECT status FROM erp_sales_orders WHERE id = ? AND user_id = ? LIMIT 1");
    $orderStmt->bind_param('ii', $salesOrderId, $userId);
    $orderStmt->execute();
    $order = $orderStmt->get_result()->fetch_assoc();
    $orderStmt->close();
    if (!$order) {
        return;
    }

    $orderedQtyStmt = $conn->prepare("SELECT COALESCE(SUM(qty), 0) AS qty FROM erp_sales_order_items WHERE sales_order_id = ?");
    $orderedQtyStmt->bind_param('i', $salesOrderId);
    $orderedQtyStmt->execute();
    $orderedQty = (float)($orderedQtyStmt->get_result()->fetch_assoc()['qty'] ?? 0);
    $orderedQtyStmt->close();

    $deliveredQtyStmt = $conn->prepare("
        SELECT COALESCE(SUM(di.qty), 0) AS qty
        FROM erp_delivery_note_items di
        INNER JOIN erp_delivery_notes dn ON dn.id = di.delivery_note_id
        WHERE dn.sales_order_id = ? AND dn.user_id = ? AND dn.status = 'DELIVERED'
    ");
    $deliveredQtyStmt->bind_param('ii', $salesOrderId, $userId);
    $deliveredQtyStmt->execute();
    $deliveredQty = (float)($deliveredQtyStmt->get_result()->fetch_assoc()['qty'] ?? 0);
    $deliveredQtyStmt->close();

    $targetStatus = 'CONFIRMED';
    if ($deliveredQty > 0 && $orderedQty > 0) {
        $targetStatus = $deliveredQty + 0.0001 >= $orderedQty ? 'DELIVERED' : 'PARTIALLY_DELIVERED';
    }

    if (!in_array((string)$order['status'], ['CANCELLED', 'INVOICED'], true)) {
        $updateStmt = $conn->prepare("UPDATE erp_sales_orders SET status = ? WHERE id = ? AND user_id = ?");
        $updateStmt->bind_param('sii', $targetStatus, $salesOrderId, $userId);
        $updateStmt->execute();
        $updateStmt->close();
    }
}

function applyDeliveryStockMovement(mysqli $conn, int $deliveryId, int $userId): void
{
    ensureProductInventorySchema($conn);

    $itemsStmt = $conn->prepare("
        SELECT di.id, di.product_id, di.qty, dn.document_type
        FROM erp_delivery_note_items di
        INNER JOIN erp_delivery_notes dn ON dn.id = di.delivery_note_id
        WHERE di.delivery_note_id = ?
        ORDER BY di.id
    ");
    $itemsStmt->bind_param('i', $deliveryId);
    $itemsStmt->execute();
    $items = $itemsStmt->get_result()->fetch_all(MYSQLI_ASSOC);
    $itemsStmt->close();

    foreach ($items as $item) {
        $productId = (int)($item['product_id'] ?? 0);
        if ($productId <= 0) {
          continue;
        }
        if (!productUsesStock($conn, $productId, $userId)) {
            continue;
        }
        $qty = (float)($item['qty'] ?? 0);
        $stock = getProductStockQuantity($conn, $productId, $userId);
        if ($stock + 0.0001 < $qty) {
            throw new Exception('Not enough stock to validate this delivery note');
        }
    }

    foreach ($items as $item) {
        $productId = (int)($item['product_id'] ?? 0);
        if ($productId <= 0) {
            continue;
        }
        if (!productUsesStock($conn, $productId, $userId)) {
            continue;
        }
        $qty = (float)($item['qty'] ?? 0);
        $isExitDocument = strtoupper((string)($item['document_type'] ?? 'DELIVERY')) === 'EXIT';
        recordProductStockMovement(
            $conn,
            $productId,
            $userId,
            -abs($qty),
            'DELIVERY_OUT',
            'DELIVERY_NOTE',
            $deliveryId,
            $isExitDocument ? 'Stock output from bon de sortie' : 'Stock output from delivery note'
        );
        syncProductStockQuantity($conn, $productId, $userId);
    }

    $markStmt = $conn->prepare("UPDATE erp_delivery_notes SET stock_applied = 1 WHERE id = ? AND user_id = ?");
    $markStmt->bind_param('ii', $deliveryId, $userId);
    $markStmt->execute();
    $markStmt->close();
}
