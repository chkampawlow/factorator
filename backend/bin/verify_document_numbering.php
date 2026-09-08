<?php

declare(strict_types=1);

if (PHP_SAPI !== 'cli') { http_response_code(404); exit; }
require_once __DIR__ . '/../config/db.php';
require_once __DIR__ . '/../invoices/document_number.php';

$conn = db();
$checks = [
    'duplicate sales numbers per company' => "SELECT COUNT(*) FROM (SELECT user_id,invoice FROM erp_invoices WHERE invoice<>'' GROUP BY user_id,invoice HAVING COUNT(*)>1) x",
    'duplicate order numbers per company' => "SELECT COUNT(*) FROM (SELECT user_id,order_number FROM erp_sales_orders WHERE order_number<>'' GROUP BY user_id,order_number HAVING COUNT(*)>1) x",
    'duplicate delivery numbers per company' => "SELECT COUNT(*) FROM (SELECT user_id,delivery_number FROM erp_delivery_notes WHERE delivery_number<>'' GROUP BY user_id,delivery_number HAVING COUNT(*)>1) x",
    'invalid sequences' => "SELECT COUNT(*) FROM erp_document_number_sequences WHERE document_type NOT IN('FACTURE','DEVIS','AVOIR','BON_COMMANDE','BON_LIVRAISON','BON_SORTIE') OR document_year NOT BETWEEN 2000 AND 2200 OR next_number<1",
];
$failures = [];
foreach ($checks as $name => $sql) {
    $count = (int)$conn->query($sql)->fetch_row()[0];
    echo ($count === 0 ? 'PASS ' : 'FAIL ') . "$name $count" . PHP_EOL;
    if ($count !== 0) $failures[] = $name;
}

$legacyCount = (int)$conn->query("SELECT COUNT(*) FROM erp_invoices WHERE is_validated=1 AND invoice_type IN('FACTURE','AVOIR','DEVIS') AND invoice NOT REGEXP '^(FAC|AV|DEV)-[0-9]{4}-[0-9]{6}$'")->fetch_row()[0];
echo "INFO legacy issued document numbers retained for audit continuity: $legacyCount" . PHP_EOL;

foreach ([['2026-08-10', '2026-09-09', true], ['2026-02-29', '2026-03-01', false], ['2026-08-10', '2026-08-09', false]] as [$date, $due, $valid]) {
    try { validateDocumentDates($date, $due); $actual = true; } catch (Throwable) { $actual = false; }
    echo ($actual === $valid ? 'PASS ' : 'FAIL ') . "dates $date / $due" . PHP_EOL;
    if ($actual !== $valid) $failures[] = "dates $date / $due";
}

$userId = (int)$conn->query("SELECT id FROM users WHERE account_status='ACTIVE' ORDER BY id LIMIT 1")->fetch_row()[0];
if ($userId <= 0) throw new RuntimeException('An active company is required for numbering verification.');
$conn->begin_transaction();
try {
    $first = nextDocumentNumber($conn, $userId, 'FACTURE', '2199-01-01');
    $second = nextDocumentNumber($conn, $userId, 'FACTURE', '2199-01-01');
    $a = (int)substr($first, -6); $b = (int)substr($second, -6);
    $passed = preg_match('/^FAC-2199-[0-9]{6}$/', $first) === 1 && $b === $a + 1;
    echo ($passed ? 'PASS ' : 'FAIL ') . "transactional sequence $first -> $second" . PHP_EOL;
    if (!$passed) $failures[] = 'transactional sequence';
} finally {
    $conn->rollback();
}

if ($failures !== []) exit(1);
echo 'Document numbering verification passed.' . PHP_EOL;
