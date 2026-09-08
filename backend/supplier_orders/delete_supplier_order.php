<?php

header('Content-Type: application/json');

require_once __DIR__ . '/../config/response.php';
require_once __DIR__ . '/../config/db.php';
require_once __DIR__ . '/../auth/auth_required.php';
require_once __DIR__ . '/../auth/role_helper.php';

require_once __DIR__ . '/order_service.php';



try {
    if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
        jsonResponse(['success' => false, 'message' => 'Method not allowed'], 405);
    }

    $userId = (int)requireAuth()->id;
    $data = requireJsonBody();
    $id = getRequiredInt($data, 'id', 'Supplier order');

    $conn = db();
    requirePermission($conn, $userId, 'supplierOrders.delete');
    ensureSupplierOrdersSchema($conn);

    $stmt = $conn->prepare("
        SELECT so.status, COUNT(sr.id) AS linked_receptions
        FROM erp_supplier_orders so
        LEFT JOIN erp_supplier_receptions sr ON sr.supplier_order_id = so.id AND sr.user_id = so.user_id
        WHERE so.id = ? AND so.user_id = ?
        GROUP BY so.id, so.status
        LIMIT 1
    ");
    if (!$stmt) {
        throw new Exception('Failed to prepare supplier order delete lookup: ' . $conn->error);
    }
    $stmt->bind_param('ii', $id, $userId);
    $stmt->execute();
    $row = $stmt->get_result()->fetch_assoc();
    $stmt->close();

    if (!$row) {
        throw new Exception('Supplier order not found or unauthorized');
    }
    if ((string)$row['status'] !== 'DRAFT') {
        throw new Exception('Only draft supplier orders can be deleted');
    }
    if ((int)($row['linked_receptions'] ?? 0) > 0) {
        throw new Exception('This supplier order already has linked receptions and cannot be deleted');
    }

    $delete = $conn->prepare('DELETE FROM erp_supplier_orders WHERE id = ? AND user_id = ?');
    if (!$delete) {
        throw new Exception('Failed to prepare supplier order deletion: ' . $conn->error);
    }
    $delete->bind_param('ii', $id, $userId);
    $delete->execute();
    $delete->close();

    jsonResponse(['success' => true, 'message' => 'Supplier order deleted']);
} catch (Throwable $e) {
    jsonResponse(['success' => false, 'message' => $e->getMessage()], 400);
}
