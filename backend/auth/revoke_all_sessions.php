<?php

declare(strict_types=1);

header('Content-Type: application/json');

require_once __DIR__ . '/../config/response.php';
require_once __DIR__ . '/../config/audit.php';
require_once __DIR__ . '/auth_required.php';
require_once __DIR__ . '/auth_cookie.php';

try {
    if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'POST') {
        jsonResponse(['success' => false, 'message' => 'Method not allowed. Use POST.'], 405);
    }

    $authUser = requireAuth(true);
    $actorId = authActorId($authUser);
    $companyId = authTenantId($authUser);
    $conn = db();
    $conn->begin_transaction();

    $stmt = $conn->prepare('
        UPDATE auth_refresh_tokens
        SET revoked_at = COALESCE(revoked_at, NOW())
        WHERE user_id = ?
    ');
    $stmt->bind_param('i', $actorId);
    $stmt->execute();
    $revokedCount = $stmt->affected_rows;
    $stmt->close();

    auditLog($conn, $companyId, $actorId, 'AUTH.ALL_SESSIONS_REVOKED', 'USER', $actorId, null, [
        'refresh_sessions_revoked' => $revokedCount,
    ], 'AUTH');
    $conn->commit();

    clearAuthCookies();
    jsonResponse(['success' => true, 'message' => 'All refresh sessions were revoked.']);
} catch (Throwable $error) {
    if (isset($conn)) {
        try { $conn->rollback(); } catch (Throwable $ignored) {}
    }
    structuredLog('ERROR', 'AUTH.REVOKE_ALL_SESSIONS_ERROR', [
        'exception' => get_class($error),
        'message' => $error->getMessage(),
    ]);
    jsonResponse(['success' => false, 'message' => 'Unable to sign out all devices right now.'], 500);
}
