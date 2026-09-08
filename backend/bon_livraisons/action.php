<?php
header('Content-Type: application/json');
require_once __DIR__ . '/../config/response.php';
require_once __DIR__ . '/../config/db.php';
require_once __DIR__ . '/../auth/auth_required.php';
require_once __DIR__ . '/../auth/role_helper.php';
require_once __DIR__ . '/../config/audit.php';

require_once __DIR__ . '/helpers.php';
require_once __DIR__ . '/../invoices/document_number.php';
require_once __DIR__ . '/../invoices/workflow_domain.php';


try {
    if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
        jsonResponse(['success' => false, 'message' => 'Method not allowed'], 405);
    }

    $userId = (int)requireAuth()->id;
    $data = json_decode(file_get_contents('php://input'), true);
    $id = (int)($data['id'] ?? 0);
    $action = strtoupper(trim((string)($data['action'] ?? '')));
    $targets = ['CONFIRM' => 'CONFIRMED', 'CANCEL' => 'CANCELLED', 'DELIVER' => 'DELIVERED'];
    if ($id <= 0 || !isset($targets[$action])) throw new Exception('Invalid action');

    $conn = db();
    $actionPermission = ['CONFIRM' => 'deliveries.confirm', 'CANCEL' => 'deliveries.cancel', 'DELIVER' => 'deliveries.deliver'][$action];
    requirePermission($conn, $userId, $actionPermission);
    ensureDeliverySchema($conn);

    $conn->begin_transaction();
    $infoStmt = $conn->prepare("SELECT id, delivery_number, document_type, delivery_date, status, sales_order_id, stock_applied FROM erp_delivery_notes WHERE id = ? AND user_id = ? LIMIT 1 FOR UPDATE");
    $infoStmt->bind_param('ii', $id, $userId);
    $infoStmt->execute();
    $delivery = $infoStmt->get_result()->fetch_assoc();
    $infoStmt->close();
    if (!$delivery) throw new Exception('Delivery note not found or unauthorized');

    $deliveryNumber=(string)$delivery['delivery_number'];
    if ($action === 'DELIVER') {
        if ((string)$delivery['status'] !== 'CONFIRMED') {
            throw new Exception('Only a confirmed delivery note can be marked as delivered');
        }
        if ((int)$delivery['stock_applied'] !== 1) {
            applyDeliveryStockMovement($conn, $id, $userId);
        }
        $stmt = $conn->prepare("UPDATE erp_delivery_notes SET status = 'DELIVERED' WHERE id = ? AND user_id = ?");
        $stmt->bind_param('ii', $id, $userId);
        $stmt->execute();
        $stmt->close();
    } else {
        if ((string)$delivery['status'] !== 'DRAFT') {
            throw new Exception('Only a draft delivery note can be confirmed or cancelled');
        }
        $target = $targets[$action];
        if ($action === 'CONFIRM') {
            $sequenceType = strtoupper((string)$delivery['document_type']) === 'EXIT' ? 'BON_SORTIE' : 'BON_LIVRAISON';
            $deliveryNumber = nextDocumentNumber($conn, $userId, $sequenceType, (string)$delivery['delivery_date']);
        }
        $stmt = $conn->prepare("UPDATE erp_delivery_notes SET status = ?, delivery_number = ? WHERE id = ? AND user_id = ?");
        $stmt->bind_param('ssii', $target, $deliveryNumber, $id, $userId);
        $stmt->execute();
        $stmt->close();
    }

    recalculateSalesOrderDeliveryStatus($conn, (int)($delivery['sales_order_id'] ?? 0), $userId);
    auditLog($conn,$userId,$userId,'DELIVERY.'.$targets[$action],'DELIVERY_NOTE',$id,
        ['status'=>$delivery['status'],'delivery_number'=>$delivery['delivery_number'],
         'stock_applied'=>(bool)$delivery['stock_applied']],
        ['status'=>$targets[$action],'delivery_number'=>$deliveryNumber,
         'stock_applied'=>$action==='DELIVER' ? true : (bool)$delivery['stock_applied']]);
    $conn->commit();
    jsonResponse(['success' => true, 'id' => $id, 'status' => $targets[$action], 'delivery_number' => $deliveryNumber]);
} catch (Throwable $e) {
    if (isset($conn)) {
        try {
            $conn->rollback();
        } catch (Throwable $ignored) {
        }
    }
    jsonResponse(['success' => false, 'message' => $e->getMessage()], 400);
}
