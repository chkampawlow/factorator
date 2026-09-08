<?php

if (PHP_SAPI !== 'cli') {
    http_response_code(404);
    exit;
}

require_once __DIR__ . '/../config/db.php';

$queries = [
    'invoice_lines' => "SELECT COUNT(*) FROM erp_invoice_items ii
        WHERE ABS(ii.subtotal - ROUND(ii.qty * ii.price * (1 - ii.discount / 100), 3)) >= 0.0005
           OR ABS(ii.fodec_amount - ROUND(ii.subtotal * ii.fodec_rate / 100, 3)) >= 0.0005
           OR ABS(ii.montant_tva - ROUND((ii.subtotal + ii.fodec_amount) *
                CASE WHEN ii.tax_regime='STANDARD' THEN ii.tva_rate ELSE 0 END / 100, 3)) >= 0.0005",
    'invoice_headers' => "SELECT COUNT(*) FROM erp_invoices i LEFT JOIN (
            SELECT invoice_id, ROUND(COALESCE(SUM(subtotal),0),3) ht,
                   ROUND(COALESCE(SUM(fodec_amount),0),3) fodec,
                   ROUND(COALESCE(SUM(montant_tva),0),3) vat,
                   ROUND(COALESCE(SUM(subtotalTTC),0),3) ttc,
                   ROUND(COALESCE(SUM(total_tnd),0),3) total_tnd
            FROM erp_invoice_items GROUP BY invoice_id
        ) x ON x.invoice_id=i.id
        WHERE ABS(i.subtotal-COALESCE(x.ht,0)) >= 0.0005
           OR ABS(i.base_tva-ROUND(COALESCE(x.ht,0)+COALESCE(x.fodec,0),3)) >= 0.0005
           OR ABS(i.montant_tva-COALESCE(x.vat,0)) >= 0.0005
           OR ABS(i.subtotal_ttc-COALESCE(x.ttc,0)) >= 0.0005
           OR ABS(i.total-ROUND(COALESCE(x.ttc,0)+i.shipping-i.discount+
                CASE WHEN i.invoice_type='AVOIR' THEN -i.timbre ELSE i.timbre END,3)) >= 0.0005
           OR ABS(i.total_tnd-ROUND(COALESCE(x.total_tnd,0)+(i.shipping-i.discount+
                CASE WHEN i.invoice_type='AVOIR' THEN -i.timbre ELSE i.timbre END)*i.exchange_rate,3)) >= 0.0005",
    'sales_orders' => "SELECT COUNT(*) FROM erp_sales_orders o LEFT JOIN (
            SELECT sales_order_id, ROUND(COALESCE(SUM(subtotal),0),3) ht,
                   ROUND(COALESCE(SUM(montant_tva),0),3) vat,
                   ROUND(COALESCE(SUM(total),0),3) total
            FROM erp_sales_order_items GROUP BY sales_order_id
        ) x ON x.sales_order_id=o.id
        WHERE ABS(o.subtotal-COALESCE(x.ht,0)) >= 0.0005
           OR ABS(o.montant_tva-COALESCE(x.vat,0)) >= 0.0005
           OR ABS(o.total-COALESCE(x.total,0)) >= 0.0005",
    'delivery_item_counts' => "SELECT COUNT(*) FROM erp_delivery_notes d LEFT JOIN (
            SELECT delivery_note_id, COUNT(*) item_count FROM erp_delivery_note_items GROUP BY delivery_note_id
        ) x ON x.delivery_note_id=d.id WHERE d.item_count <> COALESCE(x.item_count,0)",
    'supplier_orders' => "SELECT COUNT(*) FROM erp_supplier_orders o LEFT JOIN (
            SELECT supplier_order_id, ROUND(SUM(ROUND(qty*price,3)),3) ht,
                   ROUND(SUM(ROUND(ROUND(qty*price,3)*tva_rate/100,3)),3) vat,
                   ROUND(SUM(line_total),3) total
            FROM erp_supplier_order_items GROUP BY supplier_order_id
        ) x ON x.supplier_order_id=o.id
        WHERE ABS(o.subtotal-COALESCE(x.ht,0)) >= 0.0005
           OR ABS(o.total_vat-COALESCE(x.vat,0)) >= 0.0005
           OR ABS(o.total-COALESCE(x.total,0)) >= 0.0005",
    'supplier_receptions' => "SELECT COUNT(*) FROM erp_supplier_receptions r LEFT JOIN (
            SELECT supplier_reception_id, ROUND(SUM(subtotal),3) ht,
                   ROUND(SUM(ROUND(subtotal*tva_rate/100,3)),3) vat,
                   ROUND(SUM(subtotal+ROUND(subtotal*tva_rate/100,3)),3) total
            FROM erp_supplier_reception_items GROUP BY supplier_reception_id
        ) x ON x.supplier_reception_id=r.id
        WHERE ABS(r.total_ht-COALESCE(x.ht,0)) >= 0.0005
           OR ABS(r.total_vat-COALESCE(x.vat,0)) >= 0.0005
           OR ABS(r.total_ttc-COALESCE(x.total,0)) >= 0.0005",
    'supplier_invoices' => "SELECT COUNT(*) FROM erp_supplier_invoices i LEFT JOIN (
            SELECT supplier_invoice_id, ROUND(SUM(total_ht),3) ht,
                   ROUND(SUM(total_vat),3) vat, ROUND(SUM(total_ttc),3) total,
                   ROUND(SUM(total_ht_tnd),3) ht_tnd, ROUND(SUM(total_tax_tnd),3) tax_tnd,
                   ROUND(SUM(total_ttc_tnd),3) total_tnd
            FROM erp_supplier_invoice_items GROUP BY supplier_invoice_id
        ) x ON x.supplier_invoice_id=i.id
        WHERE ABS(i.total_ht-COALESCE(x.ht,0)) >= 0.0005
           OR ABS(i.total_vat-COALESCE(x.vat,0)) >= 0.0005
           OR ABS(i.total_ttc-COALESCE(x.total,0)) >= 0.0005
           OR ABS(i.total_ht_tnd-COALESCE(x.ht_tnd,0)) >= 0.0005
           OR ABS(i.total_tax_tnd-COALESCE(x.tax_tnd,0)) >= 0.0005
           OR ABS(i.total_ttc_tnd-COALESCE(x.total_tnd,0)) >= 0.0005",
];

$conn = db();
$results = [];
foreach ($queries as $name => $sql) {
    $results[$name] = (int) $conn->query($sql)->fetch_row()[0];
}
$success = array_sum($results) === 0;

echo json_encode([
    'success' => $success,
    'tolerance' => '0.0005 TND',
    'discrepancies' => $results,
], JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES) . PHP_EOL;

exit($success ? 0 : 1);
