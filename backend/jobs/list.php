<?php

declare(strict_types=1);

header('Content-Type: application/json');

require_once __DIR__ . '/../config/response.php';
require_once __DIR__ . '/../config/db.php';
require_once __DIR__ . '/../config/pagination.php';
require_once __DIR__ . '/../auth/auth_required.php';
require_once __DIR__ . '/../auth/role_helper.php';

try {
    $auth = requireAuth();
    $companyId = authTenantId($auth);
    $actorId = authActorId($auth);
    [$page, $size, $offset] = paginationInput($_GET);
    $conn = db();
    requirePermission($conn, $companyId, 'dashboard.view');
    $canViewCompanyJobs = userHasPermission($conn, $companyId, 'users.manage');
    $where = $canViewCompanyJobs ? 'user_id = ?' : 'user_id = ? AND created_by = ?';

    $count = $conn->prepare("SELECT COUNT(*) AS total FROM erp_background_jobs WHERE {$where}");
    if ($canViewCompanyJobs) {
        $count->bind_param('i', $companyId);
    } else {
        $count->bind_param('ii', $companyId, $actorId);
    }
    $count->execute();
    $total = (int)$count->get_result()->fetch_assoc()['total'];
    $count->close();

    $stmt = $conn->prepare("\n        SELECT id, job_type, status, attempts, max_attempts, progress, available_at,\n               started_at, completed_at, error_code, error_message, created_at, updated_at\n        FROM erp_background_jobs\n        WHERE {$where}\n        ORDER BY id DESC\n        LIMIT ? OFFSET ?\n    ");
    if ($canViewCompanyJobs) {
        $stmt->bind_param('iii', $companyId, $size, $offset);
    } else {
        $stmt->bind_param('iiii', $companyId, $actorId, $size, $offset);
    }
    $stmt->execute();
    $rows = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);
    $stmt->close();
    paginatedResponse($rows, $page, $size, $total);
} catch (Throwable $error) {
    jsonResponse([
        'success' => false,
        'message' => 'Could not load background jobs.',
        'error_code' => 'JOB_LIST_FAILED',
    ], 500);
}
