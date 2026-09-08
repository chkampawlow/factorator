<?php

header('Content-Type: application/json');

require_once __DIR__ . '/../config/db.php';
require_once __DIR__ . '/../config/response.php';
require_once __DIR__ . '/../config/audit.php';
require_once __DIR__ . '/../auth/auth_required.php';
require_once __DIR__ . '/../auth/role_helper.php';
require_once __DIR__ . '/../auth/refresh_token_service.php';
require_once __DIR__ . '/membership_service.php';

try {
    if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
        jsonResponse(['success' => false, 'message' => 'Method not allowed. Use POST.'], 405);
    }

    $auth = requireAuth();
    $conn = db();
    $companyId = authTenantId($auth);
    $actorId = authActorId($auth);
    requireAdministratorRole($conn, $companyId);
    $data = json_decode(file_get_contents('php://input'), true);
    if (!is_array($data)) {
        jsonResponse(['success' => false, 'message' => 'Invalid JSON body.'], 400);
    }

    $membershipId = (int)($data['membership_id'] ?? 0);
    $targetUserId = (int)($data['user_id'] ?? 0);
    $role = strtoupper(trim((string)($data['role'] ?? '')));
    $conn->begin_transaction();
    $result = updateCompanyMembershipRole(
        $conn,
        $companyId,
        $actorId,
        $membershipId,
        $targetUserId,
        $role
    );
    $conn->commit();

    jsonResponse([
        'success' => true,
        'message' => 'Member role updated successfully.',
        'membership_id' => $result['membership_id'],
        'user_id' => $result['user_id'],
        'role' => $result['role'],
        'changed' => $result['changed'],
    ]);
} catch (Throwable $e) {
    if (isset($conn)) {
        try { $conn->rollback(); } catch (Throwable $ignored) {}
    }
    if ($e instanceof CompanyMembershipException) {
        jsonResponse([
            'success' => false,
            'message' => $e->getMessage(),
            'code' => $e->errorCode,
        ], $e->httpStatus);
    }
    structuredLog('ERROR', 'MEMBERSHIP.ROLE_UPDATE_ERROR', [
        'exception' => get_class($e),
        'message' => $e->getMessage(),
    ]);
    jsonResponse([
        'success' => false,
        'message' => 'Unable to update the member role right now.',
        'code' => 'MEMBERSHIP_ROLE_UPDATE_FAILED',
    ], 500);
}
