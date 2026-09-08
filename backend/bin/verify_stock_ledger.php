<?php

if (PHP_SAPI !== 'cli') {
    http_response_code(404);
    exit;
}

require_once __DIR__ . '/../config/db.php';

$conn = db();
$checks = [
    'quantity_discrepancies' => "SELECT COUNT(*) FROM products p LEFT JOIN (
        SELECT user_id,product_id,ROUND(COALESCE(SUM(quantity),0),3) quantity
        FROM product_stock_movements GROUP BY user_id,product_id
      ) m ON m.user_id=p.user_id AND m.product_id=p.id
      WHERE ABS(p.stock_quantity-CASE WHEN p.item_type='PRODUCT' THEN COALESCE(m.quantity,0) ELSE 0 END)>=0.0005",
    'service_ledger_nonzero' => "SELECT COUNT(*) FROM (SELECT p.id FROM products p
      JOIN product_stock_movements m ON m.product_id=p.id AND m.user_id=p.user_id
      WHERE p.item_type='SERVICE' GROUP BY p.id HAVING ABS(SUM(m.quantity))>=0.0005) x",
    'movement_tenant_mismatches' => "SELECT COUNT(*) FROM product_stock_movements m
      JOIN products p ON p.id=m.product_id WHERE p.user_id<>m.user_id",
    'orphan_movements' => "SELECT COUNT(*) FROM product_stock_movements m
      LEFT JOIN products p ON p.id=m.product_id WHERE p.id IS NULL",
];

$results = [];
foreach ($checks as $name => $sql) {
    $results[$name] = (int) $conn->query($sql)->fetch_row()[0];
}
$success = array_sum($results) === 0;

echo json_encode([
    'success' => $success,
    'source_of_truth' => 'product_stock_movements',
    'tolerance' => '0.0005 units',
    'discrepancies' => $results,
], JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES) . PHP_EOL;

exit($success ? 0 : 1);
