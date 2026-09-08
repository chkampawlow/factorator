<?php

function vatMonthDates(string $month):array{
    if(!preg_match('/^\d{4}-(0[1-9]|1[0-2])$/',$month))throw new InvalidArgumentException('Month must use YYYY-MM');
    $start=new DateTimeImmutable($month.'-01');return [$start->format('Y-m-d'),$start->modify('last day of this month')->format('Y-m-d')];
}
function vatPeriodSource(mysqli $conn,int $userId,string $start):?array{
    $stmt=$conn->prepare("SELECT id,period_end,closing_credit,status FROM erp_vat_periods
        WHERE user_id=? AND period_end<? AND status IN('REVIEWED','LOCKED','FILED') ORDER BY period_end DESC,id DESC LIMIT 1");
    $stmt->bind_param('is',$userId,$start);$stmt->execute();$row=$stmt->get_result()->fetch_assoc()?:null;$stmt->close();return $row;
}
function calculateVatPeriod(mysqli $conn,int $userId,string $start,string $end,float $manualOpening=0):array{
    $source=vatPeriodSource($conn,$userId,$start);$opening=$source?(float)$source['closing_credit']:round(max(0,$manualOpening),3);
    $stmt=$conn->prepare("SELECT ROUND(COALESCE(SUM(CASE WHEN i.invoice_type='AVOIR'
        THEN -ABS(ii.montant_tva*i.exchange_rate) ELSE ii.montant_tva*i.exchange_rate END),0),3) amount
        FROM erp_invoice_items ii JOIN erp_invoices i ON i.id=ii.invoice_id
        WHERE i.user_id=? AND i.invoice_date BETWEEN ? AND ? AND i.invoice_type IN('FACTURE','AVOIR') AND i.is_validated=1");
    $stmt->bind_param('iss',$userId,$start,$end);$stmt->execute();$collected=max(0,(float)$stmt->get_result()->fetch_assoc()['amount']);$stmt->close();
    $stmt=$conn->prepare("SELECT ROUND(COALESCE(SUM(sii.deductible_vat_tnd),0),3) amount
        FROM erp_supplier_invoice_items sii JOIN erp_supplier_invoices si ON si.id=sii.supplier_invoice_id
        WHERE si.user_id=? AND si.invoice_date BETWEEN ? AND ? AND si.status IN('VALIDATED','PARTIALLY_PAID','PAID')");
    $stmt->bind_param('iss',$userId,$start,$end);$stmt->execute();$deductible=max(0,(float)$stmt->get_result()->fetch_assoc()['amount']);$stmt->close();
    $available=round($opening+$deductible,3);$payable=round(max(0,$collected-$available),3);$closing=round(max(0,$available-$collected),3);
    return ['period_start'=>$start,'period_end'=>$end,'opening_credit'=>round($opening,3),'vat_collected'=>round($collected,3),
        'vat_deductible'=>round($deductible,3),'available_credit'=>$available,'vat_payable'=>$payable,'closing_credit'=>$closing,
        'source_period_id'=>$source?(int)$source['id']:null];
}
