<?php

declare(strict_types=1);

header('Content-Type: application/json');

require_once __DIR__ . '/../auth/auth_required.php';
require_once __DIR__ . '/../config/response.php';
require_once __DIR__ . '/../config/db.php';
require_once __DIR__ . '/../config/audit.php';

try {
    if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'POST') {
        jsonResponse(['success' => false, 'message' => 'Method not allowed. Use POST.'], 405);
    }

    $auth = requireAuth();
    $companyId = authTenantId($auth);
    $actorId = authActorId($auth);
    $data = json_decode(file_get_contents('php://input'), true);
    if (!is_array($data)) {
        jsonResponse(['success' => false, 'message' => 'Invalid JSON body.'], 400);
    }

    $displayName = trim((string)($data['display_name'] ?? ''));
    if ($displayName === '' || mb_strlen($displayName) > 191) {
        jsonResponse(['success' => false, 'message' => 'Display name is required and must not exceed 191 characters.'], 422);
    }

    $conn = db();
    $conn->begin_transaction();
    $beforeStmt = $conn->prepare('SELECT display_name, email FROM users WHERE id = ? LIMIT 1 FOR UPDATE');
    $beforeStmt->bind_param('i', $actorId);
    $beforeStmt->execute();
    $before = $beforeStmt->get_result()->fetch_assoc();
    $beforeStmt->close();
    if (!$before) {
        jsonResponse(['success' => false, 'message' => 'User account not found.'], 404);
    }

    $update = $conn->prepare('UPDATE users SET display_name = ? WHERE id = ?');
    $update->bind_param('si', $displayName, $actorId);
    $update->execute();
    $update->close();
    auditLog($conn, $companyId, $actorId, 'USER.ACCOUNT_UPDATED', 'USER', $actorId, $before, [
        'display_name' => $displayName,
        'email' => (string)$before['email'],
    ], 'AUTH');
    $conn->commit();

    jsonResponse([
        'success' => true,
        'message' => 'Account updated successfully.',
        'user' => [
            'id' => $actorId,
            'display_name' => $displayName,
            'email' => (string)$before['email'],
        ],
    ]);
} catch (Throwable $error) {
    if (isset($conn)) {
        try { $conn->rollback(); } catch (Throwable $ignored) {}
    }
    jsonResponse(['success' => false, 'message' => $error->getMessage()], 400);
}
