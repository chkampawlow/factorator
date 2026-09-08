<?php

declare(strict_types=1);

$tests = [
    'test_rounding_policy.php',
    'test_accountant_cases.php',
    'verify_financial_totals.php',
    'verify_fodec.php',
    'verify_stamp_duty.php',
    'verify_vat_carryforward.php',
    'verify_vat_classification.php',
    'verify_withholding_register.php',
    'verify_report_reconciliation.php',
];

$failures = [];

foreach ($tests as $test) {
    echo PHP_EOL . '=== ' . $test . ' ===' . PHP_EOL;
    $command = escapeshellarg(PHP_BINARY) . ' ' . escapeshellarg(__DIR__ . '/' . $test);
    passthru($command, $exitCode);
    if ($exitCode !== 0) {
        $failures[] = $test;
    }
}

echo PHP_EOL;
if ($failures !== []) {
    fwrite(STDERR, 'Accounting suite failed: ' . implode(', ', $failures) . PHP_EOL);
    exit(1);
}

echo 'Accounting suite passed (' . count($tests) . ' checks).' . PHP_EOL;
