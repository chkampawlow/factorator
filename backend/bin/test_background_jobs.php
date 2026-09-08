<?php

declare(strict_types=1);

if (PHP_SAPI !== 'cli') { http_response_code(404); exit; }
require_once __DIR__ . '/../config/db.php';
require_once __DIR__ . '/../config/upload.php';
require_once __DIR__ . '/../jobs/job_service.php';

$conn = db();
$database = (string)$conn->query('SELECT DATABASE()')->fetch_row()[0];
if (!preg_match('/(?:^|_)(?:test|testing|local)(?:_|$)/i', $database)) {
    fwrite(STDERR, "REFUSED on $database" . PHP_EOL);
    exit(2);
}

$marker = bin2hex(random_bytes(8));
$userId = random_int(800000000, 900000000);
$failures = [];
$generatedFiles = [];
function jobCheck(bool $passed, string $label, array &$failures): void
{
    echo ($passed ? 'PASS ' : 'FAIL ') . $label . PHP_EOL;
    if (!$passed) $failures[] = $label;
}

try {
    $job = queueBackgroundJob($conn, $userId, $userId, 'SYSTEM_TEST', ['echo'=>$marker], "test:$marker", 2);
    $replay = queueBackgroundJob($conn, $userId, $userId, 'SYSTEM_TEST', ['echo'=>$marker], "test:$marker", 2);
    jobCheck((int)$job['id'] === (int)$replay['id'], 'identical enqueue request is idempotent', $failures);
    try {
        queueBackgroundJob($conn, $userId, $userId, 'SYSTEM_TEST', ['echo'=>'changed'], "test:$marker", 2);
        $conflictRejected = false;
    } catch (RuntimeException) {
        $conflictRejected = true;
    }
    jobCheck($conflictRejected, 'changed payload cannot reuse an idempotency key', $failures);
    jobCheck(backgroundJobForTenant($conn, $userId + 1, (int)$job['id']) === null, 'job status is isolated by tenant', $failures);

    $pipes = [];
    $process = proc_open([PHP_BINARY, __DIR__ . '/run_job_worker.php', '--once'], [1=>['pipe','w'],2=>['pipe','w']], $pipes);
    if (!is_resource($process)) throw new RuntimeException('Could not start background worker.');
    $stdout = stream_get_contents($pipes[1]);
    $stderr = stream_get_contents($pipes[2]);
    fclose($pipes[1]); fclose($pipes[2]);
    $exitCode = proc_close($process);
    $completed = backgroundJobForTenant($conn, $userId, (int)$job['id']);
    jobCheck($exitCode === 0 && ($completed['status'] ?? '') === 'COMPLETED', 'worker completes a queued job', $failures);
    jobCheck(str_contains($stdout, 'Processed 1') && $stderr === '', 'worker exits cleanly in one-job mode', $failures);

    $reportJob = queueBackgroundJob($conn, $userId, $userId, 'REPORT_EXPORT', [
        'format'=>'CSV','from'=>'2026-08-01','report'=>'expenses','to'=>'2026-08-11',
    ], "report:$marker", 2);
    $pipes = [];
    $process = proc_open([PHP_BINARY, __DIR__ . '/run_job_worker.php', '--once'], [1=>['pipe','w'],2=>['pipe','w']], $pipes);
    if (!is_resource($process)) throw new RuntimeException('Could not start report export worker.');
    $reportStdout = stream_get_contents($pipes[1]);
    $reportStderr = stream_get_contents($pipes[2]);
    fclose($pipes[1]); fclose($pipes[2]);
    $reportExitCode = proc_close($process);
    $reportState = backgroundJobForTenant($conn, $userId, (int)$reportJob['id']);
    $raw = $conn->prepare('SELECT result_json FROM erp_background_jobs WHERE id=? AND user_id=?');
    $reportId = (int)$reportJob['id'];
    $raw->bind_param('ii', $reportId, $userId);$raw->execute();
    $resultMetadata = json_decode((string)($raw->get_result()->fetch_assoc()['result_json'] ?? ''), true) ?: [];$raw->close();
    $relativePath = (string)($resultMetadata['storage_path'] ?? '');
    $absolutePath = privateStorageRoot() . DIRECTORY_SEPARATOR . str_replace('/', DIRECTORY_SEPARATOR, $relativePath);
    if ($relativePath !== '') $generatedFiles[] = $absolutePath;
    jobCheck($reportExitCode === 0 && str_contains($reportStdout, 'Processed 1') && $reportStderr === '', 'worker generates report exports outside the request', $failures);
    jobCheck(($reportState['status'] ?? '') === 'COMPLETED' && ($reportState['download_ready'] ?? false) === true, 'completed report exposes safe download metadata', $failures);
    jobCheck(!array_key_exists('storage_path', $reportState ?? []) && preg_match('#^jobs/' . $userId . '/exports/[a-f0-9]{48}\.csv$#', $relativePath) === 1, 'job status does not expose the private export path', $failures);
    jobCheck(is_file($absolutePath) && str_starts_with((string)file_get_contents($absolutePath), "\xEF\xBB\xBFno_records"), 'empty report produces a valid UTF-8 CSV empty state', $failures);

    $reconciliationJob = queueBackgroundJob($conn, $userId, $userId, 'REPORT_RECONCILIATION', [
        'from'=>'2026-08-01','to'=>'2026-08-11',
    ], "reconcile:$marker", 2);
    $pipes = [];
    $process = proc_open([PHP_BINARY, __DIR__ . '/run_job_worker.php', '--once'], [1=>['pipe','w'],2=>['pipe','w']], $pipes);
    if (!is_resource($process)) throw new RuntimeException('Could not start reconciliation worker.');
    $reconciliationStdout = stream_get_contents($pipes[1]);
    $reconciliationStderr = stream_get_contents($pipes[2]);
    fclose($pipes[1]); fclose($pipes[2]);
    $reconciliationExitCode = proc_close($process);
    $reconciliationState = backgroundJobForTenant($conn, $userId, (int)$reconciliationJob['id']);
    $reconciliation = $reconciliationState['reconciliation'] ?? null;
    jobCheck($reconciliationExitCode === 0 && str_contains($reconciliationStdout, 'Processed 1') && $reconciliationStderr === '', 'worker runs detailed reconciliation outside the request', $failures);
    jobCheck(($reconciliationState['status'] ?? '') === 'COMPLETED' && is_array($reconciliation), 'completed reconciliation exposes a safe tenant result', $failures);
    jobCheck(($reconciliation['matches'] ?? false) === true && (int)($reconciliation['issue_count'] ?? -1) === 0 && count($reconciliation['checks'] ?? []) === 14, 'detailed reconciliation executes every scoped integrity check', $failures);
    jobCheck(backgroundJobForTenant($conn, $userId + 1, (int)$reconciliationJob['id']) === null, 'reconciliation result is isolated by tenant', $failures);

    $retryJob = queueBackgroundJob($conn, $userId, $userId, 'SYSTEM_TEST', ['echo'=>'retry'], "retry:$marker", 2);
    $claimed = claimBackgroundJob($conn, 'integration-test-worker');
    if (!$claimed || (int)$claimed['id'] !== (int)$retryJob['id']) throw new RuntimeException('Could not claim retry fixture.');
    failBackgroundJob($conn, $claimed, new RuntimeException('Expected retry fixture failure.'));
    $retryState = backgroundJobForTenant($conn, $userId, (int)$retryJob['id']);
    jobCheck(($retryState['status'] ?? '') === 'QUEUED' && (int)$retryState['attempts'] === 1, 'failed job is scheduled for bounded retry', $failures);
} finally {
    foreach ($generatedFiles as $generatedFile) if (is_file($generatedFile)) @unlink($generatedFile);
    $stmt = $conn->prepare('DELETE FROM erp_background_jobs WHERE user_id=?');
    $stmt->bind_param('i', $userId);
    $stmt->execute();
    $stmt->close();
}

if ($failures !== []) exit(1);
echo 'Background job suite passed.' . PHP_EOL;
