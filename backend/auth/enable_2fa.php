<?php

header('Content-Type: application/json');

require_once __DIR__ . '/../vendor/autoload.php';
require_once __DIR__ . '/../config/db.php';
require_once __DIR__ . '/../config/response.php';
require_once __DIR__ . '/../auth/auth_required.php';
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
    $email = (string)$authUser->email;

    $conn = db();

    $stmt = $conn->prepare("
        SELECT google2fa_enabled
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

    if (!$user) {
        throw new Exception('User not found');
    }

    if ((int)($user['google2fa_enabled'] ?? 0) === 1) {
        throw new Exception('Two-factor authentication is already enabled');
    }

    $google2fa = new Google2FA();
    $secret = $google2fa->generateSecretKey();
    $encryptedSecret = encryptTwoFactorSecret($secret);

    $issuer = 'Factorator';
    $qrUrl = $google2fa->getQRCodeUrl(
        $issuer,
        $email,
        $secret
    );

    $stmt = $conn->prepare("
        UPDATE users
        SET google2fa_secret = ?, google2fa_enabled = 0
        WHERE id = ?
    ");

    if (!$stmt) {
        throw new Exception('Prepare failed: ' . $conn->error);
    }

    $stmt->bind_param('si', $encryptedSecret, $userId);
    $stmt->execute();
    $stmt->close();

    jsonResponse([
        'success' => true,
        'secret' => $secret,
        'qr_url' => $qrUrl
    ]);
} catch (Throwable $e) {
    jsonResponse([
        'success' => false,
        'message' => $e->getMessage()
    ], 400);
}
