<?php

require_once __DIR__ . '/../config/upload.php';

function requireSettlementInvoice(mysqli $conn, int $invoiceId, int $userId, bool $forUpdate = false): array
{
    $sql = "SELECT id,invoice,total,total_tnd,currency,exchange_rate invoice_exchange_rate,invoice_due_date,invoice_type,status,IFNULL(is_validated,0) is_validated FROM erp_invoices WHERE id=? AND user_id=? LIMIT 1" . ($forUpdate ? ' FOR UPDATE' : '');
    $stmt=$conn->prepare($sql); $stmt->bind_param('ii',$invoiceId,$userId); $stmt->execute(); $row=$stmt->get_result()->fetch_assoc(); $stmt->close();
    if(!$row) throw new Exception('Invoice not found or unauthorized');
    if(strtoupper((string)$row['invoice_type'])!=='FACTURE' || (int)$row['is_validated']!==1) throw new Exception('Payments and withholding require a validated invoice');
    return $row;
}

function settlementExchangeValues(array $invoice, float $amount, string $rateInput, string $paymentDate): array
{
    $currency = strtoupper((string)($invoice['currency'] ?? 'TND'));
    $rateInput = trim($rateInput);
    if ($currency === 'TND') {
        if ($rateInput !== '' && (!is_numeric($rateInput) || abs((float)$rateInput - 1.0) > 0.00000001)) {
            throw new Exception('TND payments must use an exchange rate of 1');
        }
        $rate = 1.0;
    } else {
        if ($rateInput === '' || !is_numeric($rateInput) || (float)$rateInput <= 0) {
            throw new Exception('A positive settlement exchange rate is required for foreign-currency payments');
        }
        $rate = round((float)$rateInput, 8);
    }
    return [
        'currency' => $currency,
        'exchange_rate' => $rate,
        'exchange_rate_date' => $paymentDate,
        'amount_tnd' => round($amount * $rate, 3),
    ];
}

function settlementSummary(mysqli $conn, int $invoiceId, int $userId): array
{
    $invoice=requireSettlementInvoice($conn,$invoiceId,$userId);
    $stmt=$conn->prepare("SELECT COALESCE(SUM(amount),0) total FROM erp_invoice_payments WHERE invoice_id=? AND user_id=? AND status='POSTED'");
    $stmt->bind_param('ii',$invoiceId,$userId); $stmt->execute(); $payments=(float)$stmt->get_result()->fetch_assoc()['total']; $stmt->close();
    $stmt=$conn->prepare("SELECT COALESCE(SUM(withheld_amount),0) total FROM erp_invoice_withholdings WHERE invoice_id=? AND user_id=? AND certificate_status IN('RECEIVED','VALIDATED')");
    $stmt->bind_param('ii',$invoiceId,$userId); $stmt->execute(); $withholding=(float)$stmt->get_result()->fetch_assoc()['total']; $stmt->close();
    $stmt=$conn->prepare("SELECT COALESCE(SUM(ABS(total)),0) total FROM erp_invoices WHERE source_invoice_id=? AND user_id=? AND invoice_type='AVOIR' AND IFNULL(is_validated,0)=1");
    $stmt->bind_param('ii',$invoiceId,$userId); $stmt->execute(); $credits=(float)$stmt->get_result()->fetch_assoc()['total']; $stmt->close();
    $gross=(float)$invoice['total']; $net=round($gross-$withholding-$credits,3); $remaining=round($net-$payments,3);
    $hasSettlementActivity=$payments>0.0005 || $withholding>0.0005 || $credits>0.0005;
    $derived=$remaining<=0.0005?'PAID':($hasSettlementActivity?'PARTIALLY_PAID':((string)$invoice['invoice_due_date']<date('Y-m-d')?'OVERDUE':'UNPAID'));
    return ['gross_total'=>$gross,'payment_total'=>round($payments,3),'credit_total'=>$credits,'withholding_total'=>round($withholding,3),'net_payable'=>$net,'remaining_balance'=>$remaining,'overpayment'=>round(max(0,-$remaining),3),'derived_status'=>$derived];
}

function syncInvoiceSettlementState(mysqli $conn, int $invoiceId, int $userId, ?array $summary = null): array
{
    $summary ??= settlementSummary($conn, $invoiceId, $userId);
    $status = (string)$summary['derived_status'];
    $withholding = (float)$summary['withholding_total'];
    $net = (float)$summary['net_payable'];
    $stmt = $conn->prepare('UPDATE erp_invoices SET status=?, retenue=?, net_retenue=? WHERE id=? AND user_id=?');
    $stmt->bind_param('sddii', $status, $withholding, $net, $invoiceId, $userId);
    $stmt->execute();
    if ($stmt->affected_rows < 0) throw new Exception('Unable to synchronize invoice settlement status');
    $stmt->close();
    return $summary;
}

function storeSettlementUpload(string $field, int $userId): array
{
    if(!isset($_FILES[$field]) || (int)$_FILES[$field]['error']===UPLOAD_ERR_NO_FILE) return [null,null,null];
    $upload=validatedUpload($_FILES[$field],[
        'application/pdf'=>['pdf'], 'image/jpeg'=>['jpg','jpeg'],
        'image/png'=>['png'], 'image/webp'=>['webp'],
    ],10*1024*1024);
    $dir=ensurePrivateDirectory('accounting/'.$userId); $path=$dir.'/'.$upload['stored_name'];
    if(!move_uploaded_file($upload['tmp_name'],$path)) throw new Exception('Could not store attachment');
    chmod($path,0660);
    return [$path,$upload['display_name'],$upload['mime']];
}
