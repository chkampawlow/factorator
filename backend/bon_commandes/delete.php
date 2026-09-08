<?php
header('Content-Type: application/json');
require_once __DIR__ . '/../config/response.php'; require_once __DIR__ . '/../config/db.php';
require_once __DIR__ . '/../auth/auth_required.php'; require_once __DIR__ . '/../auth/role_helper.php';
require_once __DIR__ . '/../invoices/workflow_schema.php';
try {
    if ($_SERVER['REQUEST_METHOD'] !== 'POST') jsonResponse(['success'=>false,'message'=>'Method not allowed'],405);
    $userId=(int)requireAuth()->id; $data=json_decode(file_get_contents('php://input'),true); $id=(int)($data['id']??0);
    if ($id<=0) throw new Exception('Invalid order id');
    $conn = db();
    requirePermission($conn, $userId, 'orders.delete');
    ensureInvoiceWorkflowSchema($conn);
    $conn->begin_transaction();
    $sourceStmt = $conn->prepare("SELECT IFNULL(source_devis_id, 0) AS source_devis_id FROM erp_sales_orders WHERE id=? AND user_id=? AND status='DRAFT' LIMIT 1");
    $sourceStmt->bind_param('ii',$id,$userId);
    $sourceStmt->execute();
    $row = $sourceStmt->get_result()->fetch_assoc();
    $sourceStmt->close();
    $sourceDevisId = (int)($row['source_devis_id'] ?? 0);
    $stmt=$conn->prepare("DELETE FROM erp_sales_orders WHERE id=? AND user_id=? AND status='DRAFT'");
    $stmt->bind_param('ii',$id,$userId); $stmt->execute(); $affected=$stmt->affected_rows; $stmt->close();
    if ($affected!==1) throw new Exception('Only a draft order can be deleted');
    if ($sourceDevisId > 0) {
        recalculateDevisTransformationStatus($conn, $sourceDevisId, $userId);
    }
    $conn->commit();
    jsonResponse(['success'=>true,'id'=>$id]);
} catch(Throwable $e) {
    if (isset($conn)) {
        try { $conn->rollback(); } catch (Throwable $ignored) {}
    }
    jsonResponse(['success'=>false,'message'=>$e->getMessage()],400);
}
