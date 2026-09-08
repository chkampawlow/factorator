<?php

declare(strict_types=1);

if(PHP_SAPI!=='cli'){http_response_code(404);exit;}
require_once __DIR__.'/../config/db.php';
require_once __DIR__.'/../reports/exchange_difference_service.php';
$conn=db();$database=(string)$conn->query('SELECT DATABASE()')->fetch_row()[0];
if(!preg_match('/(?:^|_)(?:test|testing|local)(?:_|$)/i',$database)){fwrite(STDERR,"REFUSED on $database\n");exit(2);}
$failures=[];
function exchangeCheck(bool $ok,string $label,array &$failures):void{echo($ok?'PASS ':'FAIL ').$label.PHP_EOL;if(!$ok)$failures[]=$label;}
try{validateExchangeDifferencePeriod('2026-08-12','2026-08-11');$invalid=false;}catch(InvalidArgumentException){$invalid=true;}
exchangeCheck($invalid,'invalid exchange-difference period is rejected',$failures);
$conn->begin_transaction();
try{
    $marker=bin2hex(random_bytes(4));$fiscal='X'.$marker;$email="exchange-$marker@example.test";$password=str_repeat('x',60);
    $s=$conn->prepare("INSERT INTO users(organization_name,fiscal_id,email,password_hash,email_verified_at) VALUES('Exchange test',?,?,?,NOW())");$s->bind_param('sss',$fiscal,$email,$password);$s->execute();$tenant=(int)$s->insert_id;$s->close();
    $s=$conn->prepare("INSERT INTO clients(reference,type,name,user_id) VALUES('C000001','company','Client EUR',?)");$s->bind_param('i',$tenant);$s->execute();$client=(int)$s->insert_id;$s->close();
    $reference='F000001';$s=$conn->prepare("INSERT INTO suppliers(reference,type,name,user_id) VALUES(?,'company','Fournisseur USD',?)");$s->bind_param('si',$reference,$tenant);$s->execute();$supplier=(int)$s->insert_id;$s->close();
    $number="FAC-$marker";$clientCode=(string)$client;
    $s=$conn->prepare("INSERT INTO erp_invoices(invoice,custom_code,invoice_date,invoice_due_date,currency,exchange_rate,exchange_rate_date,subtotal,subtotal_tnd,subtotal_ttc,total,total_tnd,notes,invoice_type,status,is_validated,user_id) VALUES(?,?,'2026-07-01','2026-08-31','EUR',3.2,'2026-07-01',100,320,100,100,320,'Exchange rollback fixture','FACTURE','PARTIALLY_PAID',1,?)");$s->bind_param('ssi',$number,$clientCode,$tenant);$s->execute();$invoice=(int)$s->insert_id;$s->close();
    $s=$conn->prepare("INSERT INTO erp_invoice_payments(invoice_id,user_id,amount,exchange_rate,exchange_rate_date,amount_tnd,payment_date,method,recorded_by) VALUES(?,?,40,3.3,'2026-08-10',132,'2026-08-10','BANK_TRANSFER',?)");$s->bind_param('iii',$invoice,$tenant,$tenant);$s->execute();$s->close();
    $s=$conn->prepare("INSERT INTO erp_invoice_payments(invoice_id,user_id,amount,payment_date,method,recorded_by) VALUES(?,?,10,'2026-08-11','BANK_TRANSFER',?)");$s->bind_param('iii',$invoice,$tenant,$tenant);$s->execute();$s->close();
    $supplierNumber="FS-$marker";
    $s=$conn->prepare("INSERT INTO erp_supplier_invoices(user_id,supplier_id,invoice_number,invoice_date,due_date,status,currency,exchange_rate,exchange_rate_date,total_ht,total_ht_tnd,total_vat,total_tax_tnd,total_ttc,total_ttc_tnd,notes,created_by,validated_at) VALUES(?,?,?,'2026-07-02','2026-08-31','PARTIALLY_PAID','USD',3,'2026-07-02',200,600,0,0,200,600,'Exchange rollback fixture',?,NOW())");$s->bind_param('iisi',$tenant,$supplier,$supplierNumber,$tenant);$s->execute();$supplierInvoice=(int)$s->insert_id;$s->close();
    $s=$conn->prepare("INSERT INTO erp_supplier_payments(user_id,supplier_invoice_id,amount,exchange_rate,exchange_rate_date,amount_tnd,payment_date,method,account,recorded_by) VALUES(?,?,50,3.1,'2026-08-10',155,'2026-08-10','BANK_TRANSFER','Banque',?)");$s->bind_param('iii',$tenant,$supplierInvoice,$tenant);$s->execute();$s->close();
    $report=buildTenantExchangeDifferenceReport($conn,$tenant,'2026-08-01','2026-08-31',25);
    exchangeCheck($report['summary']['payments']===3&&$report['summary']['documents']===2,'foreign settlements and documents are counted',$failures);
    exchangeCheck($report['summary']['realized_gains_tnd']==='4.000'&&$report['summary']['realized_losses_tnd']==='5.000'&&$report['summary']['net_exchange_difference_tnd']==='-1.000','customer gains and supplier losses use direction-aware signs',$failures);
    exchangeCheck($report['summary']['carrying_tnd']==='278.000'&&$report['summary']['settlement_tnd']==='287.000','carrying and settlement values preserve millime totals',$failures);
    exchangeCheck($report['summary']['missing_rate_payments']===1&&$report['rate_data_complete']===false,'legacy foreign settlement without a rate is explicit',$failures);
    exchangeCheck(count($report['by_currency'])===2&&($report['details'][0]['rate_missing']??false)===true,'currency breakdown and missing-rate priority are exposed',$failures);
    $exposure=[];foreach($report['open_exposure'] as $row)$exposure[$row['direction'].'-'.$row['currency']]=$row;
    exchangeCheck(($exposure['CUSTOMER-EUR']['amount_foreign']??'')==='50.000'&&($exposure['CUSTOMER-EUR']['carrying_tnd']??'')==='160.000','open customer exposure uses source balance and invoice rate',$failures);
    exchangeCheck(($exposure['SUPPLIER-USD']['amount_foreign']??'')==='150.000'&&($exposure['SUPPLIER-USD']['carrying_tnd']??'')==='450.000','open supplier exposure uses source balance and invoice rate',$failures);
}finally{$conn->rollback();}
$empty=buildTenantExchangeDifferenceReport($conn,random_int(600000000,699999999),'2026-08-01','2026-08-31',10);
exchangeCheck($empty['summary']['payments']===0&&$empty['summary']['net_exchange_difference_tnd']==='0.000'&&$empty['rate_data_complete']===true,'empty tenant exchange report is explicit',$failures);
if($failures!==[])exit(1);echo'Exchange-difference suite passed.'.PHP_EOL;
