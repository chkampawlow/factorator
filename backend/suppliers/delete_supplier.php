<?php

header('Content-Type: application/json');

require_once __DIR__ . '/../config/response.php';
require_once __DIR__ . '/../config/db.php';
require_once __DIR__ . '/../auth/auth_required.php';
require_once __DIR__ . '/../auth/role_helper.php';

require_once __DIR__ . '/supplier_service.php';



try {
    $method = strtoupper($_SERVER['REQUEST_METHOD'] ?? '');
    if ($method !== 'POST' && $method !== 'DELETE') {
        jsonResponse([
            'success' => false,
            'message' => 'Method not allowed. Use POST or DELETE.'
        ], 405);
        exit;
    }

    $authUser = requireAuth();
    $userId = (int)($authUser->id ?? 0);
    if ($userId <= 0) {
        throw new Exception('Unauthorized');
    }

    $conn = db();
    requirePermission($conn, $userId, 'suppliers.delete');
    ensureSuppliersTable($conn);

    $rawBody = file_get_contents('php://input');
    $data = json_decode($rawBody ?: '', true);

    $id = 0;
    if (is_array($data) && isset($data['id'])) {
        $id = (int)$data['id'];
    }
    if ($id <= 0 && isset($_GET['id'])) {
        $id = (int)$_GET['id'];
    }

    if ($id <= 0) {
        throw new Exception('Supplier ID is required');
    }

    $existing = getSupplierById($conn, $userId, $id);
    if (!$existing) {
        jsonResponse([
            'success' => false,
            'message' => 'Supplier not found or unauthorized',
        ], 404);
        exit;
    }

    $stmt = $conn->prepare("DELETE FROM suppliers WHERE id = ? AND user_id = ? LIMIT 1");
    if (!$stmt) {
        throw new Exception('Failed to prepare supplier delete: ' . $conn->error);
    }

    $stmt->bind_param('ii', $id, $userId);
    $stmt->execute();

    if ((int)$stmt->affected_rows <= 0) {
        throw new Exception('Delete failed (no rows affected)');
    }

    $stmt->close();

    jsonResponse([
        'success' => true,
        'id' => $id,
        'message' => 'Supplier deleted successfully',
    ]);
} catch (Throwable $e) {
    jsonResponse([
        'success' => false,
        'message' => $e->getMessage(),
    ], 400);
}
