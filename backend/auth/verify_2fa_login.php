<?php

header('Content-Type: application/json');

require_once __DIR__ . '/../vendor/autoload.php';
require_once __DIR__ . '/../config/db.php';
require_once __DIR__ . '/../config/response.php';
require_once __DIR__ . '/jwt_helper.php';
require_once __DIR__ . '/role_helper.php';
require_once __DIR__ . '/../config/rate_limit.php';
require_once __DIR__ . '/../config/audit.php';
require_once __DIR__ . '/../config/two_factor_crypto.php';
require_once __DIR__ . '/refresh_token_service.php';
require_once __DIR__ . '/auth_cookie.php';


use PragmaRX\Google2FA\Google2FA;



try {
    if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
        jsonResponse([
            'success' => false,
            'message' => 'Method not allowed. Use POST.'
        ], 405);
        exit;
    }

    $data = json_decode(file_get_contents("php://input"), true);

    if (!is_array($data)) {
        throw new Exception('Invalid JSON body');
    }

    $challengeToken = trim((string)($data['two_factor_challenge'] ?? ''));
    $code = trim((string)($data['code'] ?? ''));

    if ($challengeToken === '' || $code === '') {
        throw new InvalidArgumentException('Two-factor challenge and code are required');
    }

    try {
        $challenge = decodeTwoFactorChallenge($challengeToken);
    } catch (Throwable $e) {
        jsonResponse([
            'success' => false,
            'message' => 'Invalid or expired two-factor challenge.',
            'code' => 'INVALID_2FA_CHALLENGE',
        ], 401);
    }

    $userId = (int)$challenge->user_id;
    $email = strtolower(trim((string)($challenge->email ?? '')));
    $remember_me = (bool)($challenge->remember_me ?? false);
    enforceRateLimit('verify_2fa_login', (string)$userId, 10, 15 * 60);

    $conn = db();
    ensureUserRoleColumn($conn);

    $stmt = $conn->prepare("
        SELECT id, email, email_verified_at, google2fa_secret, google2fa_enabled, role, account_status
        FROM users
        WHERE id = ? AND email = ?
        LIMIT 1
    ");

    if (!$stmt) {
        throw new Exception('Prepare failed: ' . $conn->error);
    }

    $stmt->bind_param('is', $userId, $email);
    $stmt->execute();
    $user = $stmt->get_result()->fetch_assoc();
    $stmt->close();

    if (!$user || (int)$user['google2fa_enabled'] !== 1) {
        throw new Exception('2FA is not enabled for this account');
    }
    $accountStatus = strtoupper((string)($user['account_status'] ?? 'ACTIVE'));
    if ($accountStatus !== 'ACTIVE') {
        $isPending = $accountStatus === 'PENDING';
        jsonResponse([
            'success' => false,
            'message' => $isPending
                ? 'Your account is awaiting approval by a super administrator.'
                : 'This company account is archived.',
            'code' => $isPending ? 'ACCOUNT_PENDING_APPROVAL' : 'ACCOUNT_ARCHIVED',
        ], 403);
    }

    $requestedCompanyId = (int)($challenge->company_id ?? 0);
    try {
        $membership = requireActiveCompanyMembership(
            $conn,
            $userId,
            $requestedCompanyId > 0 ? $requestedCompanyId : null
        );
    } catch (RuntimeException $membershipError) {
        jsonResponse([
            'success' => false,
            'message' => $membershipError->getMessage(),
            'code' => 'MEMBERSHIP_INACTIVE',
        ], 403);
    }
    $user['company_id'] = (int)$membership['company_id'];
    $user['tenant_id'] = (int)$membership['company_id'];
    $user['membership_id'] = (int)$membership['membership_id'];
    $user['membership_version'] = (int)($membership['membership_version'] ?? 1);
    $user['role'] = normalizeUserRole($membership['role'] ?? null);

    $google2fa = new Google2FA();
    $secret = decryptTwoFactorSecret((string)$user['google2fa_secret']);
    $valid = $google2fa->verifyKey($secret, $code);

    if (!$valid) {
        auditLog($conn, (int)$membership['company_id'], $userId, 'AUTH.LOGIN_2FA_FAILED', 'USER', $userId,
            null, ['reason'=>'INVALID_AUTHENTICATOR_CODE'], 'AUTH');
        throw new Exception('Invalid authenticator code');
    }

    clearRateLimit('verify_2fa_login', (string)$userId);

    $accessExpiresIn = 60 * 15; // 15 minutes

    $refreshExpiresIn = $remember_me
        ? (60 * 60 * 24 * 30) // 30 days
        : (60 * 60 * 24 * 7); // 7 days

    $accessToken = generateJwt($user, $accessExpiresIn);
    $refreshToken = issueRefreshToken($user, $refreshExpiresIn);
    setAuthCookies($accessToken, $refreshToken, $accessExpiresIn, $refreshExpiresIn);

    auditLog($conn, (int)$membership['company_id'], $userId, 'AUTH.LOGIN_SUCCEEDED', 'USER', $userId,
        null, ['remember_me'=>$remember_me,'two_factor'=>true], 'AUTH');

    jsonResponse([
        'success' => true,
        'remember_me' => $remember_me,
        'access_expires_in' => $accessExpiresIn,
        'refresh_expires_in' => $refreshExpiresIn,
        'user' => [
            'id' => (int)$user['id'],
            'email' => $user['email'],
            'email_verified' => !empty($user['email_verified_at']),
            'role' => normalizeUserRole($user['role'] ?? null),
            'tenant_id' => (int)$membership['company_id'],
            'company_id' => (int)$membership['company_id'],
            'membership_id' => (int)$membership['membership_id'],
            'membership_status' => (string)$membership['membership_status'],
            'is_company_owner' => (int)($membership['is_owner'] ?? 0) === 1,
        ],
        'membership' => membershipPayload($membership, 'normalizeUserRole'),
        'company' => companyPayload($membership),
        'permissions' => permissionsForMembership($membership),
    ]);
} catch (Throwable $e) {
    jsonResponse([
        'success' => false,
        'message' => $e->getMessage()
    ], 400);
}
