<?php
declare(strict_types=1);ini_set('serialize_precision','-1');
if(PHP_SAPI!=='cli'){http_response_code(404);exit;}
require_once __DIR__.'/../config/db.php';
$c=db();$iterations=max(5,min(100,(int)($argv[1]??20)));
$queries=[
'dashboard_invoices'=>['target'=>250,'sql'=>"SELECT SUM(invoice_type='FACTURE' AND is_validated=1),SUM(invoice_type='FACTURE' AND is_validated=1 AND invoice_due_date<CURDATE()),SUM(CASE WHEN invoice_type='AVOIR' AND is_validated=1 THEN -ABS(total) WHEN invoice_type='FACTURE' AND is_validated=1 THEN total ELSE 0 END) FROM erp_invoices WHERE user_id=?",'types'=>'i','args'=>[1]],
'invoice_page'=>['target'=>150,'sql'=>"SELECT id,invoice,invoice_date,status,total_tnd FROM erp_invoices WHERE user_id=? ORDER BY id DESC LIMIT 20 OFFSET 0",'types'=>'i','args'=>[1]],
'customer_aging'=>['target'=>400,'sql'=>"SELECT COUNT(*),SUM(i.total_tnd-COALESCE(p.paid,0)) FROM erp_invoices i LEFT JOIN(SELECT invoice_id,SUM(amount) paid FROM erp_invoice_payments WHERE status='POSTED' AND payment_date<=? GROUP BY invoice_id)p ON p.invoice_id=i.id WHERE i.user_id=? AND i.invoice_type='FACTURE' AND i.is_validated=1 AND i.invoice_date<=?",'types'=>'sis','args'=>[date('Y-m-d'),1,date('Y-m-d')]],
'vat_lines'=>['target'=>500,'sql'=>"SELECT ii.tax_regime,ii.tva_rate,SUM(ii.montant_tva*i.exchange_rate) FROM erp_invoice_items ii JOIN erp_invoices i ON i.id=ii.invoice_id WHERE i.user_id=? AND i.invoice_date BETWEEN ? AND ? AND i.is_validated=1 GROUP BY ii.tax_regime,ii.tva_rate",'types'=>'iss','args'=>[1,date('Y-01-01'),date('Y-m-d')]],
'stock_cogs'=>['target'=>250,'sql'=>"SELECT SUM(cogs_value) FROM product_stock_movements WHERE user_id=? AND created_at>=? AND created_at<DATE_ADD(?,INTERVAL 1 DAY)",'types'=>'iss','args'=>[1,date('Y-01-01'),date('Y-m-d')]],
];
$volumes=[];foreach(['erp_invoices','erp_invoice_items','products','product_stock_movements','clients','suppliers'] as $table){$volumes[$table]=(int)$c->query("SELECT COUNT(*) n FROM `$table`")->fetch_assoc()['n'];}
$ready=$volumes['erp_invoices']>=10000&&$volumes['erp_invoice_items']>=30000&&$volumes['products']>=1000;
$failed=false;$results=[];
foreach($queries as $name=>$test){$times=[];for($i=0;$i<$iterations;$i++){$s=$c->prepare($test['sql']);$s->bind_param($test['types'],...$test['args']);$start=hrtime(true);$s->execute();$result=$s->get_result();while($result->fetch_row()){}$times[]=(hrtime(true)-$start)/1e6;$s->close();}sort($times);$p95=$times[(int)ceil(count($times)*.95)-1];$pass=$p95<=$test['target'];$failed=$failed||!$pass;$results[$name]=['p95_ms'=>round($p95,2),'target_ms'=>$test['target'],'pass'=>$pass];echo($pass?'PASS ':'FAIL ').$name.' p95='.round($p95,2).'ms target='.$test['target']."ms\n";}
echo($ready?'PASS production-sized dataset':'WARN dataset below production-size thresholds')."\n";
echo json_encode(['success'=>!$failed,'representative_dataset'=>$ready,'iterations'=>$iterations,'volumes'=>$volumes,'results'=>$results],JSON_PRETTY_PRINT|JSON_UNESCAPED_SLASHES),"\n";exit($failed?1:0);
