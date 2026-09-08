<?php

declare(strict_types=1);

header('Content-Type: application/json');

require_once __DIR__ . '/../config/response.php';
require_once __DIR__ . '/../config/db.php';
require_once __DIR__ . '/../config/audit.php';
require_once __DIR__ . '/../auth/auth_required.php';
require_once __DIR__ . '/../auth/role_helper.php';
require_once __DIR__ . '/../jobs/job_service.php';
require_once __DIR__ . '/export.php';
require_once __DIR__ . '/report_error.php';

try {
    if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'POST') {
        jsonResponse(['success'=>false,'message'=>'Method not allowed. Use POST.'], 405);
    }
    $auth = requireAuth();
    $userId = authTenantId($auth);
    $actorId = authActorId($auth);
    $conn = db();
    requirePermission($conn, $userId, 'reports.view');
    $data = json_decode(file_get_contents('php://input'), true);
    if (!is_array($data)) throw new InvalidArgumentException('Invalid JSON body.');

    $report = strtolower(trim((string)($data['report'] ?? '')));
    $from = trim((string)($data['from'] ?? ''));
    $to = trim((string)($data['to'] ?? ''));
    if (!reportExportSupported($report)) throw new InvalidArgumentException('Unsupported export.');
    if (!preg_match('/^\d{4}-\d{2}-\d{2}$/', $from) || !preg_match('/^\d{4}-\d{2}-\d{2}$/', $to) || $to < $from) {
        throw new InvalidArgumentException('Invalid report period.');
    }
    $idempotencyKey = trim((string)($data['idempotency_key'] ?? ''));
    if (!preg_match('/^[A-Za-z0-9._:-]{8,128}$/', $idempotencyKey)) {
        throw new InvalidArgumentException('A valid idempotency key is required.');
    }

    $job = queueBackgroundJob($conn, $userId, $actorId, 'REPORT_EXPORT', [
        'format' => 'CSV',
        'from' => $from,
        'report' => $report,
        'to' => $to,
    ], $idempotencyKey, 2);
    auditLog($conn, $userId, $actorId, 'REPORT.EXPORT_QUEUED', 'BACKGROUND_JOB', (int)$job['id'], null, [
        'date_from' => $from,
        'date_to' => $to,
        'format' => 'CSV',
        'report' => $report,
    ]);
    jsonResponse([
        'success' => true,
        'job_id' => (int)$job['id'],
        'message' => 'Report export queued.',
        'status' => (string)$job['status'],
    ], 202);
} catch (BackgroundJobIdempotencyConflict $e) {
    jsonResponse([
        'success' => false,
        'message' => 'The idempotency key was already used for a different job request.',
        'error_code' => 'EXPORT_QUEUE_CONFLICT',
    ], 409);
} catch (Throwable $e) {
    reportFailureResponse($e, 'Could not queue the report export.', 'EXPORT_QUEUE_FAILED');
}
