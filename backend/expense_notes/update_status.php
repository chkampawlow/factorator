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

    $id = isset($data['id'])
        ? getRequiredInt($data, 'id', 'Expense note ID')
        : getRequiredInt($data, 'expense_note_id', 'Expense note ID');

    $statusField = isset($data['status']) ? 'status' : 'new_status';
    $status = strtoupper(getRequiredString($data, $statusField, 'Status'));

    validateEnum($status, ['APPROVED', 'REJECTED', 'REIMBURSED'], 'Status');

    $conn = db();
    requirePermission($conn, $user_id, 'expenses.approve');

    $check = $conn->prepare("
        SELECT id, status
        FROM expense_notes
        WHERE id = ? AND user_id = ?
        LIMIT 1
    ");

    if (!$check) {
        throw new Exception('Failed to prepare ownership check: ' . $conn->error);
    }

    $check->bind_param('ii', $id, $user_id);
    $check->execute();
    $existing = $check->get_result()->fetch_assoc();
    $check->close();

    if (!$existing) {
        throw new Exception('Expense note not found or unauthorized');
    }
    $currentStatus = strtoupper((string)$existing['status']);
    $allowedTransitions = [
        'PENDING' => ['APPROVED', 'REJECTED'],
        'APPROVED' => ['REIMBURSED'],
    ];
    if (!in_array($status, $allowedTransitions[$currentStatus] ?? [], true)) {
        throw new Exception('Invalid expense status transition');
    }

    $stmt = $conn->prepare("
        UPDATE expense_notes
        SET status = ?
        WHERE id = ? AND user_id = ? AND status = ?
    ");

    if (!$stmt) {
        throw new Exception('Failed to prepare status update query: ' . $conn->error);
    }

    $stmt->bind_param('siis', $status, $id, $user_id, $currentStatus);
    $stmt->execute();

    if ($stmt->error) {
        throw new Exception('Failed to update expense note status: ' . $stmt->error);
    }
    if ($stmt->affected_rows !== 1) {
        throw new Exception('Expense note changed concurrently or is no longer pending');
    }

    $stmt->close();

    jsonResponse([
        'success' => true,
        'message' => 'Expense note status updated successfully',
        'id' => $id,
        'status' => $status,
        'db_status' => $status
    ]);
} catch (Throwable $e) {
    jsonResponse([
        'success' => false,
        'message' => $e->getMessage()
    ], 400);
}
