<?php

declare(strict_types=1);

if(PHP_SAPI!=='cli'){http_response_code(404);exit;}
require_once __DIR__.'/../config/db.php';
require_once __DIR__.'/../reports/margin_report_service.php';
$conn=db();$database=(string)$conn->query('SELECT DATABASE()')->fetch_row()[0];if(!preg_match('/(?:^|_)(?:test|testing|local)(?:_|$)/i',$database)){fwrite(STDERR,"REFUSED on $database\n");exit(2);}
$failures=[];function marginCheck(bool $ok,string $label,array &$failures):void{echo($ok?'PASS ':'FAIL ').$label.PHP_EOL;if(!$ok)$failures[]=$label;}
$normalized=normalizeMarginAggregate(['documents'=>'2','quantity'=>'3.500','revenue_tnd'=>'300.125','cost_tnd'=>'120.025','gross_margin_tnd'=>'180.100','margin_rate_percent'=>'60.005','cost_coverage_percent'=>'100']);
marginCheck($normalized['gross_margin_tnd']==='180.100'&&$normalized['quantity']==='3.500','margin amounts preserve millime precision',$failures);
marginCheck($normalized['documents']===2&&$normalized['cost_coverage_percent']==='100.000','margin counters and percentages are normalized',$failures);
try{validateMarginReportPeriod('2026-08-12','2026-08-11');$invalidRejected=false;}catch(InvalidArgumentException){$invalidRejected=true;}marginCheck($invalidRejected,'invalid margin period is rejected',$failures);
$conn->begin_transaction();
try{
    $marker=bin2hex(random_bytes(4));$fiscal='M'.$marker;$email="margin-$marker@example.test";$password=str_repeat('x',60);
    $s=$conn->prepare("INSERT INTO users(organization_name,fiscal_id,email,password_hash,email_verified_at) VALUES('Margin test',?,?,?,NOW())");$s->bind_param('sss',$fiscal,$email,$password);$s->execute();$tenant=(int)$s->insert_id;$s->close();
    $s=$conn->prepare("INSERT INTO clients(reference,type,name,user_id) VALUES('C000001','company','Client marge',?)");$s->bind_param('i',$tenant);$s->execute();$client=(int)$s->insert_id;$s->close();
    $code="P-$marker";$s=$conn->prepare("INSERT INTO products(code,name,category,item_type,price,last_purchase_price,average_cost,tva_rate,unit,stock_quantity,user_id) VALUES(?,'Produit marge','Équipement','PRODUCT',100,40,40,19,'pièce',9,?)");$s->bind_param('si',$code,$tenant);$s->execute();$product=(int)$s->insert_id;$s->close();
    $number="FAC-$marker";$clientCode=(string)$client;$s=$conn->prepare("INSERT INTO erp_invoices(invoice,custom_code,salesperson_name,invoice_date,invoice_due_date,subtotal,subtotal_tnd,subtotal_ttc,total,total_tnd,notes,invoice_type,status,is_validated,user_id) VALUES(?,?,'Sonia','2026-08-11','2026-09-10',100,100,119,120,120,'Margin rollback fixture','FACTURE','UNPAID',1,?)");$s->bind_param('ssi',$number,$clientCode,$tenant);$s->execute();$invoice=(int)$s->insert_id;$s->close();
    $s=$conn->prepare("INSERT INTO erp_invoice_items(invoice_id,invoice,product_id,product_code,product,qty,tva_rate,montant_tva,price,subtotal,subtotal_tnd,subtotalTTC,total_tnd,invoice_date) VALUES(?,?,?,?, 'Produit marge',1,19,19,100,100,100,119,119,'2026-08-11')");$s->bind_param('isis',$invoice,$number,$product,$code);$s->execute();$s->close();
    $s=$conn->prepare("INSERT INTO product_stock_movements(user_id,product_id,movement_type,quantity,unit_cost,movement_value,cogs_value,reference_type,reference_id,note) VALUES(?,?,'INVOICE_OUT',-1,40,-40,40,'INVOICE',?,'Margin rollback fixture')");$s->bind_param('iii',$tenant,$product,$invoice);$s->execute();$s->close();
    $fixture=buildTenantMarginReport($conn,$tenant,'2026-08-01','2026-08-31',25);
    marginCheck($fixture['summary']['revenue_tnd']==='100.000'&&$fixture['summary']['cost_tnd']==='40.000'&&$fixture['summary']['gross_margin_tnd']==='60.000','validated revenue reconciles to weighted-average COGS',$failures);
    marginCheck(($fixture['dimensions']['categories'][0]['label']??'')==='Équipement'&&($fixture['dimensions']['salespersons'][0]['label']??'')==='Sonia','category and salesperson dimensions are reported',$failures);
    marginCheck($fixture['summary']['cost_coverage_percent']==='100.000'&&$fixture['cost_model_complete']===true,'recorded stock cost produces complete coverage',$failures);
}finally{$conn->rollback();}
$empty=buildTenantMarginReport($conn,random_int(700000000,799999999),'2026-08-01','2026-08-31',10);
marginCheck($empty['summary']['revenue_tnd']==='0.000'&&$empty['summary']['gross_margin_tnd']==='0.000','empty tenant margin totals are zero',$failures);
marginCheck($empty['dimensions']===['customers'=>[],'products'=>[],'categories'=>[],'salespersons'=>[]],'empty tenant dimensions are explicit',$failures);
marginCheck($empty['cost_model_complete']===true,'empty margin report has complete cost coverage',$failures);
if($failures!==[])exit(1);echo'Margin report suite passed.'.PHP_EOL;
