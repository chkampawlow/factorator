<?php

header('Content-Type: application/json');

require_once __DIR__ . '/../config/response.php';
require_once __DIR__ . '/../config/db.php';
require_once __DIR__ . '/../auth/auth_required.php';
require_once __DIR__ . '/../auth/role_helper.php';

require_once __DIR__ . '/reception_service.php';



try {
    if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
        jsonResponse(['success' => false, 'message' => 'Method not allowed'], 405);
    }

    $userId = (int)requireAuth()->id;
    $conn = db();
    requirePermission($conn, $userId, 'supplierReceptions.view');

    $receptionId = (int)($_GET['id'] ?? 0);
    $supplierOrderId = (int)($_GET['supplier_order_id'] ?? 0);
    if ($receptionId <= 0 && $supplierOrderId <= 0) {
        jsonResponse(['success' => false, 'message' => 'A reception or supplier order id is required. Use list_page.php for collections.'], 422);
    }
    $rows = supplierReceptionsForUser($conn, $userId, $receptionId, $supplierOrderId);
    if ($receptionId > 0 && !$rows) {
        jsonResponse(['success' => false, 'message' => 'Supplier reception not found.'], 404);
    }
    jsonResponse(['success' => true, 'data' => $rows, 'reception' => $receptionId > 0 ? $rows[0] : null]);
} catch (Throwable $e) {
    jsonResponse(['success' => false, 'message' => $e->getMessage()], 400);
}
