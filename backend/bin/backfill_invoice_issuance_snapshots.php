<?php

declare(strict_types=1);

if (PHP_SAPI !== 'cli') {
    http_response_code(404);
    exit;
}

require_once __DIR__ . '/../config/db.php';
require_once __DIR__ . '/../invoices/issuance_snapshot_service.php';

$conn = db();
$table = $conn->query("SHOW TABLES LIKE 'erp_invoice_issuance_snapshots'")->fetch_row();
if (!$table) {
    fwrite(STDERR, "Apply 2026-08-25-immutable-invoice-issuance-snapshots.sql first.\n");
    exit(2);
}

$result = $conn->query("SELECT i.id,i.user_id,co.owner_user_id
    FROM erp_invoices i
    JOIN companies co ON co.id=i.user_id
    LEFT JOIN erp_invoice_issuance_snapshots s ON s.invoice_id=i.id
    WHERE i.is_validated=1 AND i.invoice_type IN('FACTURE','DEVIS','AVOIR') AND s.id IS NULL
    ORDER BY i.id");
$rows = $result->fetch_all(MYSQLI_ASSOC);
$result->free();
$captured = 0;

foreach ($rows as $row) {
    $conn->begin_transaction();
    try {
        captureInvoiceIssuanceSnapshot(
            $conn,
            (int)$row['user_id'],
            (int)$row['owner_user_id'],
            (int)$row['id']
        );
        $conn->commit();
        $captured++;
    } catch (Throwable $error) {
        $conn->rollback();
        fwrite(STDERR, 'Invoice ' . (int)$row['id'] . ': ' . $error->getMessage() . PHP_EOL);
        exit(1);
    }
}

echo "Captured $captured legacy invoice issuance snapshot(s)." . PHP_EOL;
