<?php

declare(strict_types=1);

header('Content-Type: application/json');

require_once __DIR__ . '/../config/db.php';
require_once __DIR__ . '/../config/response.php';
require_once __DIR__ . '/../config/validator.php';
require_once __DIR__ . '/../auth/auth_required.php';
require_once __DIR__ . '/../auth/role_helper.php';
require_once __DIR__ . '/invitation_service.php';

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
    $invitationId = (int)($data['invitation_id'] ?? 0);

    $conn->begin_transaction();
    $result = revokeCompanyInvitation($conn, $companyId, $actorId, $invitationId);
    $conn->commit();

    jsonResponse([
        'success' => true,
        'message' => $result['changed']
            ? 'Invitation revoked.'
            : 'Invitation was already unavailable.',
        'invitation_id' => $result['invitation_id'],
        'status' => $result['status'],
        'changed' => $result['changed'],
    ]);
} catch (CompanyInvitationException $e) {
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
    structuredLog('ERROR', 'MEMBERSHIP.INVITATION_REVOKE_ERROR', [
        'exception' => get_class($e),
        'message' => $e->getMessage(),
    ]);
    jsonResponse([
        'success' => false,
        'message' => 'Unable to revoke the invitation right now.',
        'code' => 'INVITATION_REVOKE_FAILED',
    ], 500);
}
