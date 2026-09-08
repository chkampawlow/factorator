<?php
declare(strict_types=1);
if(PHP_SAPI!=='cli'){http_response_code(404);exit;}
$_SERVER['REQUEST_METHOD']='CLI';require_once __DIR__.'/../config/db.php';$conn=db();$failed=false;
$checks=[
    'sales stamp values'=>"SELECT COUNT(*) n FROM erp_invoices WHERE timbre<0 OR ABS(total_tnd-ROUND(total*exchange_rate,3))>0.001",
    'sales total composition'=>"SELECT COUNT(*) n FROM erp_invoices i LEFT JOIN(SELECT invoice_id,ROUND(SUM(total_tnd),3) line_total FROM erp_invoice_items GROUP BY invoice_id)x ON x.invoice_id=i.id WHERE ABS(i.total_tnd-ROUND(COALESCE(x.line_total,0)+(CASE WHEN i.invoice_type='AVOIR' THEN -i.timbre ELSE i.timbre END)*i.exchange_rate,3))>0.001",
    'purchase stamp values'=>"SELECT COUNT(*) n FROM erp_supplier_invoices WHERE stamp_duty<0 OR ABS(stamp_duty_tnd-ROUND(stamp_duty*exchange_rate,3))>0.001",
    'purchase total composition'=>"SELECT COUNT(*) n FROM erp_supplier_invoices si LEFT JOIN(SELECT supplier_invoice_id,ROUND(SUM(total_ttc_tnd),3) line_total FROM erp_supplier_invoice_items GROUP BY supplier_invoice_id)x ON x.supplier_invoice_id=si.id WHERE ABS(si.total_ttc_tnd-ROUND(COALESCE(x.line_total,0)+si.stamp_duty_tnd,3))>0.001",
];
foreach($checks as $label=>$sql){$n=(int)$conn->query($sql)->fetch_assoc()['n'];if($n){$failed=true;fwrite(STDERR,"FAIL $label: $n mismatch(es)\n");}else echo "PASS $label reconciles\n";}
exit($failed?1:0);
