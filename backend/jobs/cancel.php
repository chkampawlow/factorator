<?php

declare(strict_types=1);

header('Content-Type: application/json');

require_once __DIR__ . '/../config/response.php';
require_once __DIR__ . '/../config/db.php';
require_once __DIR__ . '/../config/upload.php';
require_once __DIR__ . '/../auth/auth_required.php';
require_once __DIR__ . '/../auth/role_helper.php';

try {
    if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'POST') {
        jsonResponse(['success' => false, 'message' => 'Method not allowed.'], 405);
    }
    $auth = requireAuth();
    $companyId = authTenantId($auth);
    $actorId = authActorId($auth);
    $data = json_decode(file_get_contents('php://input'), true) ?: [];
    $jobId = (int)($data['id'] ?? 0);
    $conn = db();
    requirePermission($conn, $companyId, 'dashboard.view');
    $canManageCompanyJobs = userHasPermission($conn, $companyId, 'users.manage');
    $actorClause = $canManageCompanyJobs ? '' : ' AND created_by = ?';

    $conn->begin_transaction();
    $select = $conn->prepare("\n        SELECT payload_json\n        FROM erp_background_jobs\n        WHERE id = ? AND user_id = ? AND status = 'QUEUED'{$actorClause}\n        FOR UPDATE\n    ");
    if ($canManageCompanyJobs) {
        $select->bind_param('ii', $jobId, $companyId);
    } else {
        $select->bind_param('iii', $jobId, $companyId, $actorId);
    }
    $select->execute();
    $row = $select->get_result()->fetch_assoc();
    $select->close();
    if (!$row) {
        $conn->rollback();
        jsonResponse(['success' => false, 'message' => 'Only a queued job you can access may be cancelled.'], 409);
    }

    $stmt = $conn->prepare("\n        UPDATE erp_background_jobs\n        SET status = 'CANCELLED', progress = 100, completed_at = NOW(), error_code = NULL, error_message = NULL\n        WHERE id = ? AND user_id = ? AND status = 'QUEUED'{$actorClause}\n    ");
    if ($canManageCompanyJobs) {
        $stmt->bind_param('ii', $jobId, $companyId);
    } else {
        $stmt->bind_param('iii', $jobId, $companyId, $actorId);
    }
    $stmt->execute();
    $cancelled = $stmt->affected_rows === 1;
    $stmt->close();
    $conn->commit();

    if ($cancelled) {
        $payload = json_decode((string)$row['payload_json'], true) ?: [];
        $relative = trim(str_replace('\\', '/', (string)($payload['attachment_path'] ?? '')), '/');
        if (preg_match('#^jobs/' . $companyId . '/[a-f0-9]{48}\.pdf$#', $relative)) {
            @unlink(privateStorageRoot() . DIRECTORY_SEPARATOR . str_replace('/', DIRECTORY_SEPARATOR, $relative));
        }
    }
    jsonResponse(['success' => true, 'id' => $jobId, 'status' => 'CANCELLED']);
} catch (Throwable $error) {
    if (isset($conn) && $conn instanceof mysqli) {
        try { $conn->rollback(); } catch (Throwable $ignored) {}
    }
    jsonResponse([
        'success' => false,
        'message' => 'Could not cancel background job.',
        'error_code' => 'JOB_CANCEL_FAILED',
    ], 500);
}
