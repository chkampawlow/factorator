<?php
declare(strict_types=1);
if(PHP_SAPI!=='cli'){http_response_code(404);exit;}
$_SERVER['REQUEST_METHOD']='CLI';require_once __DIR__.'/../config/db.php';$conn=db();$failed=false;
$checks=[
    'sales line FODEC'=>"SELECT COUNT(*) n FROM erp_invoice_items WHERE fodec_rate NOT BETWEEN 0 AND 100 OR ABS(fodec_amount-ROUND(subtotal*fodec_rate/100,3))>0.001",
    'purchase line FODEC'=>"SELECT COUNT(*) n FROM erp_supplier_invoice_items WHERE fodec_rate NOT BETWEEN 0 AND 100 OR ABS(fodec_amount-ROUND(total_ht*fodec_rate/100,3))>0.001",
    'sales document tax'=>"SELECT COUNT(*) n FROM erp_invoices i LEFT JOIN(SELECT invoice_id,ROUND(SUM(tax_tnd),3) line_tax FROM erp_invoice_items GROUP BY invoice_id)x ON x.invoice_id=i.id WHERE ABS(i.tax_total_tnd-COALESCE(x.line_tax,0))>0.001",
    'purchase document tax'=>"SELECT COUNT(*) n FROM erp_supplier_invoices si LEFT JOIN(SELECT supplier_invoice_id,ROUND(SUM(total_tax_tnd),3) line_tax FROM erp_supplier_invoice_items GROUP BY supplier_invoice_id)x ON x.supplier_invoice_id=si.id WHERE ABS(si.total_tax_tnd-COALESCE(x.line_tax,0))>0.001",
];
foreach($checks as $label=>$sql){$n=(int)$conn->query($sql)->fetch_assoc()['n'];if($n){$failed=true;fwrite(STDERR,"FAIL $label: $n mismatch(es)\n");}else echo "PASS $label reconciles\n";}
exit($failed?1:0);
