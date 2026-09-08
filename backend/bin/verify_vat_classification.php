<?php
declare(strict_types=1);
if(PHP_SAPI!=='cli'){http_response_code(404);exit;}
$_SERVER['REQUEST_METHOD']='CLI';require_once __DIR__.'/../config/db.php';$conn=db();$failed=false;
$supplier=$conn->query("SELECT COUNT(*) line_count,ROUND(COALESCE(SUM(ABS((sii.deductible_vat_tnd+sii.non_deductible_vat_tnd)-ROUND(sii.total_vat*si.exchange_rate,3))),0),3) difference FROM erp_supplier_invoice_items sii JOIN erp_supplier_invoices si ON si.id=sii.supplier_invoice_id WHERE sii.deductibility_rate NOT BETWEEN 0 AND 100 OR ABS((sii.deductible_vat_tnd+sii.non_deductible_vat_tnd)-ROUND(sii.total_vat*si.exchange_rate,3))>0.001")->fetch_assoc();
if((int)$supplier['line_count']>0){$failed=true;fwrite(STDERR,"FAIL supplier VAT buckets differ by {$supplier['difference']} TND\n");}else echo "PASS supplier deductible and non-deductible VAT reconcile\n";
$sales=$conn->query("SELECT COUNT(*) line_count FROM erp_invoice_items WHERE tax_regime NOT IN('STANDARD','SUSPENDED','EXEMPT','OUT_OF_SCOPE') OR (tax_regime<>'STANDARD' AND ABS(montant_tva)>0.001)")->fetch_assoc();
if((int)$sales['line_count']>0){$failed=true;fwrite(STDERR,"FAIL {$sales['line_count']} sales lines have an invalid regime/VAT combination\n");}else echo "PASS sales VAT regimes are explicit and consistent\n";
$profiles=$conn->query("SELECT COUNT(*) profiles FROM erp_tax_profiles WHERE deductibility_rate NOT BETWEEN 0 AND 100 OR (tax_regime<>'STANDARD' AND (ABS(vat_rate)>0.001 OR ABS(deductibility_rate)>0.001))")->fetch_assoc();
if((int)$profiles['profiles']>0){$failed=true;fwrite(STDERR,"FAIL {$profiles['profiles']} tax profiles are inconsistent\n");}else echo "PASS tax profile classifications are consistent\n";
exit($failed?1:0);
