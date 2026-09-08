<?php

if (PHP_SAPI !== 'cli') {
    http_response_code(404);
    exit;
}

/**
 * Deterministic accounting regression cases.
 *
 * Expected values are deliberately written as fixed numbers and are not derived
 * from the implementation under test. These fixtures verify arithmetic and
 * rounding behavior; they do not replace validation by a Tunisian accountant.
 */
function amount3(float $value): float
{
    return round($value, 3, PHP_ROUND_HALF_UP);
}

function assertAmounts(string $case, array $actual, array $expected): array
{
    $differences = [];
    foreach ($expected as $key => $value) {
        $actualValue = (float) ($actual[$key] ?? NAN);
        if (!is_finite($actualValue) || abs($actualValue - (float) $value) >= 0.0005) {
            $differences[$key] = ['expected' => $value, 'actual' => $actual[$key] ?? null];
        }
    }

    return ['case' => $case, 'passed' => $differences === [], 'differences' => $differences];
}

$results = [];

$subtotal = amount3(7.35 * 128.475 * (1 - 3.7 / 100));
$fodec = amount3($subtotal * 1 / 100);
$vat = amount3(($subtotal + $fodec) * 19 / 100);
$results[] = assertAmounts('Invoice: discount, FODEC, VAT and stamp', [
    'subtotal' => $subtotal,
    'fodec' => $fodec,
    'vat' => $vat,
    'total' => amount3($subtotal + $fodec + $vat + 1.000),
], ['subtotal' => 909.352, 'fodec' => 9.094, 'vat' => 174.505, 'total' => 1093.951]);

$creditHt = amount3(3 * 87.425);
$creditFodec = amount3($creditHt * 1 / 100);
$creditVat = amount3(($creditHt + $creditFodec) * 19 / 100);
$results[] = assertAmounts('Credit note: revenue, FODEC, VAT and stamp reverse exactly once', [
    'subtotal' => -$creditHt,
    'fodec' => -$creditFodec,
    'vat' => -$creditVat,
    'stamp' => -1.000,
    'total' => amount3(-$creditHt - $creditFodec - $creditVat - 1.000),
], ['subtotal' => -262.275, 'fodec' => -2.623, 'vat' => -50.331, 'stamp' => -1.000, 'total' => -316.229]);

$results[] = assertAmounts('VAT: exempt and zero-rate lines do not create collected VAT', [
    'exempt_vat' => amount3(1845.775 * 0 / 100),
    'zero_rate_vat' => amount3(337.125 * 0 / 100),
], ['exempt_vat' => 0.000, 'zero_rate_vat' => 0.000]);

$collected = amount3(321.487 - 46.219);
$available = amount3(32.417 + 114.783);
$results[] = assertAmounts('VAT: payable after credit note and carry-forward', [
    'collected' => $collected,
    'available_credit' => $available,
    'payable' => amount3(max(0, $collected - $available)),
    'closing_credit' => amount3(max(0, $available - $collected)),
], ['collected' => 275.268, 'available_credit' => 147.200, 'payable' => 128.068, 'closing_credit' => 0.000]);

$available = amount3(17.219 + 125.337);
$results[] = assertAmounts('VAT: excess deductible credit carried forward', [
    'available_credit' => $available,
    'payable' => amount3(max(0, 88.645 - $available)),
    'closing_credit' => amount3(max(0, $available - 88.645)),
], ['available_credit' => 142.556, 'payable' => 0.000, 'closing_credit' => 53.911]);

$withheld = amount3(2380.000 * 1.5 / 100);
$results[] = assertAmounts('Withholding: certificate gross, tax and net', [
    'gross' => 2380.000,
    'withheld' => $withheld,
    'net_paid' => amount3(2380.000 - $withheld),
], ['gross' => 2380.000, 'withheld' => 35.700, 'net_paid' => 2344.300]);

$results[] = assertAmounts('Withholding: millime boundary uses half-up rounding', [
    'withheld' => amount3(123.450 * 1.5 / 100),
    'net_paid' => amount3(123.450 - amount3(123.450 * 1.5 / 100)),
], ['withheld' => 1.852, 'net_paid' => 121.598]);

$payroll = 18347.825;
$results[] = assertAmounts('Contributions: independently expected bases and rates', [
    'tfp' => amount3($payroll * 2 / 100),
    'foprolos' => amount3($payroll * 1 / 100),
    'tcl' => amount3(49285.315 * 0.2 / 100),
], ['tfp' => 366.957, 'foprolos' => 183.478, 'tcl' => 98.571]);

$results[] = assertAmounts('Fiscal result: additions and deductions', [
    'taxable_result' => amount3(48725.640 + 2310.375 + 846.220 - 425.125 - 610.445),
], ['taxable_result' => 50846.665]);

$results[] = assertAmounts('Employer declaration: beneficiary reconciliation', [
    'gross' => amount3(18500.125 + 7250.875 + 2380.000),
    'withheld' => amount3(1285.330 + 418.420 + 35.700),
], ['gross' => 28131.000, 'withheld' => 1739.450]);

$failed = array_values(array_filter($results, static fn(array $row): bool => !$row['passed']));
foreach ($results as $row) {
    echo ($row['passed'] ? 'PASS ' : 'FAIL ') . $row['case'];
    if (!$row['passed']) {
        echo ' ' . json_encode($row['differences'], JSON_UNESCAPED_SLASHES);
    }
    echo PHP_EOL;
}

echo count($results) . ' cases, ' . count($failed) . ' failures, tolerance 0.0005 TND' . PHP_EOL;
exit($failed === [] ? 0 : 1);
