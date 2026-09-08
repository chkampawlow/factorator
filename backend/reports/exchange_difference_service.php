<?php

declare(strict_types=1);

function validateExchangeDifferencePeriod(string $from, string $to): void
{
    if (!preg_match('/^\d{4}-\d{2}-\d{2}$/', $from) || !preg_match('/^\d{4}-\d{2}-\d{2}$/', $to) || $to < $from) {
        throw new InvalidArgumentException('Invalid exchange-difference period.');
    }
}

function exchangeDifferenceQuery(mysqli $conn, string $sql, string $types, array $args): array
{
    $stmt = $conn->prepare($sql);
    $stmt->bind_param($types, ...$args);
    $stmt->execute();
    $rows = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);
    $stmt->close();
    return $rows;
}

function exchangeDifferenceMoney(float $value): string
{
    return number_format(round($value, 3), 3, '.', '');
}

function exchangeDifferenceRate(float $value): string
{
    return number_format(round($value, 8), 8, '.', '');
}

function exchangeDifferenceFactsSql(): string
{
    return "SELECT 'CUSTOMER' direction,p.id payment_id,i.id document_id,i.invoice document_number,
        p.payment_date,COALESCE(NULLIF(c.name,''),'Client non lié') party,i.currency,p.amount amount_foreign,
        i.exchange_rate invoice_rate,p.exchange_rate settlement_rate,p.exchange_rate_date,
        ROUND(p.amount*i.exchange_rate,3) carrying_tnd,p.amount_tnd settlement_tnd,
        CASE WHEN p.exchange_rate IS NULL OR p.amount_tnd IS NULL THEN NULL ELSE ROUND(p.amount_tnd-p.amount*i.exchange_rate,3) END exchange_difference_tnd,
        (p.exchange_rate IS NULL OR p.amount_tnd IS NULL) rate_missing
      FROM erp_invoice_payments p
      JOIN erp_invoices i ON i.id=p.invoice_id AND i.user_id=p.user_id
      LEFT JOIN clients c ON c.id=CAST(i.custom_code AS UNSIGNED) AND c.user_id=i.user_id
      WHERE p.user_id=? AND p.payment_date BETWEEN ? AND ? AND p.status='POSTED' AND i.currency<>'TND'
      UNION ALL
      SELECT 'SUPPLIER',p.id,si.id,si.invoice_number,p.payment_date,COALESCE(NULLIF(s.name,''),'Fournisseur non lié'),
        si.currency,p.amount,si.exchange_rate,p.exchange_rate,p.exchange_rate_date,
        ROUND(p.amount*si.exchange_rate,3),p.amount_tnd,
        CASE WHEN p.exchange_rate IS NULL OR p.amount_tnd IS NULL THEN NULL ELSE ROUND(p.amount*si.exchange_rate-p.amount_tnd,3) END,
        (p.exchange_rate IS NULL OR p.amount_tnd IS NULL)
      FROM erp_supplier_payments p
      JOIN erp_supplier_invoices si ON si.id=p.supplier_invoice_id AND si.user_id=p.user_id
      LEFT JOIN suppliers s ON s.id=si.supplier_id AND s.user_id=si.user_id
      WHERE p.user_id=? AND p.payment_date BETWEEN ? AND ? AND p.voided_at IS NULL AND si.currency<>'TND'";
}

function normalizeExchangeSummary(array $row): array
{
    foreach (['payments','documents','missing_rate_payments'] as $key) $row[$key] = (int)($row[$key] ?? 0);
    foreach (['carrying_tnd','settlement_tnd','realized_gains_tnd','realized_losses_tnd','net_exchange_difference_tnd'] as $key) {
        $row[$key] = exchangeDifferenceMoney((float)($row[$key] ?? 0));
    }
    return $row;
}

function normalizeExchangeDetail(array $row): array
{
    foreach (['payment_id','document_id'] as $key) $row[$key] = (int)$row[$key];
    $row['rate_missing'] = (bool)$row['rate_missing'];
    $row['amount_foreign'] = exchangeDifferenceMoney((float)$row['amount_foreign']);
    $row['invoice_rate'] = exchangeDifferenceRate((float)$row['invoice_rate']);
    $row['settlement_rate'] = $row['settlement_rate'] === null ? null : exchangeDifferenceRate((float)$row['settlement_rate']);
    foreach (['carrying_tnd','settlement_tnd','exchange_difference_tnd'] as $key) {
        $row[$key] = $row[$key] === null ? null : exchangeDifferenceMoney((float)$row[$key]);
    }
    if (array_key_exists('total_rows', $row)) $row['total_rows'] = (int)$row['total_rows'];
    return $row;
}

function exchangeOpenExposureSql(): string
{
    return "SELECT direction,currency,COUNT(*) documents,ROUND(SUM(remaining_foreign),3) amount_foreign,
        ROUND(SUM(remaining_foreign*invoice_rate),3) carrying_tnd FROM(
        SELECT 'CUSTOMER' direction,i.currency,i.exchange_rate invoice_rate,
          i.total-COALESCE(p.paid,0)-COALESCE(w.withheld,0)-COALESCE(cr.credited,0) remaining_foreign
        FROM erp_invoices i
        LEFT JOIN(SELECT invoice_id,SUM(amount) paid FROM erp_invoice_payments WHERE user_id=? AND status='POSTED' AND payment_date<=? GROUP BY invoice_id)p ON p.invoice_id=i.id
        LEFT JOIN(SELECT invoice_id,SUM(withheld_amount) withheld FROM erp_invoice_withholdings WHERE user_id=? AND certificate_status IN('RECEIVED','VALIDATED') AND COALESCE(certificate_date,DATE(created_at))<=? GROUP BY invoice_id)w ON w.invoice_id=i.id
        LEFT JOIN(SELECT source_invoice_id,SUM(ABS(total)) credited FROM erp_invoices WHERE user_id=? AND invoice_type='AVOIR' AND is_validated=1 AND invoice_date<=? GROUP BY source_invoice_id)cr ON cr.source_invoice_id=i.id
        WHERE i.user_id=? AND i.invoice_type='FACTURE' AND i.is_validated=1 AND i.currency<>'TND' AND i.invoice_date<=?
        UNION ALL
        SELECT 'SUPPLIER',si.currency,si.exchange_rate,
          si.total_ttc-si.credited_amount-COALESCE(p.paid,0)
        FROM erp_supplier_invoices si
        LEFT JOIN(SELECT supplier_invoice_id,SUM(amount) paid FROM erp_supplier_payments WHERE user_id=? AND voided_at IS NULL AND payment_date<=? GROUP BY supplier_invoice_id)p ON p.supplier_invoice_id=si.id
        WHERE si.user_id=? AND si.currency<>'TND' AND si.invoice_date<=? AND si.status IN('VALIDATED','PARTIALLY_PAID','PAID')
      ) exposure WHERE remaining_foreign>0.0005 GROUP BY direction,currency ORDER BY currency,direction";
}

function buildTenantExchangeDifferenceReport(mysqli $conn, int $userId, string $from, string $to, int $limit = 100): array
{
    if ($userId <= 0) throw new InvalidArgumentException('Invalid exchange-difference tenant.');
    validateExchangeDifferencePeriod($from, $to);
    $limit = min(200, max(1, $limit));
    $facts = exchangeDifferenceFactsSql();
    $factArgs = [$userId,$from,$to,$userId,$from,$to];
    $projection = "COUNT(*) payments,COUNT(DISTINCT CONCAT(direction,':',document_id)) documents,
      ROUND(COALESCE(SUM(CASE WHEN rate_missing=0 THEN carrying_tnd ELSE 0 END),0),3) carrying_tnd,
      ROUND(COALESCE(SUM(CASE WHEN rate_missing=0 THEN settlement_tnd ELSE 0 END),0),3) settlement_tnd,
      ROUND(COALESCE(SUM(CASE WHEN exchange_difference_tnd>0 THEN exchange_difference_tnd ELSE 0 END),0),3) realized_gains_tnd,
      ROUND(COALESCE(SUM(CASE WHEN exchange_difference_tnd<0 THEN ABS(exchange_difference_tnd) ELSE 0 END),0),3) realized_losses_tnd,
      ROUND(COALESCE(SUM(exchange_difference_tnd),0),3) net_exchange_difference_tnd,
      SUM(rate_missing) missing_rate_payments";
    $summary = normalizeExchangeSummary(exchangeDifferenceQuery($conn,"SELECT $projection FROM($facts) facts",'ississ',$factArgs)[0] ?? []);
    $currencyRows = exchangeDifferenceQuery($conn,"SELECT direction,currency,$projection FROM($facts) facts GROUP BY direction,currency ORDER BY currency,direction",'ississ',$factArgs);
    $byCurrency = array_map('normalizeExchangeSummary',$currencyRows);
    $details = exchangeDifferenceQuery($conn,"SELECT facts.*,COUNT(*) OVER() total_rows FROM($facts) facts ORDER BY rate_missing DESC,ABS(COALESCE(exchange_difference_tnd,0)) DESC,payment_date DESC,payment_id DESC LIMIT ?",'ississi',[...$factArgs,$limit]);
    $details = array_map('normalizeExchangeDetail',$details);
    $exposureArgs = [$userId,$to,$userId,$to,$userId,$to,$userId,$to,$userId,$to,$userId,$to];
    $exposure = exchangeDifferenceQuery($conn,exchangeOpenExposureSql(),'isisisisisis',$exposureArgs);
    foreach ($exposure as &$row) {
        $row['documents']=(int)$row['documents'];
        $row['amount_foreign']=exchangeDifferenceMoney((float)$row['amount_foreign']);
        $row['carrying_tnd']=exchangeDifferenceMoney((float)$row['carrying_tnd']);
    }
    unset($row);
    return [
        'period'=>['from'=>$from,'to'=>$to],
        'accounting_basis'=>'REALIZED_ON_SETTLEMENT',
        'summary'=>$summary,
        'by_currency'=>$byCurrency,
        'details'=>$details,
        'detail_count'=>(int)($details[0]['total_rows']??0),
        'row_limit'=>$limit,
        'open_exposure'=>$exposure,
        'rate_data_complete'=>$summary['missing_rate_payments']===0,
    ];
}
