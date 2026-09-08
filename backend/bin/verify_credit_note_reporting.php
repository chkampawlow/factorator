<?php

if(PHP_SAPI!=='cli'){http_response_code(404);exit;}
require_once __DIR__.'/../config/db.php';
$conn=db();$tenantId=(int)($argv[1]??32);$from=(string)($argv[2]??'2000-01-01');$to=(string)($argv[3]??'2099-12-31');
$stmt=$conn->prepare("SELECT
    ROUND(COALESCE(SUM(CASE WHEN invoice_type='FACTURE' THEN subtotal_tnd ELSE 0 END),0),3) gross_revenue,
    ROUND(COALESCE(SUM(CASE WHEN invoice_type='AVOIR' THEN ABS(subtotal_tnd) ELSE 0 END),0),3) credit_revenue,
    ROUND(COALESCE(SUM(CASE WHEN invoice_type='AVOIR' THEN -ABS(subtotal_tnd) ELSE subtotal_tnd END),0),3) net_revenue,
    SUM(invoice_type='AVOIR') credit_count,
    SUM(invoice_type='AVOIR' AND source_invoice_id IS NULL) unlinked_credit_count
    FROM erp_invoices WHERE user_id=? AND invoice_date BETWEEN ? AND ?
      AND invoice_type IN('FACTURE','AVOIR') AND is_validated=1");
$stmt->bind_param('iss',$tenantId,$from,$to);$stmt->execute();$sales=$stmt->get_result()->fetch_assoc();$stmt->close();
$stmt=$conn->prepare("SELECT
    ROUND(COALESCE(SUM(CASE WHEN i.invoice_type='FACTURE' THEN ii.montant_tva ELSE 0 END),0),3) gross_vat,
    ROUND(COALESCE(SUM(CASE WHEN i.invoice_type='AVOIR' THEN ABS(ii.montant_tva) ELSE 0 END),0),3) credit_vat,
    ROUND(COALESCE(SUM(CASE WHEN i.invoice_type='AVOIR' THEN -ABS(ii.montant_tva) ELSE ii.montant_tva END),0),3) net_vat
    FROM erp_invoice_items ii JOIN erp_invoices i ON i.id=ii.invoice_id
    WHERE i.user_id=? AND i.invoice_date BETWEEN ? AND ? AND i.invoice_type IN('FACTURE','AVOIR') AND i.is_validated=1");
$stmt->bind_param('iss',$tenantId,$from,$to);$stmt->execute();$vat=$stmt->get_result()->fetch_assoc();$stmt->close();
$revenueMatches=abs(((float)$sales['gross_revenue']-(float)$sales['credit_revenue'])-(float)$sales['net_revenue'])<0.0005;
$vatMatches=abs(((float)$vat['gross_vat']-(float)$vat['credit_vat'])-(float)$vat['net_vat'])<0.0005;
$success=$revenueMatches&&$vatMatches;
echo json_encode(['success'=>$success,'sign_policy'=>'FACTURE=+1; AVOIR=-1','sales'=>$sales,'vat'=>$vat,
    'revenue_reconciles'=>$revenueMatches,'vat_reconciles'=>$vatMatches,
    'aging_note'=>'Only validated credit notes linked by source_invoice_id reduce a specific invoice balance.'],JSON_PRETTY_PRINT|JSON_UNESCAPED_SLASHES).PHP_EOL;
exit($success?0:1);
