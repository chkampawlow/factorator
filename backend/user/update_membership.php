<?php

declare(strict_types=1);

header('Content-Type: application/json');

require_once __DIR__ . '/../config/db.php';
require_once __DIR__ . '/../config/response.php';
require_once __DIR__ . '/../config/validator.php';
require_once __DIR__ . '/../auth/auth_required.php';
require_once __DIR__ . '/../auth/role_helper.php';
require_once __DIR__ . '/membership_service.php';

try {
    if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'POST') {
        jsonResponse(['success' => false, 'message' => 'Method not allowed. Use POST.'], 405);
    }

    $auth = requireAuth();
    $conn = db();
    $companyId = authTenantId($auth);
    $actorId = authActorId($auth);
    requireAdministratorRole($conn, $companyId);
    $data = requireJsonBody();

    $membershipId = (int)($data['membership_id'] ?? 0);
    $targetUserId = (int)($data['user_id'] ?? 0);
    $action = strtoupper(trim((string)($data['action'] ?? '')));
    $statusByAction = [
        'SUSPEND' => 'SUSPENDED',
        'REACTIVATE' => 'ACTIVE',
        'REMOVE' => 'REVOKED',
        'REVOKE' => 'REVOKED',
    ];
    if (!isset($statusByAction[$action])) {
        jsonResponse([
            'success' => false,
            'message' => 'Action must be SUSPEND, REACTIVATE, or REMOVE.',
            'code' => 'MEMBERSHIP_ACTION_INVALID',
        ], 422);
    }

    $conn->begin_transaction();
    $result = updateCompanyMembershipStatus(
        $conn,
        $companyId,
        $actorId,
        $membershipId,
        $targetUserId,
        $statusByAction[$action]
    );
    $conn->commit();

    jsonResponse([
        'success' => true,
        'message' => 'Membership updated.',
        'membership_id' => $result['membership_id'],
        'user_id' => $result['user_id'],
        'status' => $result['status'],
        'changed' => $result['changed'],
    ]);
} catch (CompanyMembershipException $e) {
    if (isset($conn)) {
        try { $conn->rollback(); } catch (Throwable $ignored) {}
    }
    jsonResponse([
        'success' => false,
        'message' => $e->getMessage(),
        'code' => $e->errorCode,
    ], $e->httpStatus);
} catch (Throwable $e) {
    if (isset($conn)) {
        try { $conn->rollback(); } catch (Throwable $ignored) {}
    }
    structuredLog('ERROR', 'MEMBERSHIP.STATUS_UPDATE_ERROR', [
        'exception' => get_class($e),
        'message' => $e->getMessage(),
    ]);
    jsonResponse([
        'success' => false,
        'message' => 'Unable to update the membership right now.',
        'code' => 'MEMBERSHIP_UPDATE_FAILED',
    ], 500);
}
