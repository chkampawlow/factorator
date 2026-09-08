<?php

declare(strict_types=1);

if (PHP_SAPI !== 'cli') { http_response_code(404); exit; }

require_once __DIR__ . '/../config/db.php';
require_once __DIR__ . '/../config/upload.php';
require_once __DIR__ . '/../config/logger.php';
require_once __DIR__ . '/../jobs/job_service.php';
require_once __DIR__ . '/../mailer/mailer.php';
require_once __DIR__ . '/../reports/export.php';
require_once __DIR__ . '/../reports/reconciliation_service.php';

$conn = db();
$once = in_array('--once', $argv, true);
$drain = in_array('--drain', $argv, true);
$maxJobs = 0;
$idleTimeout = 0;
foreach ($argv as $argument) if (str_starts_with($argument, '--max=')) $maxJobs = max(0, (int)substr($argument, 6));
foreach ($argv as $argument) if (str_starts_with($argument, '--idle-timeout=')) $idleTimeout = min(300, max(0, (int)substr($argument, 15)));
$workerId = gethostname() . ':' . getmypid() . ':' . bin2hex(random_bytes(4));
$processed = 0;
$idleStartedAt = null;
recoverStaleBackgroundJobs($conn);

function jobPrivatePath(string $relativePath): string
{
    $relativePath = trim(str_replace('\\', '/', $relativePath), '/');
    if (!preg_match('#^jobs/[0-9]+/[a-f0-9]{48}\.pdf$#', $relativePath)) {
        throw new InvalidArgumentException('Invalid job attachment path.');
    }
    return privateStorageRoot() . DIRECTORY_SEPARATOR . str_replace('/', DIRECTORY_SEPARATOR, $relativePath);
}

function executeBackgroundJob(mysqli $conn, array $job): array
{
    $payload = is_array($job['payload'] ?? null) ? $job['payload'] : [];
    switch ((string)$job['job_type']) {
        case 'EMAIL_DOCUMENT':
            $to = trim((string)($payload['email'] ?? ''));
            $filename = basename(trim((string)($payload['filename'] ?? 'document.pdf')));
            $language = (string)($payload['language'] ?? 'en');
            $documentType = (string)($payload['document_type'] ?? 'invoice');
            if (!filter_var($to, FILTER_VALIDATE_EMAIL)) throw new InvalidArgumentException('Invalid recipient email.');
            $path = jobPrivatePath((string)($payload['attachment_path'] ?? ''));
            if (!is_file($path) || filesize($path) === false || filesize($path) > 10485760) {
                throw new InvalidArgumentException('Queued PDF attachment is missing or invalid.');
            }
            $pdf = file_get_contents($path);
            if ($pdf === false || !str_starts_with($pdf, '%PDF-')) throw new InvalidArgumentException('Queued attachment is not a PDF.');
            if (!hash_equals((string)($payload['content_sha256'] ?? ''), hash('sha256', $pdf))) throw new InvalidArgumentException('Queued PDF integrity check failed.');
            sendInvoicePdf($to, $pdf, $filename, $language, $documentType);
            @unlink($path);
            return ['delivered' => true, 'filename' => $filename];

        case 'REPORT_EXPORT':
            $userId = (int)$job['user_id'];
            $report = strtolower(trim((string)($payload['report'] ?? '')));
            $from = trim((string)($payload['from'] ?? ''));
            $to = trim((string)($payload['to'] ?? ''));
            if ((string)($payload['format'] ?? '') !== 'CSV' || !reportExportSupported($report)) {
                throw new InvalidArgumentException('Invalid report export payload.');
            }
            $storedName = substr(hash('sha256', 'report-export|' . $job['id'] . '|' . $job['request_hash']), 0, 48) . '.csv';
            $relativePath = 'jobs/' . $userId . '/exports/' . $storedName;
            $directory = ensurePrivateDirectory('jobs/' . $userId . '/exports');
            $absolutePath = $directory . DIRECTORY_SEPARATOR . $storedName;
            try {
                $metadata = generateReportCsv(
                    $conn,
                    $userId,
                    $report,
                    $from,
                    $to,
                    $absolutePath,
                    static fn(int $progress) => updateBackgroundJobProgress($conn, (int)$job['id'], $progress)
                );
                @chmod($absolutePath, 0600);
                return $metadata + ['storage_path'=>$relativePath,'format'=>'CSV'];
            } catch (Throwable $error) {
                if (is_file($absolutePath)) @unlink($absolutePath);
                throw $error;
            }

        case 'REPORT_RECONCILIATION':
            $userId = (int)$job['user_id'];
            $from = trim((string)($payload['from'] ?? ''));
            $to = trim((string)($payload['to'] ?? ''));
            return runTenantReportReconciliation(
                $conn,
                $userId,
                $from,
                $to,
                static fn(int $progress) => updateBackgroundJobProgress($conn, (int)$job['id'], $progress)
            );

        case 'SYSTEM_TEST':
            $database = (string)$conn->query('SELECT DATABASE()')->fetch_row()[0];
            $environment = strtolower((string)($_ENV['APP_ENV'] ?? 'development'));
            if ($environment !== 'testing' && !preg_match('/(?:^|_)(?:test|testing|local)(?:_|$)/i', $database)) {
                throw new RuntimeException('System test jobs are disabled outside test databases.');
            }
            return ['echo' => $payload['echo'] ?? null];
    }
    throw new InvalidArgumentException('Unsupported background job type.');
}

do {
    $job = claimBackgroundJob($conn, $workerId);
    if (!$job) {
        if ($once || $drain || $maxJobs > 0) break;
        if ($idleTimeout > 0) {
            $idleStartedAt ??= microtime(true);
            if ((microtime(true) - $idleStartedAt) >= $idleTimeout) break;
        }
        usleep(500000);
        continue;
    }
    $idleStartedAt = null;
    try {
        appSetLogContext((int)$job['user_id'], (int)$job['created_by']);
        $result = executeBackgroundJob($conn, $job);
        completeBackgroundJob($conn, (int)$job['id'], $result);
        structuredLog('INFO', 'BACKGROUND_JOB.COMPLETED', ['job_id'=>(int)$job['id'],'job_type'=>$job['job_type']]);
    } catch (Throwable $error) {
        failBackgroundJob($conn, $job, $error);
        structuredLog('ERROR', 'BACKGROUND_JOB.FAILED', ['job_id'=>(int)$job['id'],'job_type'=>$job['job_type'],'message'=>$error->getMessage()]);
    }
    $processed++;
    if ($once || ($maxJobs > 0 && $processed >= $maxJobs)) break;
} while (true);

echo "Processed $processed background job(s)." . PHP_EOL;
