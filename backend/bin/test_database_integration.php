<?php

declare(strict_types=1);

if (PHP_SAPI !== 'cli') { http_response_code(404); exit; }
require_once __DIR__ . '/../config/db.php';
require_once __DIR__ . '/../config/tenant_scope.php';
require_once __DIR__ . '/../invoices/document_number.php';

$conn = db();
$database = (string)$conn->query('SELECT DATABASE()')->fetch_row()[0];
if (!preg_match('/(?:^|_)(?:test|testing|local)(?:_|$)/i', $database)) {
    fwrite(STDERR, "REFUSED: integration fixtures may only run in a local/test database; connected to $database." . PHP_EOL);
    exit(2);
}

$marker = bin2hex(random_bytes(6));
$emails = ["integration-a-$marker@example.test", "integration-b-$marker@example.test"];
$failures = [];

function passOrFail(bool $passed, string $label, array &$failures): void
{
    echo ($passed ? 'PASS ' : 'FAIL ') . $label . PHP_EOL;
    if (!$passed) $failures[] = $label;
}

$conn->begin_transaction();
try {
    $insertUser = $conn->prepare("INSERT INTO users(organization_name,fiscal_id,email,password_hash,email_verified_at,role,account_status) VALUES(?,?,?,?,NOW(),'ADMINISTRATOR','ACTIVE')");
    $password = password_hash('Integration-only-password-2026!', PASSWORD_DEFAULT);
    $companyIds = [];
    foreach ([['Integration A', 'TESTA'], ['Integration B', 'TESTB']] as $index => [$name, $fiscalPrefix]) {
        $fiscalId = $fiscalPrefix . strtoupper($marker);
        $email = $emails[$index];
        $insertUser->bind_param('ssss', $name, $fiscalId, $email, $password);
        $insertUser->execute();
        $companyIds[] = (int)$conn->insert_id;
    }
    $insertUser->close();

    $clientStmt = $conn->prepare("INSERT INTO clients(reference,type,name,email,user_id) VALUES('C000001','ENTREPRISE',?,?,?)");
    $clientEmail = "client-$marker@example.test";
    $clientName = "Integration Client $marker";
    $clientStmt->bind_param('ssi', $clientName, $clientEmail, $companyIds[0]);
    $clientStmt->execute();
    $clientId = (int)$conn->insert_id;
    $clientStmt->close();

    $productStmt = $conn->prepare("INSERT INTO products(code,name,item_type,price,tva_rate,unit,stock_quantity,user_id) VALUES(?,?,'PRODUCT',125.375,19.000,'pièce',10.000,?)");
    $productCode = "INT-$marker"; $productName = "Integration Product $marker";
    $productStmt->bind_param('ssi', $productCode, $productName, $companyIds[0]);
    $productStmt->execute();
    $productId = (int)$conn->insert_id;
    $productStmt->close();

    requireTenantClient($conn, $companyIds[0], $clientId);
    passOrFail(true, 'own company can resolve its client', $failures);
    try { requireTenantClient($conn, $companyIds[1], $clientId); $foreignClientDenied = false; } catch (Throwable) { $foreignClientDenied = true; }
    passOrFail($foreignClientDenied, 'other company cannot resolve foreign client', $failures);

    requireTenantProduct($conn, $companyIds[0], $productId);
    passOrFail(true, 'own company can resolve its product', $failures);
    try { requireTenantProduct($conn, $companyIds[1], $productId); $foreignProductDenied = false; } catch (Throwable) { $foreignProductDenied = true; }
    passOrFail($foreignProductDenied, 'other company cannot resolve foreign product', $failures);

    $numberA = nextDocumentNumber($conn, $companyIds[0], 'FACTURE', '2026-08-10');
    $numberB = nextDocumentNumber($conn, $companyIds[1], 'FACTURE', '2026-08-10');
    passOrFail($numberA === 'FAC-2026-000001' && $numberB === 'FAC-2026-000001', 'number sequences are isolated per company', $failures);
} finally {
    $conn->rollback();
}

$placeholders = implode(',', array_fill(0, count($emails), '?'));
$cleanupCheck = $conn->prepare("SELECT COUNT(*) FROM users WHERE email IN ($placeholders)");
$cleanupCheck->bind_param('ss', ...$emails);
$cleanupCheck->execute();
$remaining = (int)$cleanupCheck->get_result()->fetch_row()[0];
$cleanupCheck->close();
passOrFail($remaining === 0, 'all integration fixtures rolled back', $failures);

if ($failures !== []) exit(1);
echo "Database integration suite passed on $database." . PHP_EOL;
