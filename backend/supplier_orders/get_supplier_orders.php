<?php

header('Content-Type: application/json');

require_once __DIR__ . '/../config/response.php';
require_once __DIR__ . '/../config/db.php';
require_once __DIR__ . '/../auth/auth_required.php';
require_once __DIR__ . '/../auth/role_helper.php';

require_once __DIR__ . '/order_service.php';



try {
    if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
        jsonResponse(['success' => false, 'message' => 'Method not allowed'], 405);
    }

    $userId = (int)requireAuth()->id;
    $conn = db();
    requirePermission($conn, $userId, 'supplierOrders.view');

    $orderId = (int)($_GET['id'] ?? 0);
    if ($orderId <= 0) {
        jsonResponse(['success' => false, 'message' => 'An order id is required. Use list_page.php for collections.'], 422);
    }
    $order = getSupplierOrderForUser($conn, $userId, $orderId);
    if (!$order) {
        jsonResponse(['success' => false, 'message' => 'Supplier order not found.'], 404);
    }
    jsonResponse(['success' => true, 'order' => $order]);
} catch (Throwable $e) {
    jsonResponse(['success' => false, 'message' => $e->getMessage()], 400);
}
