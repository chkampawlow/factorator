<?php

declare(strict_types=1);

require_once __DIR__ . '/../dashboard/revenue_series.php';

$series = dashboardMonthlyRevenueSeries([
    ['month' => '2026-02', 'revenue' => '100.1254'],
    ['month' => '2026-04', 'revenue' => -20],
    ['month' => 'invalid', 'revenue' => 999],
], '2026-04-01', 4);

$expected = [
    ['month' => '2026-01', 'revenue' => 0.0],
    ['month' => '2026-02', 'revenue' => 100.125],
    ['month' => '2026-03', 'revenue' => 0.0],
    ['month' => '2026-04', 'revenue' => -20.0],
];

if ($series !== $expected) {
    fwrite(STDERR, 'FAIL dashboard revenue series: ' . json_encode($series) . PHP_EOL);
    exit(1);
}

$source = file_get_contents(__DIR__ . '/../dashboard/overview.php') ?: '';
foreach (['monthly_series', 'dashboardMonthlyRevenueSeries', "invoice_type = 'AVOIR'"] as $guard) {
    if (!str_contains($source, $guard)) {
        fwrite(STDERR, 'FAIL dashboard revenue endpoint missing guard: ' . $guard . PHP_EOL);
        exit(1);
    }
}

echo 'PASS dashboard continuous monthly net revenue series' . PHP_EOL;
