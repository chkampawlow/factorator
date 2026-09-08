<?php

declare(strict_types=1);

if (PHP_SAPI !== 'cli') { http_response_code(404); exit; }

require_once __DIR__ . '/../auth/role_helper.php';

$failures = [];

function financePermissionCheck(bool $passed, string $label, array &$failures): void
{
    echo ($passed ? 'PASS ' : 'FAIL ') . $label . PHP_EOL;
    if (!$passed) $failures[] = $label;
}

function financeSource(string $relativePath): string
{
    $source = file_get_contents(dirname(__DIR__) . '/' . $relativePath);
    if ($source === false) throw new RuntimeException("Could not read $relativePath");
    return $source;
}

/** @return string[] */
function typescriptRolePermissions(string $source, string $role): array
{
    if (!preg_match('/\\b' . preg_quote($role, '/') . ':\\s*\\[(.*?)\\],/s', $source, $match)) {
        throw new RuntimeException("Could not parse the $role frontend permission block");
    }
    preg_match_all("/'([^']+)'/", $match[1], $permissions);
    return array_values(array_unique($permissions[1] ?? []));
}

$financeCapabilities = [
    'invoices.view', 'invoices.create', 'invoices.edit', 'invoices.delete',
    'invoices.validate', 'invoices.send', 'invoices.credit',
    'devis.view', 'devis.create', 'devis.edit', 'devis.delete', 'devis.validate', 'devis.send',
    'avoirs.view', 'avoirs.create', 'avoirs.edit', 'avoirs.delete', 'avoirs.validate', 'avoirs.send',
    'payments.view', 'payments.record', 'payments.void',
    'withholding.view', 'withholding.record', 'withholding.edit',
];

$expected = [
    'COMMERCIAL' => [
        'invoices.view', 'invoices.create', 'invoices.edit', 'invoices.delete',
        'devis.view', 'devis.create', 'devis.edit', 'devis.delete', 'devis.validate', 'devis.send',
        'avoirs.view',
    ],
    'ACCOUNTING' => [
        'invoices.view', 'invoices.create', 'invoices.edit', 'invoices.delete',
        'invoices.validate', 'invoices.send', 'invoices.credit',
        'avoirs.view', 'avoirs.create', 'avoirs.edit', 'avoirs.delete', 'avoirs.validate', 'avoirs.send',
        'payments.view', 'payments.record', 'payments.void',
        'withholding.view', 'withholding.record', 'withholding.edit',
    ],
];

$frontendMatrixPath = trim((string)(getenv('FRONTEND_ROLE_ACCESS_PATH') ?: ''));
if ($frontendMatrixPath === '') {
    $frontendMatrixPath = dirname(__DIR__, 2) . '/src/app/core/role-access.ts';
}
$frontendSource = is_file($frontendMatrixPath) ? file_get_contents($frontendMatrixPath) : false;
$backendMatrix = rolePermissions();
foreach ($expected as $role => $roleExpected) {
    $backendActual = array_values(array_intersect($financeCapabilities, $backendMatrix[$role] ?? []));
    sort($roleExpected); sort($backendActual);
    financePermissionCheck($backendActual === $roleExpected, "$role has the exact PHP finance capability contract", $failures);
    if ($frontendSource !== false) {
        $frontendActual = array_values(array_intersect($financeCapabilities, typescriptRolePermissions($frontendSource, $role)));
        sort($frontendActual);
        financePermissionCheck($frontendActual === $roleExpected, "$role has the exact frontend finance capability contract", $failures);
        financePermissionCheck($backendActual === $frontendActual, "$role frontend and PHP finance capabilities are identical", $failures);
    }
}
if ($frontendSource === false) {
    echo "SKIP frontend/PHP parity: set FRONTEND_ROLE_ACCESS_PATH when the Angular source is stored outside this runtime." . PHP_EOL;
}

$guardContracts = [
    'invoices/get_invoices.php' => ['requireAnyInvoiceDocumentView($conn,$user_id)'],
    'invoices/add_invoice.php' => [
        "requireInvoiceDocumentPermission(\$conn, \$user_id, \$invoice_type, 'create')",
        "requirePermission(\$conn, \$user_id, 'invoices.credit')",
    ],
    'invoices/update_invoice.php' => [
        "requireInvoiceDocumentPermission(\$conn, \$user_id, \$invoiceType, 'edit')",
        "requireInvoiceDocumentPermission(\$conn, \$user_id, \$invoiceType, 'validate')",
        "requireInvoiceDocumentPermission(\$conn, \$user_id, \$invoiceType, 'send')",
        "requirePermission(\$conn, \$user_id, 'invoices.credit')",
    ],
    'mailer/send_invoice_pdf.php' => [
        "requireInvoiceDocumentPermission(\$conn, \$userId, \$actualType, 'send')",
        'document_id', 'is_validated', 'actualStatus',
    ],
    'invoice_settlements/add_payment.php' => ["requirePermission(\$conn, \$userId, 'payments.record')"],
    'invoice_settlements/void_payment.php' => ["requirePermission(\$conn, \$userId, 'payments.void')"],
    'invoice_settlements/add_withholding.php' => ["requirePermission(\$conn, \$userId, 'withholding.record')"],
    'invoice_settlements/update_withholding.php' => ["requirePermission(\$conn, \$userId, 'withholding.edit')"],
    'einvoices/get.php' => ["requirePermission(\$conn, \$userId, 'invoices.send')"],
    'einvoices/prepare.php' => ["requirePermission(\$conn, \$userId, 'invoices.send')"],
    'einvoices/retry.php' => ["requirePermission(\$conn, \$userId, 'invoices.send')"],
];

foreach ($guardContracts as $file => $needles) {
    $source = financeSource($file);
    foreach ($needles as $needle) {
        financePermissionCheck(str_contains($source, $needle), "$file contains action guard $needle", $failures);
    }
    financePermissionCheck(
        !preg_match("/'(?:invoices|devis|avoirs|payments|withholding)\\.manage'/", $source),
        "$file has no broad legacy finance authorization guard",
        $failures
    );
}

$settlement = financeSource('invoice_settlements/get.php');
foreach ([
    "['invoices.view','payments.view','withholding.view']",
    "userHasPermission(\$c,\$uid,'payments.view')",
    "userHasPermission(\$c,\$uid,'withholding.view')",
    '$payments=[];$withholdings=[]',
    "'summary'=>\$summary", "'payments'=>\$payments", "'withholdings'=>\$withholdings",
] as $needle) {
    financePermissionCheck(str_contains($settlement, $needle), "settlement response enforces $needle", $failures);
}

$unsafeSettlementPatterns = [
    '/SELECT\\s+(?:p|w)\\.\\*/i' => 'wildcard ledger projection',
    '/\\bp\\.proof_(?:name|mime)\\b/i' => 'payment evidence metadata',
    '/\\bw\\.attachment_(?:name|mime)\\b/i' => 'withholding attachment metadata',
    '/(?:proof|attachment)_path\\s+(?:AS\\s+)?path/i' => 'private storage path alias',
];
foreach ($unsafeSettlementPatterns as $pattern => $label) {
    financePermissionCheck(!preg_match($pattern, $settlement), "settlement response omits $label", $failures);
}

$clientOptions = financeSource('clients/options.php');
$productOptions = financeSource('products/options.php');
foreach (['invoices.view', 'invoices.create', 'invoices.edit', 'devis.view', 'avoirs.view'] as $capability) {
    financePermissionCheck(str_contains($clientOptions, "'$capability'"), "client selector accepts $capability", $failures);
    financePermissionCheck(str_contains($productOptions, "'$capability'"), "product selector accepts $capability", $failures);
}
foreach (['last_purchase_price', 'average_cost', 'reorder_point', 'stock_value'] as $sensitiveCostField) {
    financePermissionCheck(!str_contains($productOptions, $sensitiveCostField), "product selector omits $sensitiveCostField", $failures);
}
financePermissionCheck(!preg_match('/SELECT\\s+\\*/i', $clientOptions . "\n" . $productOptions), 'selector projections are explicit', $failures);

if ($failures !== []) {
    fwrite(STDERR, 'Finance action permission contract failed (' . count($failures) . ' checks).' . PHP_EOL);
    exit(1);
}

echo 'Finance action permission contract passed.' . PHP_EOL;
