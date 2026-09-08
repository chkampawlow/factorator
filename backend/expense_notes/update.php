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
    $title = getRequiredString($data, 'title', 'Title');
    $category = getRequiredString($data, 'category', 'Category');
    $amount = (float)($data['amount'] ?? -1);
    $expense_date = getRequiredString($data, 'expense_date', 'Expense date');
    $description = trim((string)($data['description'] ?? ''));
    $receipt_path = trim((string)($data['receipt_path'] ?? ''));
    $status = strtoupper(trim((string)($data['status'] ?? 'PENDING')));

    validateEnum($status, ['PENDING', 'APPROVED', 'REJECTED', 'REIMBURSED'], 'Status');
    if ($status !== 'PENDING') {
        throw new Exception('Use the expense status action to approve or reject an expense');
    }

    if ($amount < 0) {
        throw new Exception('Amount must be greater than or equal to 0');
    }

    if (!preg_match('/^\d{4}-\d{2}-\d{2}$/', $expense_date)) {
        throw new Exception('Expense date must be in YYYY-MM-DD format');
    }

    $conn = db();
    requirePermission($conn, $user_id, 'expenses.edit');

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
    if (strtoupper((string)$existing['status']) !== 'PENDING') {
        throw new Exception('Only pending expense notes can be edited');
    }

    $stmt = $conn->prepare("
        UPDATE expense_notes
        SET
            title = ?,
            category = ?,
            amount = ?,
            expense_date = ?,
            description = ?,
            receipt_path = ?,
            status = ?
        WHERE id = ? AND user_id = ? AND status = 'PENDING'
    ");

    if (!$stmt) {
        throw new Exception('Failed to prepare update query: ' . $conn->error);
    }

    $stmt->bind_param(
        'ssdssssii',
        $title,
        $category,
        $amount,
        $expense_date,
        $description,
        $receipt_path,
        $status,
        $id,
        $user_id
    );

    $stmt->execute();

    if ($stmt->error) {
        throw new Exception('Failed to update expense note: ' . $stmt->error);
    }

    $stmt->close();

    jsonResponse([
        'success' => true,
        'message' => 'Expense note updated successfully'
    ]);
} catch (Throwable $e) {
    jsonResponse([
        'success' => false,
        'message' => $e->getMessage()
    ], 400);
}
