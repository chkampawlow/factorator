<?php

declare(strict_types=1);

header('Content-Type: application/json');
require_once __DIR__ . '/../config/response.php';
require_once __DIR__ . '/../config/db.php';
require_once __DIR__ . '/../config/audit.php';
require_once __DIR__ . '/../auth/auth_required.php';
require_once __DIR__ . '/../auth/role_helper.php';
require_once __DIR__ . '/../jobs/job_service.php';
require_once __DIR__ . '/reconciliation_service.php';
require_once __DIR__ . '/report_error.php';

try {
    if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'POST') jsonResponse(['success'=>false,'message'=>'Method not allowed. Use POST.'], 405);
    $auth = requireAuth();
    $userId = authTenantId($auth);
    $actorId = authActorId($auth);
    $conn = db();
    requirePermission($conn, $userId, 'reports.view');
    $data = json_decode(file_get_contents('php://input'), true);
    if (!is_array($data)) throw new InvalidArgumentException('Invalid JSON body.');
    $from = trim((string)($data['from'] ?? ''));
    $to = trim((string)($data['to'] ?? ''));
    validateReconciliationPeriod($from, $to);
    $idempotencyKey = trim((string)($data['idempotency_key'] ?? ''));
    if (!preg_match('/^[A-Za-z0-9._:-]{8,128}$/', $idempotencyKey)) throw new InvalidArgumentException('A valid idempotency key is required.');

    $job = queueBackgroundJob($conn, $userId, $actorId, 'REPORT_RECONCILIATION', ['from'=>$from,'to'=>$to], $idempotencyKey, 2);
    auditLog($conn, $userId, $actorId, 'REPORT.RECONCILIATION_QUEUED', 'BACKGROUND_JOB', (int)$job['id'], null, ['date_from'=>$from,'date_to'=>$to]);
    jsonResponse(['success'=>true,'job_id'=>(int)$job['id'],'message'=>'Detailed reconciliation queued.','status'=>(string)$job['status']], 202);
} catch (BackgroundJobIdempotencyConflict $e) {
    jsonResponse([
        'success' => false,
        'message' => 'The idempotency key was already used for a different job request.',
        'error_code' => 'RECONCILIATION_QUEUE_CONFLICT',
    ], 409);
} catch (Throwable $e) {
    reportFailureResponse($e, 'Could not queue the reconciliation.', 'RECONCILIATION_QUEUE_FAILED');
}
