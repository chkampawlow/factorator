<?php

header('Content-Type: application/json');

require_once __DIR__ . '/../config/response.php';
require_once __DIR__ . '/../config/db.php';
require_once __DIR__ . '/../config/validator.php';
require_once __DIR__ . '/../auth/auth_required.php';
require_once __DIR__ . '/../auth/role_helper.php';




try {
    if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
        jsonResponse([
            'success' => false,
            'message' => 'Method not allowed. Use POST.'
        ], 405);
        exit;
    }

    $authUser = requireAuth();
    $user_id = (int)$authUser->id;

    $data = requireJsonBody();
    $id = getRequiredInt($data, 'id', 'Expense note ID');

    $conn = db();
    requirePermission($conn, $user_id, 'expenses.delete');

    $stmt = $conn->prepare("
        DELETE FROM expense_notes
        WHERE id = ? AND user_id = ? AND status = 'PENDING'
    ");

    if (!$stmt) {
        throw new Exception('Failed to prepare delete query: ' . $conn->error);
    }

    $stmt->bind_param('ii', $id, $user_id);
    $stmt->execute();

    if ($stmt->error) {
        throw new Exception('Failed to delete expense note: ' . $stmt->error);
    }

    if ($stmt->affected_rows === 0) {
        $stmt->close();
        throw new Exception('Only pending expense notes can be deleted');
    }

    $stmt->close();

    jsonResponse([
        'success' => true,
        'message' => 'Expense note deleted successfully'
    ]);
} catch (Throwable $e) {
    jsonResponse([
        'success' => false,
        'message' => $e->getMessage()
    ], 400);
}
