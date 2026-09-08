<?php

header('Content-Type: application/json');

require_once __DIR__ . '/../config/db.php';
require_once __DIR__ . '/../config/response.php';
require_once __DIR__ . '/../auth/auth_required.php';




try {
    if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
        jsonResponse([
            'success' => false,
            'message' => 'Method not allowed. Use GET.'
        ], 405);
        exit;
    }

    $authUser = requireAuth(true);
    $userId = authActorId($authUser);

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

    jsonResponse([
        'success' => true,
        'enabled' => (int)($user['google2fa_enabled'] ?? 0) === 1
    ]);
} catch (Throwable $e) {
    jsonResponse([
        'success' => false,
        'message' => $e->getMessage()
    ], 400);
}
