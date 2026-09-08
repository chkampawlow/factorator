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
    $withholdingId = (int) ($data['id'] ?? 0);
    $status = strtoupper(trim((string) ($data['certificate_status'] ?? '')));
    $number = trim((string) ($data['certificate_number'] ?? ''));
    $date = trim((string) ($data['certificate_date'] ?? ''));
    $notes = trim((string) ($data['validation_notes'] ?? ''));
    if (!in_array($status,['PENDING','RECEIVED','VALIDATED','CANCELLED'],true)) throw new Exception('Invalid certificate status');
    if (in_array($status,['RECEIVED','VALIDATED'],true) && ($number==='' || !DateTimeImmutable::createFromFormat('!Y-m-d',$date))) throw new Exception('Certificate number and date are required');

    $conn = db();
    requirePermission($conn, $userId, 'withholding.edit');
    $conn->begin_transaction();
    $stmt = $conn->prepare('SELECT invoice_id,certificate_status,certificate_number,certificate_date,withheld_amount,expected_certificate_date,received_at,validated_at,cancelled_at,validation_notes FROM erp_invoice_withholdings WHERE id=? AND user_id=? FOR UPDATE');
    $stmt->bind_param('ii', $withholdingId, $userId);
    $stmt->execute();
    $before = $stmt->get_result()->fetch_assoc();
    $stmt->close();
    if (!$before) throw new Exception('Withholding record not found');
    $invoiceId = (int) $before['invoice_id'];
    $current=$before['certificate_status'];$allowed=['PENDING'=>['RECEIVED','CANCELLED'],'RECEIVED'=>['VALIDATED','CANCELLED'],'VALIDATED'=>['CANCELLED'],'CANCELLED'=>[]];
    if(!in_array($status,$allowed[$current]??[],true))throw new Exception('Invalid certificate status transition');

    $stmt = $conn->prepare("UPDATE erp_invoice_withholdings SET certificate_status=?,certificate_number=?,certificate_date=NULLIF(?,''),validation_notes=?,received_at=IF(?='RECEIVED',COALESCE(received_at,NOW()),received_at),validated_at=IF(?='VALIDATED',COALESCE(validated_at,NOW()),validated_at),cancelled_at=IF(?='CANCELLED',COALESCE(cancelled_at,NOW()),cancelled_at) WHERE id=? AND user_id=?");
    $stmt->bind_param('sssssssii', $status, $number, $date, $notes, $status, $status, $status, $withholdingId, $userId);
    $stmt->execute();
    $stmt->close();
    $summary = settlementSummary($conn, $invoiceId, $userId);
    if ((float)$summary['overpayment'] > 0.0005) throw new Exception('Withholding exceeds the outstanding balance');
    $summary = syncInvoiceSettlementState($conn, $invoiceId, $userId, $summary);
    auditLog($conn, $userId, $actorId, 'WITHHOLDING.STATUS_CHANGED', 'INVOICE_WITHHOLDING', $withholdingId,
        $before, ['invoice_id'=>$invoiceId,'certificate_status'=>$status,
        'certificate_number'=>$number,'certificate_date'=>$date ?: null,'validation_notes'=>$notes,'settlement'=>$summary]);
    $conn->commit();
    jsonResponse(['success'=>true,'summary'=>$summary]);
} catch (Throwable $e) {
    if (isset($conn)) { try { $conn->rollback(); } catch (Throwable $ignored) {} }
    jsonResponse(['success'=>false,'message'=>$e->getMessage()],400);
}
