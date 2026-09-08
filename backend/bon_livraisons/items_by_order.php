<?php

header('Content-Type: application/json');

require_once __DIR__ . '/../config/response.php';
require_once __DIR__ . '/../config/db.php';
require_once __DIR__ . '/../auth/auth_required.php';
require_once __DIR__ . '/../auth/role_helper.php';

try {
    if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
        jsonResponse(['success' => false, 'message' => 'Method not allowed'], 405);
    }

    $userId = (int)requireAuth()->id;
    $salesOrderId = (int)($_GET['sales_order_id'] ?? 0);
    if ($salesOrderId <= 0) {
        throw new Exception('Sales order is required');
    }

    $conn = db();
    requirePermission($conn, $userId, 'orders.view');

    // This endpoint deliberately has no LIMIT: the flow calculation must cover
    // every linked document, not just the currently visible list page.
    $stmt = $conn->prepare(
        "SELECT di.product_id, di.product_code, di.product, di.qty
         FROM erp_delivery_note_items di
         INNER JOIN erp_delivery_notes dn ON dn.id = di.delivery_note_id
         WHERE dn.user_id = ?
           AND dn.sales_order_id = ?
           AND dn.status <> 'CANCELLED'"
    );
    $stmt->bind_param('ii', $userId, $salesOrderId);
    $stmt->execute();
    $items = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);
    $stmt->close();

    jsonResponse(['success' => true, 'data' => $items]);
} catch (Throwable $e) {
    jsonResponse([
        'success' => false,
        'message' => 'Could not load sales-order delivery items.',
        'error_code' => 'ORDER_DELIVERY_ITEMS_FAILED',
    ], resourceExceptionStatus($e));
}
