<?php

declare(strict_types=1);

if (PHP_SAPI !== 'cli') exit(2);
require_once __DIR__ . '/../config/db.php';
require_once __DIR__ . '/../config/idempotency.php';
require_once __DIR__ . '/../invoice_settlements/service.php';

[$script, $invoiceArg, $userArg, $amountArg, $key, $barrier] = array_pad($argv, 6, '');
$invoiceId = (int)$invoiceArg; $userId = (int)$userArg; $amount = round((float)$amountArg, 3);
$deadline = microtime(true) + 10;
while (!is_file($barrier) && microtime(true) < $deadline) usleep(10000);
if (!is_file($barrier)) { fwrite(STDERR, "Barrier timeout\n"); exit(2); }

$conn = db();
$payload = ['invoice_id'=>$invoiceId,'amount'=>$amount,'payment_date'=>'2026-08-10','method'=>'CASH','account_name'=>'integration','reference_number'=>''];
$conn->begin_transaction();
try {
    $replayed = claimIdempotencyKey($conn, $userId, 'invoice.payment.add', $key, idempotencyRequestHash($payload));
    if ($replayed !== null) {
        $conn->commit(); echo json_encode(['success'=>true,'replayed'=>true,'id'=>$replayed]); exit(0);
    }
    requireSettlementInvoice($conn, $invoiceId, $userId, true);
    $before = settlementSummary($conn, $invoiceId, $userId);
    if ($amount > (float)$before['remaining_balance'] + 0.0005) throw new RuntimeException('Payment exceeds the outstanding balance');
    $stmt=$conn->prepare("INSERT INTO erp_invoice_payments(invoice_id,user_id,amount,payment_date,method,account_name,reference_number,recorded_by) VALUES(?,?,?,'2026-08-10','CASH','integration','',?)");
    $stmt->bind_param('iidi',$invoiceId,$userId,$amount,$userId);$stmt->execute();$paymentId=(int)$stmt->insert_id;$stmt->close();
    $summary=syncInvoiceSettlementState($conn,$invoiceId,$userId);
    completeIdempotencyKey($conn,$userId,'invoice.payment.add',$key,$paymentId);
    $conn->commit(); echo json_encode(['success'=>true,'replayed'=>false,'id'=>$paymentId,'summary'=>$summary]); exit(0);
} catch (Throwable $e) {
    try{$conn->rollback();}catch(Throwable){}
    echo json_encode(['success'=>false,'message'=>$e->getMessage()]); exit(1);
}
