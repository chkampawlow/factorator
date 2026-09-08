<?php

if (PHP_SAPI !== 'cli') {
    http_response_code(404);
    exit;
}

require_once __DIR__ . '/../taxes/tax_profile_service.php';

$cases = [
    ['1.2344', '1.234'],
    ['1.2345', '1.235'],
    ['-1.2344', '-1.234'],
    ['-1.2345', '-1.235'],
    ['0.0005', '0.001'],
    ['-0.0005', '-0.001'],
];

$failures = [];
foreach ($cases as [$input, $expected]) {
    $actual = money3($input);
    if ($actual !== $expected) {
        $failures[] = compact('input', 'expected', 'actual');
    }
}

echo json_encode([
    'success' => $failures === [],
    'policy' => 'TND millime, round-half-up to 3 decimals',
    'cases' => count($cases),
    'failures' => $failures,
], JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES) . PHP_EOL;

exit($failures === [] ? 0 : 1);
