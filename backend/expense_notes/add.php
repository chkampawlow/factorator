<?php

header('Content-Type: application/json');

require_once __DIR__ . '/../config/response.php';
require_once __DIR__ . '/../config/db.php';
require_once __DIR__ . '/../config/validator.php';
require_once __DIR__ . '/../auth/auth_required.php';
require_once __DIR__ . '/../auth/role_helper.php';
require_once __DIR__ . '/../config/tenant_scope.php';

require_once __DIR__ . '/expense_service.php';



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

    $title = getRequiredString($data, 'title', 'Title');
    $category = getRequiredString($data, 'category', 'Category');
    $amount = (float)($data['amount'] ?? -1);
    $expense_date = getRequiredString($data, 'expense_date', 'Expense date');
    $description = trim((string)($data['description'] ?? ''));
    $receipt_path = trim((string)($data['receipt_path'] ?? ''));
    $status = strtoupper(trim((string)($data['status'] ?? 'PENDING')));
    $supplier_id = max(0, (int)($data['supplier_id'] ?? 0));
    $source_document_type = strtoupper(trim((string)($data['source_document_type'] ?? '')));
    $source_document_id = max(0, (int)($data['source_document_id'] ?? 0));
    $source_document_number = trim((string)($data['source_document_number'] ?? ''));

    validateEnum($status, ['PENDING', 'APPROVED', 'REJECTED', 'REIMBURSED'], 'Status');
    if ($status !== 'PENDING') {
        throw new Exception('New expense notes must start as pending');
    }
    if ($source_document_type !== '') {
        validateEnum($source_document_type, ['SUPPLIER_RECEPTION', 'SUPPLIER_ORDER'], 'Source document type');
    }

    if ($amount < 0) {
        throw new Exception('Amount must be greater than or equal to 0');
    }

    if (!preg_match('/^\d{4}-\d{2}-\d{2}$/', $expense_date)) {
        throw new Exception('Expense date must be in YYYY-MM-DD format');
    }

    $conn = db();
    requirePermission($conn, $user_id, 'expenses.create');
    ensureExpenseNotesSchema($conn);
    if ($supplier_id > 0) requireTenantSupplier($conn, $user_id, $supplier_id);
    if ($source_document_id > 0) {
        if ($source_document_type === '') throw new Exception('Source document type is required');
        requireTenantExpenseSource($conn, $user_id, $source_document_type, $source_document_id, $supplier_id);
    }

    $stmt = $conn->prepare("
        INSERT INTO expense_notes (
            user_id,
            supplier_id,
            title,
            category,
            amount,
            expense_date,
            description,
            receipt_path,
            source_document_type,
            source_document_id,
            source_document_number,
            status
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ");

    if (!$stmt) {
        throw new Exception('Failed to prepare insert query: ' . $conn->error);
    }

    $stmt->bind_param(
        'iissdssssiss',
        $user_id,
        $supplier_id,
        $title,
        $category,
        $amount,
        $expense_date,
        $description,
        $receipt_path,
        $source_document_type,
        $source_document_id,
        $source_document_number,
        $status
    );

    $stmt->execute();

    if ($stmt->error) {
        throw new Exception('Failed to add expense note: ' . $stmt->error);
    }

    $id = $stmt->insert_id;
    $stmt->close();

    jsonResponse([
        'success' => true,
        'message' => 'Expense note added successfully',
        'id' => $id
    ]);
} catch (Throwable $e) {
    jsonResponse([
        'success' => false,
        'message' => $e->getMessage()
    ], 400);
}
