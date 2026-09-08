<?php

declare(strict_types=1);

header('Content-Type: application/json');

require_once __DIR__ . '/../config/response.php';
require_once __DIR__ . '/../config/db.php';
require_once __DIR__ . '/../auth/auth_required.php';
require_once __DIR__ . '/../auth/role_helper.php';
require_once __DIR__ . '/expense_service.php';

try {
    if (($_SERVER['REQUEST_METHOD'] ?? 'GET') !== 'GET') {
        jsonResponse(['success' => false, 'message' => 'Method not allowed. Use GET.'], 405);
    }

    $userId = (int)requireAuth()->id;
    $expenseId = (int)($_GET['id'] ?? 0);
    if ($expenseId <= 0) {
        jsonResponse(['success' => false, 'message' => 'Invalid expense id.'], 422);
    }

    $conn = db();
    requirePermission($conn, $userId, 'expenses.view');
    ensureExpenseNotesSchema($conn);
    $stmt = $conn->prepare("SELECT e.id,e.title,e.category,e.amount,e.expense_date,e.description,e.receipt_path,e.status,e.created_at,e.updated_at,e.supplier_id,e.source_document_type,e.source_document_id,e.source_document_number,s.name supplier_name,s.reference supplier_reference FROM expense_notes e LEFT JOIN suppliers s ON s.id=e.supplier_id AND s.user_id=e.user_id WHERE e.id=? AND e.user_id=? LIMIT 1");
    $stmt->bind_param('ii', $expenseId, $userId);
    $stmt->execute();
    $expense = $stmt->get_result()->fetch_assoc();
    $stmt->close();

    if (!$expense) {
        jsonResponse(['success' => false, 'message' => 'Expense not found.'], 404);
    }
    jsonResponse(['success' => true, 'expense' => $expense]);
} catch (Throwable $e) {
    jsonResponse(['success' => false, 'message' => 'Could not load the expense.', 'error_code' => 'EXPENSE_GET_FAILED'], 500);
}
