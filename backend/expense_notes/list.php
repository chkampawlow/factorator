<?php

header('Content-Type: application/json');

require_once __DIR__ . '/../config/response.php';
require_once __DIR__ . '/../config/db.php';
require_once __DIR__ . '/../auth/auth_required.php';
require_once __DIR__ . '/../auth/role_helper.php';

require_once __DIR__ . '/expense_service.php';



try {
    if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
        jsonResponse([
            'success' => false,
            'message' => 'Method not allowed. Use GET.'
        ], 405);
        exit;
    }

    $authUser = requireAuth();
    $user_id = (int)$authUser->id;

    $conn = db();requirePermission($conn, $user_id, 'expenses.view');
    ensureExpenseNotesSchema($conn);

    $stmt = $conn->prepare("
        SELECT
            e.id,
            e.title,
            e.category,
            e.amount,
            e.expense_date,
            e.description,
            e.receipt_path,
            e.status,
            e.created_at,
            e.updated_at,
            e.supplier_id,
            e.source_document_type,
            e.source_document_id,
            e.source_document_number,
            s.name AS supplier_name,
            s.reference AS supplier_reference
        FROM expense_notes e
        LEFT JOIN suppliers s
            ON s.id = e.supplier_id
           AND s.user_id = e.user_id
        WHERE e.user_id = ?
        ORDER BY e.expense_date DESC, e.id DESC
    ");

    if (!$stmt) {
        throw new Exception('Failed to prepare list query: ' . $conn->error);
    }

    $stmt->bind_param('i', $user_id);
    $stmt->execute();

    $result = $stmt->get_result();
    $rows = [];

    while ($row = $result->fetch_assoc()) {
        $rows[] = $row;
    }

    $stmt->close();

    jsonResponse([
        'success' => true,
        'items' => $rows
    ]);
} catch (Throwable $e) {
    jsonResponse([
        'success' => false,
        'message' => $e->getMessage()
    ], 400);
}
