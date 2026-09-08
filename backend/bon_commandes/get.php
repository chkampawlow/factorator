<?php
header('Content-Type: application/json');
require_once __DIR__ . '/../config/response.php';
require_once __DIR__ . '/../config/db.php';
require_once __DIR__ . '/../auth/auth_required.php';
require_once __DIR__ . '/../auth/role_helper.php';
require_once __DIR__ . '/../config/field_projection.php';

require_once __DIR__ . '/../invoices/workflow_schema.php';


try {
    if ($_SERVER['REQUEST_METHOD'] !== 'GET') jsonResponse(['success' => false, 'message' => 'Method not allowed'], 405);
    $userId = (int)requireAuth()->id;
    $id = (int)($_GET['id'] ?? 0);
    if ($id <= 0) throw new Exception('Invalid order id');
    $conn = db();requirePermission($conn,$userId,'orders.view');
    ensureInvoiceWorkflowSchema($conn);
    $stmt = $conn->prepare("SELECT so.*, c.name AS client_name, c.email AS client_email,
            sd.invoice AS source_devis_number
        FROM erp_sales_orders so LEFT JOIN clients c ON c.id = so.client_id AND c.user_id = so.user_id
        LEFT JOIN erp_invoices sd ON sd.id = so.source_devis_id AND sd.user_id = so.user_id
        WHERE so.id = ? AND so.user_id = ? LIMIT 1");
    $stmt->bind_param('ii', $id, $userId);
    $stmt->execute();
    $order = $stmt->get_result()->fetch_assoc();
    $stmt->close();
    if (!$order) throw new Exception('Order not found or unauthorized');
    $order = projectOperationalDocumentFields($order);
    $itemsStmt = $conn->prepare('SELECT * FROM erp_sales_order_items WHERE sales_order_id = ? ORDER BY id');
    $itemsStmt->bind_param('i', $id);
    $itemsStmt->execute();
    $items = $itemsStmt->get_result()->fetch_all(MYSQLI_ASSOC);
    $itemsStmt->close();
    $items = projectRows($items, 'projectOperationalDocumentFields');
    jsonResponse(['success' => true, 'order' => $order, 'items' => $items]);
} catch (Throwable $e) {
    jsonResponse(['success' => false, 'message' => $e->getMessage()], resourceExceptionStatus($e));
}
