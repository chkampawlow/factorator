<?php

declare(strict_types=1);

header('Content-Type: application/json');

require_once __DIR__ . '/../config/db.php';
require_once __DIR__ . '/../config/response.php';
require_once __DIR__ . '/../config/validator.php';
require_once __DIR__ . '/../config/rate_limit.php';
require_once __DIR__ . '/../user/invitation_service.php';

try {
    if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'POST') {
        jsonResponse(['success' => false, 'message' => 'Method not allowed. Use POST.'], 405);
    }

    $data = requireJsonBody();
    $token = trim((string)($data['token'] ?? ''));
    $password = (string)($data['password'] ?? '');
    $confirmPassword = (string)($data['confirm_password'] ?? '');
    $displayName = trim((string)($data['display_name'] ?? $data['name'] ?? ''));
    $phone = trim((string)($data['phone'] ?? ''));

    // Bound public request/storage volume even when an attacker rotates a new
    // random token on every request, then apply the tighter per-token limit.
    enforceRateLimit('accept_invitation_ip', 'public', 30, 15 * 60);
    // The raw secret is never stored by the limiter or written to logs.
    enforceRateLimit('accept_invitation', hash('sha256', $token), 10, 15 * 60);

    $conn = db();
    $conn->begin_transaction();
    $result = acceptCompanyInvitation(
        $conn,
        $token,
        $password,
        $confirmPassword,
        $displayName,
        $phone
    );
    $conn->commit();
    clearRateLimit('accept_invitation', hash('sha256', $token));

    jsonResponse([
        'success' => true,
        'message' => 'Invitation accepted. You can now sign in.',
        'user_id' => $result['user_id'],
        'membership' => [
            'id' => $result['membership_id'],
            'role' => $result['role'],
            'status' => $result['status'],
            'is_owner' => false,
        ],
        'rehired' => (bool)($result['rehired'] ?? false),
        'email_verified' => (bool)($result['email_verified'] ?? false),
    ], 201);
} catch (CompanyInvitationException | InvalidArgumentException $e) {
    if (isset($conn)) {
        try { $conn->rollback(); } catch (Throwable $ignored) {}
    }
    $status = $e instanceof CompanyInvitationException ? $e->httpStatus : 422;
    $code = $e instanceof CompanyInvitationException ? $e->errorCode : 'PASSWORD_POLICY_FAILED';
    jsonResponse([
        'success' => false,
        'message' => $e->getMessage(),
        'code' => $code,
    ], $status);
} catch (Throwable $e) {
    if (isset($conn)) {
        try { $conn->rollback(); } catch (Throwable $ignored) {}
    }
    structuredLog('ERROR', 'MEMBERSHIP.INVITATION_ACCEPT_ERROR', [
        'exception' => get_class($e),
        'message' => $e->getMessage(),
    ]);
    jsonResponse([
        'success' => false,
        'message' => 'Unable to accept the invitation right now.',
        'code' => 'INVITATION_ACCEPT_FAILED',
    ], 500);
}
