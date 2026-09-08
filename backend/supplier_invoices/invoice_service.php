<?php

function supplierInvoiceMatchStatus(int $lineCount, int $unmatchedCount, int $varianceCount, int $partialCount): string
{
    if ($lineCount <= 0 || $unmatchedCount > 0) return 'UNMATCHED';
    if ($varianceCount > 0) return 'VARIANCE';
    return $partialCount > 0 ? 'PARTIAL' : 'MATCHED';
}

function supplierInvoiceListRow(array $row): array
{
    $total = round((float)($row['total_ttc'] ?? 0), 3);
    $paid = round((float)($row['paid_amount'] ?? 0), 3);
    $credited = round((float)($row['credited_amount'] ?? 0), 3);
    $balance = max(0, round($total - $paid - $credited, 3));
    $lineCount = (int)($row['line_count'] ?? 0);
    $unmatchedCount = (int)($row['unmatched_count'] ?? 0);
    $varianceCount = (int)($row['variance_count'] ?? 0);
    $partialCount = (int)($row['partial_count'] ?? 0);

    return [
        'id' => (int)($row['id'] ?? 0),
        'supplierId' => (int)($row['supplier_id'] ?? 0),
        'supplierName' => (string)($row['supplier_name'] ?? ''),
        'supplierOrderId' => isset($row['supplier_order_id']) ? (int)$row['supplier_order_id'] : null,
        'supplierOrderNumber' => (string)($row['order_number'] ?? ''),
        'invoiceNumber' => (string)($row['invoice_number'] ?? ''),
        'invoiceDate' => (string)($row['invoice_date'] ?? ''),
        'dueDate' => (string)($row['due_date'] ?? ''),
        'status' => (string)($row['status'] ?? 'DRAFT'),
        'currency' => (string)($row['currency'] ?? 'TND'),
        'exchangeRate' => round((float)($row['exchange_rate'] ?? 1), 8),
        'totalHt' => round((float)($row['total_ht'] ?? 0), 3),
        'totalVat' => round((float)($row['total_vat'] ?? 0), 3),
        'totalTtc' => $total,
        'totalTtcTnd' => round((float)($row['total_ttc_tnd'] ?? $total), 3),
        'paidAmount' => $paid,
        'creditedAmount' => $credited,
        'balance' => $balance,
        'balanceTnd' => round($balance * (float)($row['exchange_rate'] ?? 1), 3),
        'lineCount' => $lineCount,
        'unmatchedCount' => $unmatchedCount,
        'varianceCount' => $varianceCount,
        'partialCount' => $partialCount,
        'matchStatus' => supplierInvoiceMatchStatus($lineCount, $unmatchedCount, $varianceCount, $partialCount),
        'validatedAt' => $row['validated_at'] ? (string)$row['validated_at'] : '',
        'createdAt' => (string)($row['created_at'] ?? ''),
    ];
}

function supplierInvoiceHeaderSelect(): string
{
    return "
        SELECT si.*, s.name supplier_name, so.order_number,
            COALESCE((SELECT SUM(sp.amount) FROM erp_supplier_payments sp WHERE sp.supplier_invoice_id=si.id AND sp.user_id=si.user_id AND sp.voided_at IS NULL),0) paid_amount,
            (SELECT COUNT(*) FROM erp_supplier_invoice_items sii WHERE sii.supplier_invoice_id=si.id) line_count,
            (SELECT COUNT(*) FROM erp_supplier_invoice_items sii WHERE sii.supplier_invoice_id=si.id AND sii.supplier_reception_item_id IS NULL) unmatched_count,
            (SELECT COUNT(*)
             FROM erp_supplier_invoice_items sii
             JOIN erp_supplier_reception_items sri ON sri.id=sii.supplier_reception_item_id
             WHERE sii.supplier_invoice_id=si.id
               AND (ABS(sii.unit_price-COALESCE((SELECT soi.price FROM erp_supplier_order_items soi WHERE soi.supplier_order_id=si.supplier_order_id AND ((sri.catalog_id IS NOT NULL AND soi.catalog_id=sri.catalog_id) OR (sri.catalog_id IS NULL AND soi.product_code=sri.code)) ORDER BY soi.id LIMIT 1),sri.price))>0.0005 OR
                    COALESCE((SELECT SUM(all_items.quantity) FROM erp_supplier_invoice_items all_items JOIN erp_supplier_invoices all_invoices ON all_invoices.id=all_items.supplier_invoice_id WHERE all_items.supplier_reception_item_id=sri.id AND all_invoices.user_id=si.user_id AND all_invoices.status<>'CANCELLED'),0)>sri.accepted_qty+0.0005)) variance_count,
            (SELECT COUNT(*)
             FROM erp_supplier_invoice_items sii
             JOIN erp_supplier_reception_items sri ON sri.id=sii.supplier_reception_item_id
             WHERE sii.supplier_invoice_id=si.id
               AND COALESCE((SELECT SUM(all_items.quantity) FROM erp_supplier_invoice_items all_items JOIN erp_supplier_invoices all_invoices ON all_invoices.id=all_items.supplier_invoice_id WHERE all_items.supplier_reception_item_id=sri.id AND all_invoices.user_id=si.user_id AND all_invoices.status<>'CANCELLED'),0)<sri.accepted_qty-0.0005) partial_count
        FROM erp_supplier_invoices si
        JOIN suppliers s ON s.id=si.supplier_id AND s.user_id=si.user_id
        LEFT JOIN erp_supplier_orders so ON so.id=si.supplier_order_id AND so.user_id=si.user_id
    ";
}
