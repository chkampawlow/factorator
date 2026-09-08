<?php

header('Content-Type: application/json');
require_once __DIR__ . '/../config/response.php';
require_once __DIR__ . '/../config/db.php';
require_once __DIR__ . '/../config/audit.php';
require_once __DIR__ . '/../auth/auth_required.php';
require_once __DIR__ . '/../auth/role_helper.php';

try {
    if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'POST') jsonResponse(['success'=>false,'message'=>'Method not allowed'],405);
    $userId=(int)requireAuth()->id;$data=json_decode(file_get_contents('php://input'),true)?:[];$invoiceId=(int)($data['id']??0);
    if($invoiceId<=0)jsonResponse(['success'=>false,'message'=>'A supplier invoice id is required.'],422);
    $conn=db();requirePermission($conn,$userId,'supplierInvoices.validate');$conn->begin_transaction();
    $stmt=$conn->prepare("SELECT status,(SELECT COUNT(*) FROM erp_supplier_invoice_items WHERE supplier_invoice_id=erp_supplier_invoices.id) line_count FROM erp_supplier_invoices WHERE id=? AND user_id=? FOR UPDATE");
    $stmt->bind_param('ii',$invoiceId,$userId);$stmt->execute();$invoice=$stmt->get_result()->fetch_assoc();$stmt->close();
    if(!$invoice)throw new Exception('Supplier invoice not found or unauthorized');
    if((string)$invoice['status']!=='DRAFT')throw new Exception('Only a draft supplier invoice can be validated');
    if((int)$invoice['line_count']<=0)throw new Exception('A supplier invoice needs at least one line');
    $stmt=$conn->prepare("UPDATE erp_supplier_invoices SET status='VALIDATED',validated_at=NOW() WHERE id=? AND user_id=? AND status='DRAFT'");$stmt->bind_param('ii',$invoiceId,$userId);$stmt->execute();$stmt->close();
    auditLog($conn,$userId,$userId,'SUPPLIER_INVOICE.VALIDATED','SUPPLIER_INVOICE',$invoiceId,['status'=>'DRAFT'],['status'=>'VALIDATED']);
    $conn->commit();jsonResponse(['success'=>true,'id'=>$invoiceId,'status'=>'VALIDATED']);
}catch(Throwable $error){if(isset($conn))try{$conn->rollback();}catch(Throwable $ignored){}jsonResponse(['success'=>false,'message'=>$error->getMessage()],400);}

