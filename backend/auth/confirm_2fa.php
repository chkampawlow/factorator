<?php

header('Content-Type: application/json');

require_once __DIR__ . '/../vendor/autoload.php';
require_once __DIR__ . '/../config/db.php';
require_once __DIR__ . '/../config/response.php';
require_once __DIR__ . '/../auth/auth_required.php';
require_once __DIR__ . '/../config/rate_limit.php';
require_once __DIR__ . '/../config/two_factor_crypto.php';


use PragmaRX\Google2FA\Google2FA;



try {
    if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
        jsonResponse([
            'success' => false,
            'message' => 'Method not allowed. Use POST.'
        ], 405);
        exit;
    }

    $authUser = requireAuth(true);
    $userId = authActorId($authUser);

    enforceRateLimit('confirm_2fa', (string)$userId, 10, 15 * 60);

    $data = json_decode(file_get_contents("php://input"), true);

    if (!is_array($data)) {
        throw new Exception('Invalid JSON body');
    }

    $code = trim((string)($data['code'] ?? ''));

    if (!preg_match('/^\d{6}$/', $code)) {
        throw new Exception('Invalid code format');
    }

    $conn = db();

    $stmt = $conn->prepare("
        SELECT google2fa_secret, google2fa_enabled
        FROM users
        WHERE id = ?
        LIMIT 1
    ");

    if (!$stmt) {
        throw new Exception('Prepare failed: ' . $conn->error);
    }

    $stmt->bind_param('i', $userId);
    $stmt->execute();
    $user = $stmt->get_result()->fetch_assoc();
    $stmt->close();

    if (!$user || empty($user['google2fa_secret'])) {
        throw new Exception('2FA secret not found');
    }

    if ((int)($user['google2fa_enabled'] ?? 0) === 1) {
        throw new Exception('Two-factor authentication is already enabled');
    }

    $google2fa = new Google2FA();
    $secret = decryptTwoFactorSecret((string)$user['google2fa_secret']);

    $valid = $google2fa->verifyKey(
        $secret,
        $code,
        1
    );

    if (!$valid) {
        throw new Exception('Invalid authenticator code');
    }

    clearRateLimit('confirm_2fa', (string)$userId);

    $stmt = $conn->prepare("
        UPDATE users
        SET google2fa_enabled = 1
        WHERE id = ?
    ");

    if (!$stmt) {
        throw new Exception('Prepare failed: ' . $conn->error);
    }

    $stmt->bind_param('i', $userId);
    $stmt->execute();
    $stmt->close();

    jsonResponse([
        'success' => true,
        'message' => '2FA enabled successfully'
    ]);
} catch (Throwable $e) {
    jsonResponse([
        'success' => false,
        'message' => $e->getMessage()
    ], 400);
}
