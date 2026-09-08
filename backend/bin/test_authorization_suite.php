<?php

declare(strict_types=1);

$tests = [
    'verify_permission_matrix.php',
    'test_finance_action_permissions.php',
    'verify_tenant_isolation.php',
    'test_company_invitation_lifecycle.php',
    'test_http_role_authorization.php',
    'test_http_tenant_isolation.php',
];

$failures = [];
foreach ($tests as $test) {
    echo PHP_EOL . '=== ' . $test . ' ===' . PHP_EOL;
    passthru(escapeshellarg(PHP_BINARY) . ' ' . escapeshellarg(__DIR__ . '/' . $test), $exitCode);
    if ($exitCode !== 0) {
        $failures[] = $test;
    }
}

echo PHP_EOL;
if ($failures !== []) {
    fwrite(STDERR, 'Authorization suite failed: ' . implode(', ', $failures) . PHP_EOL);
    exit(1);
}

echo 'Authorization suite passed (' . count($tests) . ' checks).' . PHP_EOL;
