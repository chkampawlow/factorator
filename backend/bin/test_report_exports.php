<?php

declare(strict_types=1);

if (PHP_SAPI !== 'cli') { http_response_code(404); exit; }
require_once __DIR__ . '/../config/db.php';
require_once __DIR__ . '/../reports/export.php';

$conn = db();
$database = (string)$conn->query('SELECT DATABASE()')->fetch_row()[0];
if (!preg_match('/(?:^|_)(?:test|testing|local)(?:_|$)/i', $database)) {
    fwrite(STDERR, "REFUSED on $database" . PHP_EOL);
    exit(2);
}

$userId = random_int(800000000, 900000000);
$failed = [];
foreach (reportExportTypes() as $report) {
    $path = tempnam(sys_get_temp_dir(), 'report-test-');
    if ($path === false) throw new RuntimeException('Could not allocate a report test file.');
    try {
        $metadata = generateReportCsv($conn, $userId, $report, '2026-01-01', '2026-08-11', $path);
        $valid = $metadata['row_count'] === 0
            && $metadata['filename'] === $report . '-2026-01-01-2026-08-11.csv'
            && $metadata['size'] === filesize($path)
            && hash_equals($metadata['sha256'], hash_file('sha256', $path))
            && str_starts_with((string)file_get_contents($path), "\xEF\xBB\xBFno_records");
        echo ($valid ? 'PASS ' : 'FAIL ') . $report . PHP_EOL;
        if (!$valid) $failed[] = $report;
    } catch (Throwable $error) {
        $failed[] = $report;
        fwrite(STDERR, 'FAIL ' . $report . ': ' . $error->getMessage() . PHP_EOL);
    } finally {
        @unlink($path);
    }
}

if ($failed !== []) exit(1);
echo 'All report export definitions generated valid CSV files.' . PHP_EOL;
