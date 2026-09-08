<?php
header('Content-Type: application/json');
require_once __DIR__ . '/../config/response.php'; require_once __DIR__ . '/../config/db.php';
require_once __DIR__ . '/../auth/auth_required.php'; require_once __DIR__ . '/../auth/role_helper.php';
require_once __DIR__ . '/../config/audit.php';
require_once __DIR__ . '/../invoices/document_number.php';
require_once __DIR__ . '/../invoices/workflow_domain.php';
try {
    if ($_SERVER['REQUEST_METHOD'] !== 'POST') jsonResponse(['success'=>false,'message'=>'Method not allowed'],405);
    $userId=(int)requireAuth()->id; $conn = db(); $data=json_decode(file_get_contents('php://input'),true);
    $id=(int)($data['id']??0); $action=strtoupper(trim((string)($data['action']??'')));
    $targets=['CONFIRM'=>'CONFIRMED','CANCEL'=>'CANCELLED'];
    if ($id<=0 || !isset($targets[$action])) throw new Exception('Invalid action');
    requirePermission($conn, $userId, $action === 'CONFIRM' ? 'orders.confirm' : 'orders.cancel');
    $target=$targets[$action];
    $conn->begin_transaction();
    $lock=$conn->prepare("SELECT order_number, order_date, status FROM erp_sales_orders WHERE id=? AND user_id=? FOR UPDATE");
    $lock->bind_param('ii',$id,$userId); $lock->execute(); $order=$lock->get_result()->fetch_assoc(); $lock->close();
    if (!$order || (string)$order['status'] !== 'DRAFT') throw new Exception('Only a draft order can be confirmed or cancelled');
    $number=(string)$order['order_number'];
    if ($action === 'CONFIRM') {
        $number=nextDocumentNumber($conn,$userId,'BON_COMMANDE',(string)$order['order_date']);
    }
    $stmt=$conn->prepare("UPDATE erp_sales_orders SET status=?, order_number=? WHERE id=? AND user_id=? AND status='DRAFT'");
    $stmt->bind_param('ssii',$target,$number,$id,$userId); $stmt->execute(); $affected=$stmt->affected_rows; $stmt->close();
    if ($affected!==1) throw new Exception('Only a draft order can be confirmed or cancelled');
    auditLog($conn,$userId,$userId,'SALES_ORDER.'.$target,'SALES_ORDER',$id,
        ['status'=>$order['status'],'order_number'=>$order['order_number']],
        ['status'=>$target,'order_number'=>$number]);
    $conn->commit();
    jsonResponse(['success'=>true,'id'=>$id,'status'=>$target,'order_number'=>$number]);
} catch(Throwable $e) { if(isset($conn)){try{$conn->rollback();}catch(Throwable $ignored){}} jsonResponse(['success'=>false,'message'=>$e->getMessage()],400); }
