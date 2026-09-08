<?php

declare(strict_types=1);

if (PHP_SAPI !== 'cli') {
    http_response_code(404);
    exit;
}

require_once __DIR__ . '/../invoices/issuance_snapshot_service.php';

$failures = [];
function snapshotCheck(bool $condition, string $label, array &$failures): void
{
    echo ($condition ? 'PASS ' : 'FAIL ') . $label . PHP_EOL;
    if (!$condition) $failures[] = $label;
}

$first = [
    'version' => 1,
    'seller' => ['name' => 'El Fatoura', 'fiscal_id' => '1234567A'],
    'buyer' => ['name' => 'Client', 'email' => 'client@example.test'],
    'document' => ['number' => 'FAC-2026-1', 'subtotal' => '100.000', 'tax_total' => '19.000', 'stamp_duty' => '1.000', 'total' => '120.000'],
    'items' => [['code' => 'P-1', 'description' => 'Product', 'qty' => '1.000', 'price' => '100.000', 'discount' => '0.000', 'tva_rate' => '19.000', 'total' => '119.000']],
];
$second = [
    'items' => $first['items'], 'document' => $first['document'], 'buyer' => $first['buyer'],
    'seller' => $first['seller'], 'version' => 1,
];
$json = invoiceSnapshotJson($first);
$sameJson = invoiceSnapshotJson($second);
$hash = hash('sha256', $json);
snapshotCheck($json === $sameJson, 'canonical JSON is independent of associative key order', $failures);
snapshotCheck(invoiceSnapshotDecodeVerified($json, $hash)['document']['number'] === 'FAC-2026-1', 'valid snapshot hash is accepted', $failures);

$tamperRejected = false;
try {
    invoiceSnapshotDecodeVerified(str_replace('Client', 'Changed client', $json), $hash);
} catch (RuntimeException) {
    $tamperRejected = true;
}
snapshotCheck($tamperRejected, 'identity tampering invalidates the snapshot hash', $failures);

$projection = invoiceSnapshotPdfProjection($first);
snapshotCheck(
    $projection['company']['organization_name'] === 'El Fatoura'
        && $projection['document']['party_name'] === 'Client'
        && $projection['document']['items'][0]['description'] === 'Product',
    'PDF projection uses frozen seller, buyer and line data',
    $failures
);

if ($failures !== []) exit(1);
echo 'Invoice issuance snapshot verification passed.' . PHP_EOL;
