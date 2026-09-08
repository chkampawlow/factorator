<?php

header('Content-Type: application/json');
require_once __DIR__ . '/../config/response.php';
require_once __DIR__ . '/../config/db.php';
require_once __DIR__ . '/../config/audit.php';
require_once __DIR__ . '/../auth/auth_required.php';
require_once __DIR__ . '/../auth/role_helper.php';
require_once __DIR__ . '/service.php';

try {
    if ($_SERVER['REQUEST_METHOD'] !== 'POST') jsonResponse(['success'=>false,'message'=>'Method not allowed'],405);
    $auth = requireAuth();
    $userId = authTenantId($auth);
    $actorId = authActorId($auth);
    $data = json_decode(file_get_contents('php://input'), true) ?: [];
    $paymentId = (int) ($data['id'] ?? 0);
    $reason = trim((string) ($data['reason'] ?? ''));
    if ($reason === '') throw new Exception('A void reason is required');

    $conn = db();
    requirePermission($conn, $userId, 'payments.void');
    $conn->begin_transaction();
    $stmt = $conn->prepare("SELECT invoice_id,amount,payment_date,method,reference_number
        FROM erp_invoice_payments WHERE id=? AND user_id=? AND status='POSTED' FOR UPDATE");
    $stmt->bind_param('ii', $paymentId, $userId);
    $stmt->execute();
    $payment = $stmt->get_result()->fetch_assoc();
    $stmt->close();
    if (!$payment) throw new Exception('Posted payment not found');

    $invoiceId = (int) $payment['invoice_id'];
    $before = settlementSummary($conn, $invoiceId, $userId);
    $stmt = $conn->prepare("UPDATE erp_invoice_payments SET status='VOID',voided_by=?,
        voided_at=NOW(),void_reason=? WHERE id=? AND user_id=?");
    $stmt->bind_param('isii', $actorId, $reason, $paymentId, $userId);
    $stmt->execute();
    $stmt->close();
    $summary = syncInvoiceSettlementState($conn, $invoiceId, $userId);
    auditLog($conn, $userId, $actorId, 'PAYMENT.VOIDED', 'INVOICE_PAYMENT', $paymentId,
        ['status'=>'POSTED','invoice_id'=>$invoiceId,'amount'=>$payment['amount'],'settlement'=>$before],
        ['status'=>'VOID','invoice_id'=>$invoiceId,'reason'=>$reason,'settlement'=>$summary]);
    $conn->commit();
    jsonResponse(['success'=>true,'summary'=>$summary]);
} catch (Throwable $e) {
    if (isset($conn)) { try { $conn->rollback(); } catch (Throwable $ignored) {} }
    jsonResponse(['success'=>false,'message'=>$e->getMessage()],400);
}
