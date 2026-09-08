<?php

require_once __DIR__ . '/../config/db.php';
require_once __DIR__ . '/jwt_helper.php';
require_once __DIR__ . '/role_helper.php';
require_once __DIR__ . '/../config/audit.php';

function refreshTokenHash(string $token): string
{
    return hash('sha256', $token);
}

function refreshClientHash(string $value): string
{
    return hash_hmac('sha256', trim($value), (string)$_ENV['JWT_SECRET']);
}

function issueRefreshToken(array $user, int $expiresInSeconds): string
{
    $token = generateRefreshJwt($user, $expiresInSeconds);
    $hash = refreshTokenHash($token);
    $expiresAtEpoch = time() + $expiresInSeconds;
    $userAgentHash = refreshClientHash((string)($_SERVER['HTTP_USER_AGENT'] ?? 'unknown'));
    $ipHash = refreshClientHash((string)($_SERVER['REMOTE_ADDR'] ?? 'unknown'));
    $userId = (int)$user['id'];
    $companyId = (int)($user['company_id'] ?? $user['tenant_id'] ?? 0);
    $membershipId = (int)($user['membership_id'] ?? 0);
    if ($companyId <= 0 || $membershipId <= 0) {
        throw new RuntimeException('An active company membership is required to create a session.');
    }

    $stmt = db()->prepare('
        INSERT INTO auth_refresh_tokens
            (user_id, company_id, membership_id, token_hash, expires_at, user_agent_hash, ip_hash)
        VALUES (?, ?, ?, ?, FROM_UNIXTIME(?), ?, ?)
    ');
    $stmt->bind_param('iiisiss', $userId, $companyId, $membershipId, $hash, $expiresAtEpoch, $userAgentHash, $ipHash);
    $stmt->execute();
    $stmt->close();

    if (random_int(1, 100) === 1) {
        db()->query('DELETE FROM auth_refresh_tokens WHERE expires_at < DATE_SUB(NOW(), INTERVAL 7 DAY)');
    }

    return $token;
}

function rotateRefreshToken(string $token): array
{
    $decoded = decodeJwt($token);
    if (($decoded->type ?? '') !== 'refresh') {
        throw new RuntimeException('Invalid refresh token.');
    }

    $hash = refreshTokenHash($token);
    $conn = db();
    $conn->begin_transaction();
    try {
        $stmt = $conn->prepare('SELECT id, user_id, company_id, membership_id, UNIX_TIMESTAMP(expires_at) AS expires_at_epoch, revoked_at FROM auth_refresh_tokens WHERE token_hash = ? LIMIT 1 FOR UPDATE');
        $stmt->bind_param('s', $hash);
        $stmt->execute();
        $record = $stmt->get_result()->fetch_assoc();
        $stmt->close();

        if (!$record) {
            throw new RuntimeException('Refresh session not found.');
        }

        $userId = (int)$record['user_id'];
        if (!empty($record['revoked_at'])) {
            $stmt = $conn->prepare('UPDATE auth_refresh_tokens SET revoked_at = COALESCE(revoked_at, NOW()) WHERE user_id = ? AND revoked_at IS NULL');
            $stmt->bind_param('i', $userId);
            $stmt->execute();
            $stmt->close();
            $conn->commit();
            throw new RuntimeException('Refresh token reuse detected.');
        }
        $expiresAtEpoch = (int)$record['expires_at_epoch'];
        if ($expiresAtEpoch <= time()) {
            throw new RuntimeException('Refresh token expired.');
        }

        $stmt = $conn->prepare("SELECT id, email, account_status FROM users WHERE id = ? LIMIT 1");
        $stmt->bind_param('i', $userId);
        $stmt->execute();
        $user = $stmt->get_result()->fetch_assoc();
        $stmt->close();
        if (!$user) {
            throw new RuntimeException('User not found.');
        }
        if (($user['account_status'] ?? '') !== 'ACTIVE') {
            throw new RuntimeException('User account is not active.');
        }
        $companyId = (int)($record['company_id'] ?? $decoded->user->company_id ?? $decoded->user->tenant_id ?? 0);
        $membership = requireActiveCompanyMembership($conn, $userId, $companyId > 0 ? $companyId : null, true);
        if ((int)($record['membership_id'] ?? 0) > 0
            && (int)$record['membership_id'] !== (int)$membership['membership_id']) {
            throw new RuntimeException('Refresh session membership no longer matches.');
        }
        $user['company_id'] = (int)$membership['company_id'];
        $user['tenant_id'] = (int)$membership['company_id'];
        $user['membership_id'] = (int)$membership['membership_id'];
        $user['membership_version'] = (int)($membership['membership_version'] ?? 1);
        $user['role'] = normalizeUserRole($membership['role'] ?? null);

        $expiresInSeconds = max(1, $expiresAtEpoch - time());
        $newToken = generateRefreshJwt($user, $expiresInSeconds);
        $newHash = refreshTokenHash($newToken);
        $userAgentHash = refreshClientHash((string)($_SERVER['HTTP_USER_AGENT'] ?? 'unknown'));
        $ipHash = refreshClientHash((string)($_SERVER['REMOTE_ADDR'] ?? 'unknown'));
        $membershipId = (int)$membership['membership_id'];
        $companyId = (int)$membership['company_id'];
        $stmt = $conn->prepare('INSERT INTO auth_refresh_tokens (user_id, company_id, membership_id, token_hash, expires_at, user_agent_hash, ip_hash) VALUES (?, ?, ?, ?, FROM_UNIXTIME(?), ?, ?)');
        $stmt->bind_param('iiisiss', $userId, $companyId, $membershipId, $newHash, $expiresAtEpoch, $userAgentHash, $ipHash);
        $stmt->execute();
        $stmt->close();

        $recordId = (int)$record['id'];
        $stmt = $conn->prepare('UPDATE auth_refresh_tokens SET revoked_at = NOW(), replaced_by_hash = ?, last_used_at = NOW() WHERE id = ?');
        $stmt->bind_param('si', $newHash, $recordId);
        $stmt->execute();
        $stmt->close();
        $conn->commit();

        return ['user' => $user, 'refresh_token' => $newToken, 'expires_in' => $expiresInSeconds];
    } catch (Throwable $e) {
        try { $conn->rollback(); } catch (Throwable $ignored) {}
        throw $e;
    }
}

function revokeRefreshToken(string $token): ?int
{
    if ($token === '') return null;
    $hash = refreshTokenHash($token);
    $conn = db();
    $conn->begin_transaction();
    try {
    $stmt = $conn->prepare('SELECT user_id, company_id FROM auth_refresh_tokens WHERE token_hash=? LIMIT 1 FOR UPDATE');
    $stmt->bind_param('s', $hash);
    $stmt->execute();
    $row = $stmt->get_result()->fetch_assoc();
    $stmt->close();
    if (!$row) { $conn->commit(); return null; }
    $userId = (int) $row['user_id'];
    $stmt = $conn->prepare('UPDATE auth_refresh_tokens SET revoked_at = COALESCE(revoked_at, NOW()) WHERE token_hash = ?');
    $stmt->bind_param('s', $hash);
    $stmt->execute();
    $stmt->close();
    $tenantId = (int)($row['company_id'] ?? 0);
    auditLog($conn, $tenantId > 0 ? $tenantId : null, $userId, 'AUTH.LOGOUT', 'USER', $userId, null,
        ['refresh_session_revoked'=>true], 'AUTH');
    $conn->commit();
    return $userId;
    } catch (Throwable $e) {
        try { $conn->rollback(); } catch (Throwable $ignored) {}
        throw $e;
    }
}

function revokeAllRefreshTokens(int $userId): void
{
    $stmt = db()->prepare('UPDATE auth_refresh_tokens SET revoked_at = COALESCE(revoked_at, NOW()) WHERE user_id = ?');
    $stmt->bind_param('i', $userId);
    $stmt->execute();
    $stmt->close();
}

function revokeCompanyRefreshTokens(int $userId, int $companyId): void
{
    $stmt = db()->prepare('UPDATE auth_refresh_tokens SET revoked_at = COALESCE(revoked_at, NOW()) WHERE user_id = ? AND company_id = ?');
    $stmt->bind_param('ii', $userId, $companyId);
    $stmt->execute();
    $stmt->close();
}
