<?php

header('Content-Type: application/json');

ini_set('display_errors', '0');
ini_set('display_startup_errors', '0');
ini_set('log_errors', '1');
error_reporting(E_ALL);

require_once __DIR__ . '/../config/db.php';
require_once __DIR__ . '/../config/response.php';
require_once __DIR__ . '/jwt_helper.php';
require_once __DIR__ . '/role_helper.php';
require_once __DIR__ . '/../config/rate_limit.php';
require_once __DIR__ . '/../config/audit.php';
require_once __DIR__ . '/refresh_token_service.php';
require_once __DIR__ . '/auth_cookie.php';
require_once __DIR__ . '/company_context.php';




try {
    if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
        jsonResponse([
            "success" => false,
            "message" => "Method not allowed. Use POST."
        ], 405);
        exit;
    }

    $data = json_decode(file_get_contents("php://input"), true);

    if (!is_array($data)) {
        throw new Exception("Invalid JSON body.");
    }

    $email = strtolower(trim($data['email'] ?? ''));
    $password = $data['password'] ?? '';
    $remember_me = (bool)($data['remember_me'] ?? false);

    enforceRateLimit('login', $email, 10, 15 * 60);

    if ($email === '' || $password === '') {
        jsonResponse([
            "success" => false,
            "message" => "Email and password are required."
        ], 400);
        exit;
    }

    $conn = db();
    ensureUserRoleColumn($conn);

    // ✅ ADD google2fa_enabled + secret
    $stmt = $conn->prepare("
        SELECT id, email, password_hash, email_verified_at, google2fa_enabled, role, account_status
        FROM users
        WHERE email = ?
        LIMIT 1
    ");

    if (!$stmt) {
        throw new Exception("Prepare failed: " . $conn->error);
    }

    $stmt->bind_param("s", $email);
    $stmt->execute();

    $user = $stmt->get_result()->fetch_assoc();
    $stmt->close();

    // Always perform one password verification so an unknown email and a wrong
    // password have the same response and comparable computational cost.
    $dummyPasswordHash = '$2y$10$KpwjR5ZhkA.pfuy9o760fOt21ZnzDcwtAXgWTMKYtyEapvopZcbEG';
    $passwordHash = $user ? (string)$user['password_hash'] : $dummyPasswordHash;
    $passwordMatches = password_verify($password, $passwordHash);

    if (!$user || !$passwordMatches) {
        auditLog($conn, $user ? (int)$user['id'] : null, null, 'AUTH.LOGIN_FAILED', 'USER',
            $user ? (int)$user['id'] : null, null,
            ['email_hash' => hash('sha256', $email), 'reason' => 'INVALID_CREDENTIALS'], 'AUTH');
        jsonResponse([
            "success" => false,
            "message" => "Invalid email or password."
        ], 401);
        exit;
    }

    $accountStatus = strtoupper((string)($user['account_status'] ?? 'ACTIVE'));
    if ($accountStatus !== 'ACTIVE') {
        $isPending = $accountStatus === 'PENDING';
        auditLog(
            $conn,
            (int)$user['id'],
            null,
            $isPending ? 'AUTH.LOGIN_BLOCKED_PENDING' : 'AUTH.LOGIN_BLOCKED_ARCHIVED',
            'USER',
            (int)$user['id'],
            null,
            ['account_status' => $accountStatus],
            'AUTH'
        );
        jsonResponse([
            'success' => false,
            'message' => $isPending
                ? 'Your account is awaiting approval by a super administrator.'
                : 'This company account is archived.',
            'code' => $isPending ? 'ACCOUNT_PENDING_APPROVAL' : 'ACCOUNT_ARCHIVED',
        ], 403);
    }

    clearRateLimit('login', $email);

    try {
        $membership = requireActiveCompanyMembership($conn, (int)$user['id']);
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

    // 🔥 NEW: CHECK 2FA
    if ((int)($user['google2fa_enabled'] ?? 0) === 1) {
        $challengeExpiresIn = 5 * 60;
        auditLog($conn, (int)$membership['company_id'], (int)$user['id'], 'AUTH.LOGIN_2FA_CHALLENGE',
            'USER', (int)$user['id'], null, ['remember_me' => $remember_me], 'AUTH');
        jsonResponse([
            "success" => true,
            "requires_2fa" => true,
            "two_factor_challenge" => generateTwoFactorChallenge($user, $remember_me, $challengeExpiresIn),
            "challenge_expires_in" => $challengeExpiresIn
        ]);
        exit;
    }

    // ✅ NORMAL LOGIN (no 2FA)
    $accessExpiresIn = 60 * 15; // 15 min

    $refreshExpiresIn = $remember_me
        ? (60 * 60 * 24 * 30)
        : (60 * 60 * 24 * 7);

    $accessToken = generateJwt($user, $accessExpiresIn);
    $refreshToken = issueRefreshToken($user, $refreshExpiresIn);
    setAuthCookies($accessToken, $refreshToken, $accessExpiresIn, $refreshExpiresIn);

    auditLog($conn, (int)$membership['company_id'], (int)$user['id'], 'AUTH.LOGIN_SUCCEEDED',
        'USER', (int)$user['id'], null, ['remember_me' => $remember_me, 'two_factor' => false], 'AUTH');

    jsonResponse([
        "success" => true,
        "remember_me" => $remember_me,
        "access_expires_in" => $accessExpiresIn,
        "refresh_expires_in" => $refreshExpiresIn,
        "user" => [
            "id" => (int)$user['id'],
            "email" => $user['email'],
            "email_verified" => !empty($user['email_verified_at']),
            "role" => normalizeUserRole($user['role'] ?? null),
            "tenant_id" => (int)$membership['company_id'],
            "company_id" => (int)$membership['company_id'],
            "membership_id" => (int)$membership['membership_id'],
            "membership_status" => (string)$membership['membership_status'],
            "is_company_owner" => (int)($membership['is_owner'] ?? 0) === 1
        ],
        'membership' => membershipPayload($membership, 'normalizeUserRole'),
        'company' => companyPayload($membership),
        'permissions' => permissionsForMembership($membership),
    ]);

} catch (Throwable $e) {
    structuredLog('ERROR', 'AUTH.LOGIN_ERROR', ['exception'=>get_class($e),'message'=>$e->getMessage()]);
    jsonResponse([
        "success" => false,
        "message" => "Unable to sign in right now."
    ], 500);
}
