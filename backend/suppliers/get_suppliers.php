<?php

header('Content-Type: application/json');

require_once __DIR__ . '/../config/response.php';
require_once __DIR__ . '/../config/db.php';
require_once __DIR__ . '/../auth/auth_required.php';
require_once __DIR__ . '/../auth/role_helper.php';

require_once __DIR__ . '/supplier_service.php';



try {
    if (($_SERVER['REQUEST_METHOD'] ?? 'GET') !== 'GET') {
        jsonResponse([
            'success' => false,
            'message' => 'Method not allowed. Use GET.'
        ], 405);
        exit;
    }

    $authUser = requireAuth();
    $userId = (int)($authUser->id ?? 0);
    if ($userId <= 0) {
        throw new Exception('Unauthorized');
    }

    $conn = db();
    requirePermission($conn, $userId, 'suppliers.view');
    ensureSuppliersTable($conn);

    $stmt = $conn->prepare("
        SELECT id, reference, type, name, email, phone, address, fiscal_id
        FROM suppliers
        WHERE user_id = ?
        ORDER BY id DESC
    ");

    if (!$stmt) {
        throw new Exception('Failed to prepare supplier list query: ' . $conn->error);
    }

    $stmt->bind_param('i', $userId);
    $stmt->execute();
    $result = $stmt->get_result();

    $suppliers = [];
    while ($row = $result->fetch_assoc()) {
        $suppliers[] = supplierRow($row);
    }

    $stmt->close();

    jsonResponse([
        'success' => true,
        'data' => $suppliers,
    ]);
} catch (Throwable $e) {
    jsonResponse([
        'success' => false,
        'message' => $e->getMessage(),
    ], 400);
}
