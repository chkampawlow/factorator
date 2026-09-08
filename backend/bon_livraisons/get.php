<?php
header('Content-Type: application/json');
require_once __DIR__ . '/../config/response.php';
require_once __DIR__ . '/../config/db.php';
require_once __DIR__ . '/../auth/auth_required.php';
require_once __DIR__ . '/../auth/role_helper.php';
require_once __DIR__ . '/../config/field_projection.php';

require_once __DIR__ . '/helpers.php';


try {
    if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
        jsonResponse(['success' => false, 'message' => 'Method not allowed'], 405);
    }

    $userId = (int)requireAuth()->id;
    $id = (int)($_GET['id'] ?? 0);
    if ($id <= 0) throw new Exception('Invalid delivery note id');

    $conn = db();requirePermission($conn,$userId,'deliveries.view');
    ensureDeliverySchema($conn);
    $stmt = $conn->prepare("SELECT dn.*, c.name AS client_name, c.email AS client_email, so.order_number
        FROM erp_delivery_notes dn
        LEFT JOIN clients c ON c.id = dn.client_id AND c.user_id = dn.user_id
        LEFT JOIN erp_sales_orders so ON so.id = dn.sales_order_id AND so.user_id = dn.user_id
        WHERE dn.id = ? AND dn.user_id = ? LIMIT 1");
    $stmt->bind_param('ii', $id, $userId);
    $stmt->execute();
    $delivery = $stmt->get_result()->fetch_assoc();
    $stmt->close();

    if (!$delivery) throw new Exception('Delivery note not found or unauthorized');
    $delivery = projectOperationalDocumentFields($delivery);

    $itemsStmt = $conn->prepare('SELECT * FROM erp_delivery_note_items WHERE delivery_note_id = ? ORDER BY id');
    $itemsStmt->bind_param('i', $id);
    $itemsStmt->execute();
    $items = $itemsStmt->get_result()->fetch_all(MYSQLI_ASSOC);
    $itemsStmt->close();
    $items = projectRows($items, 'projectOperationalDocumentFields');

    jsonResponse(['success' => true, 'delivery' => $delivery, 'items' => $items]);
} catch (Throwable $e) {
    jsonResponse(['success' => false, 'message' => $e->getMessage()], resourceExceptionStatus($e));
}
