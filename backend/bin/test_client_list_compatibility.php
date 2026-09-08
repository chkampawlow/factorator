<?php

declare(strict_types=1);

require_once __DIR__ . '/../clients/list_query.php';

$failures = [];

function clientListCheck(bool $condition, string $message): void
{
    global $failures;
    if (!$condition) {
        $failures[] = $message;
    }
}

$legacyColumns = array_fill_keys(
    ['id', 'type', 'name', 'email', 'phone', 'address', 'fiscalId', 'cin', 'user_id'],
    true
);
$currentColumns = $legacyColumns + [
    'reference' => true,
    'payment_terms_days' => true,
];

$legacySelect = clientListSelectSql($legacyColumns);
clientListCheck(
    str_contains($legacySelect, 'CAST(NULL AS CHAR) AS reference'),
    'Legacy schemas must receive a nullable reference projection.'
);
clientListCheck(
    str_contains($legacySelect, '30 AS payment_terms_days'),
    'Legacy schemas must receive the default payment term projection.'
);
clientListCheck(
    !str_contains(clientListSearchSql($legacyColumns), 'reference'),
    'Legacy search must not query a missing reference column.'
);
clientListCheck(
    clientListMissingMigrationColumns($legacyColumns) === ['reference', 'payment_terms_days'],
    'Both pending client migration columns must be reported.'
);

$currentSelect = clientListSelectSql($currentColumns);
clientListCheck(
    str_contains($currentSelect, 'reference')
        && !str_contains($currentSelect, 'CAST(NULL AS CHAR) AS reference'),
    'Current schemas must return stored client references.'
);
clientListCheck(
    str_contains($currentSelect, 'payment_terms_days')
        && !str_contains($currentSelect, '30 AS payment_terms_days'),
    'Current schemas must return stored client payment terms.'
);
clientListCheck(
    str_contains(clientListSearchSql($currentColumns), 'reference'),
    'Current search must include client references.'
);
clientListCheck(
    clientListMissingMigrationColumns($currentColumns) === [],
    'Current schemas must not report pending client migration columns.'
);

if ($failures) {
    fwrite(STDERR, "Client list compatibility test failed:\n- " . implode("\n- ", $failures) . "\n");
    exit(1);
}

echo "Client list compatibility test passed.\n";
