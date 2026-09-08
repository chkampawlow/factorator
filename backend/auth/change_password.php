<?php

declare(strict_types=1);

ini_set('display_errors', '0');
ini_set('display_startup_errors', '0');
ini_set('log_errors', '1');
error_reporting(E_ALL);

header('Content-Type: application/json; charset=utf-8');

require_once __DIR__ . '/auth_required.php';
require_once __DIR__ . '/auth_cookie.php';
require_once __DIR__ . '/password_policy.php';
require_once __DIR__ . '/../config/audit.php';
require_once __DIR__ . '/../config/db.php';
require_once __DIR__ . '/../config/rate_limit.php';
require_once __DIR__ . '/../config/response.php';

try {
    if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'POST') {
        jsonResponse(['success' => false, 'message' => 'Method not allowed. Use POST.'], 405);
    }

    $contentLength = (int)($_SERVER['CONTENT_LENGTH'] ?? 0);
    if ($contentLength > 4096) {
        jsonResponse(['success' => false, 'message' => 'Request body is too large.'], 413);
    }

    $auth = requireAuth();
    $actorId = authActorId($auth);
    $companyId = authTenantId($auth);
    enforceRateLimit('change_password', (string)$actorId, 5, 15 * 60);

    try {
        $data = json_decode(file_get_contents('php://input'), true, 32, JSON_THROW_ON_ERROR);
    } catch (JsonException $error) {
        jsonResponse(['success' => false, 'message' => 'Invalid JSON body.'], 400);
    }
    if (!is_array($data)) {
        jsonResponse(['success' => false, 'message' => 'Invalid JSON body.'], 400);
    }

    $currentPassword = (string)($data['current_password'] ?? '');
    $newPassword = (string)($data['new_password'] ?? '');
    $confirmPassword = (string)($data['confirm_password'] ?? '');
    if ($currentPassword === '' || $newPassword === '' || $confirmPassword === '') {
        throw new InvalidArgumentException('All password fields are required.', 1001);
    }
    if (!hash_equals($newPassword, $confirmPassword)) {
        throw new InvalidArgumentException('The new password confirmation does not match.', 1002);
    }

    $conn = db();
    $conn->begin_transaction();

    $stmt = $conn->prepare('
        SELECT id, email, display_name, password_hash
        FROM users
        WHERE id = ?
        LIMIT 1
        FOR UPDATE
    ');
    $stmt->bind_param('i', $actorId);
    $stmt->execute();
    $user = $stmt->get_result()->fetch_assoc();
    $stmt->close();

    if (!$user || !password_verify($currentPassword, (string)$user['password_hash'])) {
        auditLog($conn, $companyId, $actorId, 'AUTH.PASSWORD_CHANGE_FAILED', 'USER', $actorId, null, [
            'reason' => 'current_password_mismatch',
        ], 'AUTH');
        $conn->commit();
        jsonResponse([
            'success' => false,
            'message' => 'Current password is incorrect.',
            'code' => 'CURRENT_PASSWORD_INCORRECT',
        ], 422);
    }

    if (password_verify($newPassword, (string)$user['password_hash'])) {
        throw new InvalidArgumentException('The new password must be different from the current password.', 1003);
    }

    assertStrongPassword($newPassword, [
        (string)($user['email'] ?? ''),
        (string)($user['display_name'] ?? ''),
    ]);

    $newHash = password_hash($newPassword, PASSWORD_DEFAULT);
    if ($newHash === false) {
        throw new RuntimeException('Unable to secure the new password.');
    }

    $stmt = $conn->prepare('UPDATE users SET password_hash = ? WHERE id = ?');
    $stmt->bind_param('si', $newHash, $actorId);
    $stmt->execute();
    $stmt->close();

    $stmt = $conn->prepare('
        UPDATE auth_refresh_tokens
        SET revoked_at = COALESCE(revoked_at, NOW())
        WHERE user_id = ?
    ');
    $stmt->bind_param('i', $actorId);
    $stmt->execute();
    $stmt->close();

    auditLog($conn, $companyId, $actorId, 'AUTH.PASSWORD_CHANGED', 'USER', $actorId, null, [
        'all_refresh_sessions_revoked' => true,
    ], 'AUTH');
    $conn->commit();

    clearRateLimit('change_password', (string)$actorId);
    clearAuthCookies();
    jsonResponse([
        'success' => true,
        'message' => 'Password changed. Please sign in again.',
        'reauthentication_required' => true,
    ]);
} catch (InvalidArgumentException $error) {
    if (isset($conn)) {
        try { $conn->rollback(); } catch (Throwable $ignored) {}
    }
    $codes = [
        1001 => 'PASSWORD_FIELDS_REQUIRED',
        1002 => 'PASSWORD_CONFIRMATION_MISMATCH',
        1003 => 'PASSWORD_MUST_CHANGE',
    ];
    jsonResponse([
        'success' => false,
        'message' => $error->getMessage(),
        'code' => $codes[$error->getCode()] ?? 'PASSWORD_POLICY_REJECTED',
    ], 422);
} catch (Throwable $error) {
    if (isset($conn)) {
        try { $conn->rollback(); } catch (Throwable $ignored) {}
    }
    structuredLog('ERROR', 'AUTH.PASSWORD_CHANGE_ERROR', [
        'exception' => get_class($error),
        'message' => $error->getMessage(),
    ]);
    jsonResponse(['success' => false, 'message' => 'Unable to change the password right now.'], 500);
}
