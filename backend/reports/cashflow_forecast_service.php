<?php

declare(strict_types=1);

function cashflowForecastToday(): DateTimeImmutable
{
    return new DateTimeImmutable('today', new DateTimeZone('Africa/Tunis'));
}

function validateCashflowForecastPeriod(string $from, string $to, ?DateTimeImmutable $today = null): void
{
    if (!preg_match('/^\d{4}-\d{2}-\d{2}$/', $from) || !preg_match('/^\d{4}-\d{2}-\d{2}$/', $to) || $to < $from) {
        throw new InvalidArgumentException('Invalid cash-flow forecast period.');
    }
    $today ??= cashflowForecastToday();
    $start = new DateTimeImmutable($from, $today->getTimezone());
    $end = new DateTimeImmutable($to, $today->getTimezone());
    if ($start < $today) throw new InvalidArgumentException('Cash-flow forecast must start today or later.');
    if ((int)$start->diff($end)->format('%a') > 365) throw new InvalidArgumentException('Cash-flow forecast cannot exceed 366 days.');
}

function cashflowForecastQuery(mysqli $conn, string $sql, string $types, array $args): array
{
    $stmt=$conn->prepare($sql);$stmt->bind_param($types,...$args);$stmt->execute();$rows=$stmt->get_result()->fetch_all(MYSQLI_ASSOC);$stmt->close();return $rows;
}

function cashflowAmount(float $amount): string
{
    return number_format(round($amount,3),3,'.','');
}

function summarizeCashflowForecast(array $collectionDays, array $paymentDays, array $events, string $from, string $to, bool $truncated): array
{
    $days=[];$collections=0.0;$payments=0.0;$overdueCollections=0.0;$overduePayments=0.0;
    foreach($collectionDays as $row){$date=(string)$row['forecast_date'];$amount=(float)$row['amount_tnd'];$overdue=(float)$row['overdue_tnd'];$days[$date]['collections']=($days[$date]['collections']??0)+$amount;$collections+=$amount;$overdueCollections+=$overdue;}
    foreach($paymentDays as $row){$date=(string)$row['forecast_date'];$amount=(float)$row['amount_tnd'];$overdue=(float)$row['overdue_tnd'];$days[$date]['payments']=($days[$date]['payments']??0)+$amount;$payments+=$amount;$overduePayments+=$overdue;}
    ksort($days);$daily=[];$cumulative=0.0;
    foreach($days as $date=>$amounts){$in=round((float)($amounts['collections']??0),3);$out=round((float)($amounts['payments']??0),3);$net=round($in-$out,3);$cumulative=round($cumulative+$net,3);$daily[]=['date'=>$date,'collections'=>cashflowAmount($in),'payments'=>cashflowAmount($out),'net'=>cashflowAmount($net),'cumulative_net'=>cashflowAmount($cumulative)];}
    usort($events,static fn(array $a,array $b):int=>[$a['forecast_date'],$a['direction'],$a['document_number'],$a['source_id']]<=>[$b['forecast_date'],$b['direction'],$b['document_number'],$b['source_id']]);
    return ['period'=>['from'=>$from,'to'=>$to],'summary'=>[
        'expected_collections'=>cashflowAmount($collections),'expected_payments'=>cashflowAmount($payments),'net_cashflow'=>cashflowAmount($collections-$payments),
        'overdue_collections'=>cashflowAmount($overdueCollections),'overdue_payments'=>cashflowAmount($overduePayments),
    ],'daily'=>$daily,'events'=>array_slice($events,0,500),'event_limit'=>500,'truncated'=>$truncated||count($events)>500];
}

function buildTenantCashflowForecast(mysqli $conn,int $userId,string $from,string $to,?DateTimeImmutable $today=null):array
{
    if($userId<=0)throw new InvalidArgumentException('Invalid forecast tenant.');$today??=cashflowForecastToday();validateCashflowForecastPeriod($from,$to,$today);$asOf=$today->format('Y-m-d');
    $customerBase="SELECT i.id source_id,i.invoice document_number,i.invoice_due_date due_date,COALESCE(c.name,'Client') party,
        ROUND(i.total_tnd-(COALESCE(p.paid,0)+COALESCE(w.withheld,0))*i.exchange_rate-COALESCE(cr.credited,0),3) balance_tnd
        FROM erp_invoices i LEFT JOIN clients c ON c.id=CAST(i.custom_code AS UNSIGNED) AND c.user_id=i.user_id
        LEFT JOIN(SELECT invoice_id,SUM(amount) paid FROM erp_invoice_payments WHERE user_id=? AND status='POSTED' AND payment_date<=? GROUP BY invoice_id)p ON p.invoice_id=i.id
        LEFT JOIN(SELECT invoice_id,SUM(withheld_amount) withheld FROM erp_invoice_withholdings WHERE user_id=? AND certificate_status IN('RECEIVED','VALIDATED') AND certificate_date<=? GROUP BY invoice_id)w ON w.invoice_id=i.id
        LEFT JOIN(SELECT source_invoice_id,SUM(ABS(total_tnd)) credited FROM erp_invoices WHERE user_id=? AND invoice_type='AVOIR' AND is_validated=1 AND invoice_date<=? GROUP BY source_invoice_id)cr ON cr.source_invoice_id=i.id
        WHERE i.user_id=? AND i.invoice_type='FACTURE' AND i.is_validated=1 AND i.invoice_date<=? AND i.invoice_due_date<=?";
    $customerArgs=[$userId,$asOf,$userId,$asOf,$userId,$asOf,$userId,$asOf,$to];$customerTypes='isisisiss';
    $collectionDays=cashflowForecastQuery($conn,"SELECT GREATEST(due_date,?) forecast_date,ROUND(SUM(balance_tnd),3) amount_tnd,ROUND(SUM(CASE WHEN due_date<? THEN balance_tnd ELSE 0 END),3) overdue_tnd FROM($customerBase) open_items WHERE balance_tnd>0 GROUP BY forecast_date ORDER BY forecast_date",'ss'.$customerTypes,[$from,$from,...$customerArgs]);
    $collectionEvents=cashflowForecastQuery($conn,"SELECT 'COLLECTION' direction,source_id,document_number,party,due_date,GREATEST(due_date,?) forecast_date,balance_tnd amount_tnd,CASE WHEN due_date<? THEN 'OVERDUE' ELSE 'UPCOMING' END timing FROM($customerBase) open_items WHERE balance_tnd>0 ORDER BY forecast_date,due_date,source_id LIMIT ?",'ss'.$customerTypes.'i',[$from,$from,...$customerArgs,501]);

    $supplierBase="SELECT si.id source_id,si.invoice_number document_number,si.due_date,COALESCE(s.name,'Fournisseur') party,
        ROUND(si.total_ttc_tnd-(si.credited_amount+COALESCE(p.paid,0))*si.exchange_rate,3) balance_tnd
        FROM erp_supplier_invoices si JOIN suppliers s ON s.id=si.supplier_id AND s.user_id=si.user_id
        LEFT JOIN(SELECT supplier_invoice_id,SUM(amount) paid FROM erp_supplier_payments WHERE user_id=? AND voided_at IS NULL AND payment_date<=? GROUP BY supplier_invoice_id)p ON p.supplier_invoice_id=si.id
        WHERE si.user_id=? AND si.invoice_date<=? AND si.due_date<=? AND si.status IN('VALIDATED','PARTIALLY_PAID','PAID')";
    $supplierArgs=[$userId,$asOf,$userId,$asOf,$to];$supplierTypes='isiss';
    $paymentDays=cashflowForecastQuery($conn,"SELECT GREATEST(due_date,?) forecast_date,ROUND(SUM(balance_tnd),3) amount_tnd,ROUND(SUM(CASE WHEN due_date<? THEN balance_tnd ELSE 0 END),3) overdue_tnd FROM($supplierBase) open_items WHERE balance_tnd>0 GROUP BY forecast_date ORDER BY forecast_date",'ss'.$supplierTypes,[$from,$from,...$supplierArgs]);
    $paymentEvents=cashflowForecastQuery($conn,"SELECT 'PAYMENT' direction,source_id,document_number,party,due_date,GREATEST(due_date,?) forecast_date,balance_tnd amount_tnd,CASE WHEN due_date<? THEN 'OVERDUE' ELSE 'UPCOMING' END timing FROM($supplierBase) open_items WHERE balance_tnd>0 ORDER BY forecast_date,due_date,source_id LIMIT ?",'ss'.$supplierTypes.'i',[$from,$from,...$supplierArgs,501]);

    foreach($collectionEvents as &$event){$event['source_id']=(int)$event['source_id'];$event['amount_tnd']=cashflowAmount((float)$event['amount_tnd']);}unset($event);
    foreach($paymentEvents as &$event){$event['source_id']=(int)$event['source_id'];$event['amount_tnd']=cashflowAmount((float)$event['amount_tnd']);}unset($event);
    return ['as_of'=>$asOf]+summarizeCashflowForecast($collectionDays,$paymentDays,[...$collectionEvents,...$paymentEvents],$from,$to,count($collectionEvents)>500||count($paymentEvents)>500);
}
