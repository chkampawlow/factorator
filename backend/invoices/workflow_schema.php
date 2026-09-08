<?php

function workflowColumnExists(mysqli $conn, string $table, string $column): bool
{
    $tableEscaped = $conn->real_escape_string($table);
    $columnEscaped = $conn->real_escape_string($column);
    $result = $conn->query("SHOW COLUMNS FROM `{$tableEscaped}` LIKE '{$columnEscaped}'");
    if (!$result) {
        throw new Exception('Failed to inspect workflow schema: ' . $conn->error);
    }
    $exists = $result->num_rows > 0;
    $result->close();
    return $exists;
}

function ensureInvoiceWorkflowSchema(mysqli $conn): void
{
    static $checked = false;
    if ($checked) return;
    $conn->query("SELECT transformation_status FROM erp_invoices LIMIT 0");
    $conn->query("SELECT source_devis_id FROM erp_sales_orders LIMIT 0");
    $checked = true;
}

function recalculateDevisTransformationStatus(mysqli $conn, int $devisId, int $userId): string
{
    ensureInvoiceWorkflowSchema($conn);

    $devisItemsStmt = $conn->prepare("
        SELECT product_id, product_code, product, qty
        FROM erp_invoice_items
        WHERE invoice_id = ?
        ORDER BY id
    ");
    if (!$devisItemsStmt) {
        throw new Exception('Failed to prepare devis items lookup: ' . $conn->error);
    }
    $devisItemsStmt->bind_param('i', $devisId);
    $devisItemsStmt->execute();
    $devisItems = $devisItemsStmt->get_result()->fetch_all(MYSQLI_ASSOC);
    $devisItemsStmt->close();

    if (!$devisItems) {
        $status = 'NOT_TRANSFORMED';
    } else {
        $orderItemsStmt = $conn->prepare("
            SELECT soi.product_id, soi.product_code, soi.product, soi.qty
            FROM erp_sales_orders so
            INNER JOIN erp_sales_order_items soi ON soi.sales_order_id = so.id
            WHERE so.user_id = ? AND so.source_devis_id = ? AND so.status <> 'CANCELLED'
        ");
        if (!$orderItemsStmt) {
            throw new Exception('Failed to prepare linked order items lookup: ' . $conn->error);
        }
        $orderItemsStmt->bind_param('ii', $userId, $devisId);
        $orderItemsStmt->execute();
        $orderItems = $orderItemsStmt->get_result()->fetch_all(MYSQLI_ASSOC);
        $orderItemsStmt->close();

        $orderedByKey = [];
        foreach ($orderItems as $item) {
            $key = workflowItemKey($item['product_id'] ?? null, $item['product_code'] ?? '', $item['product'] ?? '');
            $orderedByKey[$key] = ($orderedByKey[$key] ?? 0.0) + abs((float)($item['qty'] ?? 0));
        }

        $hasAny = false;
        $allCovered = true;
        foreach ($devisItems as $item) {
            $key = workflowItemKey($item['product_id'] ?? null, $item['product_code'] ?? '', $item['product'] ?? '');
            $sourceQty = abs((float)($item['qty'] ?? 0));
            $orderedQty = (float)($orderedByKey[$key] ?? 0);
            if ($orderedQty > 0) {
                $hasAny = true;
            }
            if ($orderedQty + 0.0001 < $sourceQty) {
                $allCovered = false;
            }
        }

        if (!$hasAny) {
            $status = 'NOT_TRANSFORMED';
        } elseif ($allCovered) {
            $status = 'FULLY_ORDERED';
        } else {
            $status = 'PARTIALLY_ORDERED';
        }
    }

    $updateStmt = $conn->prepare("
        UPDATE erp_invoices
        SET transformation_status = ?
        WHERE id = ? AND user_id = ? AND UPPER(invoice_type) = 'DEVIS'
    ");
    if (!$updateStmt) {
        throw new Exception('Failed to prepare devis transformation update: ' . $conn->error);
    }
    $updateStmt->bind_param('sii', $status, $devisId, $userId);
    $updateStmt->execute();
    $updateStmt->close();

    return $status;
}

function workflowItemKey($productId, string $productCode, string $productLabel): string
{
    $numericId = (int)$productId;
    if ($numericId > 0) {
        return 'id:' . $numericId;
    }
    $normalizedCode = strtoupper(trim($productCode));
    if ($normalizedCode !== '') {
        return 'code:' . $normalizedCode;
    }
    return 'label:' . strtoupper(trim($productLabel));
}
