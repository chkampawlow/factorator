<?php
function accountingPeriodAggregate(mysqli $c,int $uid,string $from,string $to):array{
    $query=function(string $sql,string $types,array $args)use($c):array{$s=$c->prepare($sql);$s->bind_param($types,...$args);$s->execute();$r=$s->get_result()->fetch_assoc()?:[];$s->close();return$r;};$p=[$uid,$from,$to];
    return[
        'period'=>['from'=>$from,'to'=>$to],
        'sales'=>$query("SELECT COUNT(*) documents,ROUND(COALESCE(SUM(CASE WHEN invoice_type='AVOIR' THEN -ABS(subtotal_tnd) ELSE subtotal_tnd END),0),3) net_ht_tnd,ROUND(COALESCE(SUM(CASE WHEN invoice_type='AVOIR' THEN -ABS(montant_tva*exchange_rate) ELSE montant_tva*exchange_rate END),0),3) vat_tnd,ROUND(COALESCE(SUM(CASE WHEN invoice_type='AVOIR' THEN -ABS(total_tnd) ELSE total_tnd END),0),3) total_tnd FROM erp_invoices WHERE user_id=? AND invoice_date BETWEEN ? AND ? AND invoice_type IN('FACTURE','AVOIR') AND is_validated=1",'iss',$p),
        'purchases'=>$query("SELECT COUNT(*) documents,ROUND(COALESCE(SUM(total_ht_tnd),0),3) ht_tnd,ROUND(COALESCE(SUM(total_tax_tnd),0),3) tax_tnd,ROUND(COALESCE(SUM(total_ttc_tnd),0),3) total_tnd FROM erp_supplier_invoices WHERE user_id=? AND invoice_date BETWEEN ? AND ? AND status IN('VALIDATED','PARTIALLY_PAID','PAID')",'iss',$p),
        'customer_payments'=>$query("SELECT COUNT(*) records,ROUND(COALESCE(SUM(COALESCE(p.amount_tnd,p.amount*i.exchange_rate)),0),3) amount FROM erp_invoice_payments p JOIN erp_invoices i ON i.id=p.invoice_id AND i.user_id=p.user_id WHERE p.user_id=? AND p.payment_date BETWEEN ? AND ? AND p.status='POSTED'",'iss',$p),
        'supplier_payments'=>$query("SELECT COUNT(*) records,ROUND(COALESCE(SUM(COALESCE(p.amount_tnd,p.amount*i.exchange_rate)),0),3) amount FROM erp_supplier_payments p JOIN erp_supplier_invoices i ON i.id=p.supplier_invoice_id AND i.user_id=p.user_id WHERE p.user_id=? AND p.payment_date BETWEEN ? AND ? AND p.voided_at IS NULL",'iss',$p),
        'expenses'=>$query("SELECT COUNT(*) records,ROUND(COALESCE(SUM(amount),0),3) amount FROM expense_notes WHERE user_id=? AND expense_date BETWEEN ? AND ? AND status IN('APPROVED','REIMBURSED')",'iss',$p),
        'stock'=>$query("SELECT COUNT(*) movements,ROUND(COALESCE(SUM(cogs_value),0),3) cogs FROM product_stock_movements WHERE user_id=? AND created_at>=? AND created_at<DATE_ADD(?,INTERVAL 1 DAY)",'iss',$p),
    ];
}
function captureAccountingPeriodSnapshot(mysqli $c,int $periodId,int $uid,string $from,string $to,string $status,int $actor):array{
    $payload=accountingPeriodAggregate($c,$uid,$from,$to);$payload['status']=$status;$json=json_encode($payload,JSON_UNESCAPED_SLASHES|JSON_UNESCAPED_UNICODE|JSON_PRESERVE_ZERO_FRACTION|JSON_THROW_ON_ERROR);$hash=hash('sha256',$json);
    $s=$c->prepare('SELECT COALESCE(MAX(version),0)+1 version FROM erp_accounting_period_snapshots WHERE period_id=? FOR UPDATE');$s->bind_param('i',$periodId);$s->execute();$version=(int)$s->get_result()->fetch_assoc()['version'];$s->close();
    $s=$c->prepare('INSERT INTO erp_accounting_period_snapshots(period_id,user_id,version,status,snapshot_json,snapshot_sha256,captured_by) VALUES(?,?,?,?,?,?,?)');$s->bind_param('iiisssi',$periodId,$uid,$version,$status,$json,$hash,$actor);$s->execute();$id=(int)$s->insert_id;$s->close();return['id'=>$id,'version'=>$version,'sha256'=>$hash,'data'=>$payload];
}
