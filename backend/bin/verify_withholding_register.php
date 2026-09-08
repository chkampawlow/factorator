<?php
declare(strict_types=1);if(PHP_SAPI!=='cli'){http_response_code(404);exit;}$_SERVER['REQUEST_METHOD']='CLI';require_once __DIR__.'/../config/db.php';$conn=db();$failed=false;
$checks=[
    'withholding formulas'=>"SELECT COUNT(*) n FROM erp_invoice_withholdings WHERE rate NOT BETWEEN 0 AND 100 OR calculation_base<=0 OR ABS(withheld_amount-ROUND(calculation_base*rate/100,3))>0.001",
    'certificate requirements'=>"SELECT COUNT(*) n FROM erp_invoice_withholdings WHERE certificate_status IN('RECEIVED','VALIDATED') AND(certificate_number='' OR certificate_date IS NULL)",
    'certificate lifecycle'=>"SELECT COUNT(*) n FROM erp_invoice_withholdings WHERE(certificate_status='PENDING' AND(received_at IS NOT NULL OR validated_at IS NOT NULL OR cancelled_at IS NOT NULL))OR(certificate_status='RECEIVED' AND(received_at IS NULL OR validated_at IS NOT NULL OR cancelled_at IS NOT NULL))OR(certificate_status='VALIDATED' AND(received_at IS NULL OR validated_at IS NULL OR cancelled_at IS NOT NULL))OR(certificate_status='CANCELLED' AND cancelled_at IS NULL)",
    'tenant ownership'=>"SELECT COUNT(*) n FROM erp_invoice_withholdings w JOIN erp_invoices i ON i.id=w.invoice_id WHERE w.user_id<>i.user_id",
];
foreach($checks as $label=>$sql){$n=(int)$conn->query($sql)->fetch_assoc()['n'];if($n){$failed=true;fwrite(STDERR,"FAIL $label: $n mismatch(es)\n");}else echo "PASS $label reconciles\n";}
$duplicates=(int)$conn->query("SELECT COUNT(*) n FROM(SELECT user_id,certificate_number FROM erp_invoice_withholdings WHERE certificate_number<>'' AND certificate_status<>'CANCELLED' GROUP BY user_id,certificate_number HAVING COUNT(*)>1)x")->fetch_assoc()['n'];echo "INFO duplicate active certificate numbers: $duplicates\n";exit($failed?1:0);
