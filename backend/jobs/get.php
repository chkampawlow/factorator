<?php

declare(strict_types=1);

header('Content-Type: application/json');

require_once __DIR__ . '/../config/response.php';
require_once __DIR__ . '/../config/db.php';
require_once __DIR__ . '/../auth/auth_required.php';
require_once __DIR__ . '/../auth/role_helper.php';
require_once __DIR__ . '/job_service.php';

try {
    $auth = requireAuth();
    $companyId = authTenantId($auth);
    $actorId = authActorId($auth);
    $conn = db();
    requirePermission($conn, $companyId, 'dashboard.view');

    $jobId = (int)($_GET['id'] ?? 0);
    if ($jobId <= 0) {
        jsonResponse(['success' => false, 'message' => 'Invalid job id.'], 422);
    }
    $job = backgroundJobForTenant($conn, $companyId, $jobId);
    $canViewCompanyJobs = userHasPermission($conn, $companyId, 'users.manage');
    if (!$job || (!$canViewCompanyJobs && (int)($job['created_by'] ?? 0) !== $actorId)) {
        jsonResponse(['success' => false, 'message' => 'Background job not found.'], 404);
    }
    unset($job['created_by']);
    jsonResponse(['success' => true, 'job' => $job]);
} catch (Throwable $error) {
    jsonResponse([
        'success' => false,
        'message' => 'Could not load background job.',
        'error_code' => 'JOB_GET_FAILED',
    ], 500);
}
