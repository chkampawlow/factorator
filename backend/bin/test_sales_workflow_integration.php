<?php

declare(strict_types=1);

if(PHP_SAPI!=='cli'){http_response_code(404);exit;}
require_once __DIR__.'/../config/db.php';
require_once __DIR__.'/../invoices/workflow_domain.php';
require_once __DIR__.'/../invoices/workflow_rules.php';
require_once __DIR__.'/../invoice_settlements/service.php';

$c=db();$database=(string)$c->query('SELECT DATABASE()')->fetch_row()[0];
if(!preg_match('/(?:^|_)(?:test|testing|local)(?:_|$)/i',$database)){fwrite(STDERR,"REFUSED on $database\n");exit(2);}
$marker=bin2hex(random_bytes(6));$email="sales-flow-$marker@example.test";$failures=[];$userId=0;
function wfCheck(bool $ok,string $label,array &$failures):void{echo($ok?'PASS ':'FAIL ').$label.PHP_EOL;if(!$ok)$failures[]=$label;}

$c->begin_transaction();
try{
    $password=password_hash('Integration-only-password-2026!',PASSWORD_DEFAULT);$name='Sales Workflow Fixture';$fiscal='FLOW'.strtoupper($marker);
    $s=$c->prepare("INSERT INTO users(organization_name,fiscal_id,email,password_hash,email_verified_at,role,account_status) VALUES(?,?,?,?,NOW(),'ADMINISTRATOR','ACTIVE')");$s->bind_param('ssss',$name,$fiscal,$email,$password);$s->execute();$userId=(int)$s->insert_id;$s->close();
    $clientName='Workflow Client';$s=$c->prepare("INSERT INTO clients(reference,type,name,user_id) VALUES('C000001','ENTREPRISE',?,?)");$s->bind_param('si',$clientName,$userId);$s->execute();$clientId=(int)$s->insert_id;$s->close();
    $code="FLOW-$marker";$productName='Workflow Product';$s=$c->prepare("INSERT INTO products(code,name,item_type,price,tva_rate,unit,stock_quantity,user_id) VALUES(?,?,'PRODUCT',100,19,'pièce',20,?)");$s->bind_param('ssi',$code,$productName,$userId);$s->execute();$productId=(int)$s->insert_id;$s->close();
    $date='2026-08-10';$due='2026-09-09';$notes='Rollback-only sales workflow fixture';$devisNumber="DEV-TMP-$marker";$clientCode=(string)$clientId;$type='DEVIS';$status='ACCEPTED';
    $s=$c->prepare("INSERT INTO erp_invoices(invoice,custom_code,invoice_date,invoice_due_date,subtotal,subtotal_tnd,base_tva,montant_tva,tax_total_tnd,subtotal_ttc,shipping,discount,vat,total,total_tnd,notes,invoice_type,status,is_validated,timbre,user_id) VALUES(?,?,?, ?,400,400,400,76,76,476,0,0,19,476,476,?,?,?,1,0,?)");$s->bind_param('sssssssi',$devisNumber,$clientCode,$date,$due,$notes,$type,$status,$userId);$s->execute();$devisId=(int)$s->insert_id;$s->close();
    $s=$c->prepare("INSERT INTO erp_invoice_items(invoice_id,invoice,product_id,product_code,product,qty,tva_rate,montant_tva,tax_tnd,price,subtotal,subtotal_tnd,subtotalTTC,total_tnd,invoice_date) VALUES(?,?,?,?,?,4,19,76,76,100,400,400,476,476,?)");$s->bind_param('isisss',$devisId,$devisNumber,$productId,$code,$productName,$date);$s->execute();$s->close();
    $items=[['product_id'=>$productId,'product_code'=>$code,'product'=>$productName,'qty'=>4]];
    validateOrderAgainstAcceptedDevis($c,$devisId,$userId,$clientId,$items);wfCheck(true,'accepted quotation permits matching order',$failures);
    try{validateOrderAgainstAcceptedDevis($c,$devisId,$userId,$clientId,[...$items,['product_id'=>$productId,'product_code'=>$code,'product'=>$productName,'qty'=>1]]);$excessOrderDenied=false;}catch(Throwable){$excessOrderDenied=true;}wfCheck($excessOrderDenied,'order cannot exceed quotation quantity',$failures);
    $orderNumber="BC-TMP-$marker";$s=$c->prepare("INSERT INTO erp_sales_orders(order_number,client_id,order_date,source_devis_id,status,subtotal,montant_tva,total,user_id) VALUES(?,?,?,?, 'CONFIRMED',400,76,476,?)");$s->bind_param('sisii',$orderNumber,$clientId,$date,$devisId,$userId);$s->execute();$orderId=(int)$s->insert_id;$s->close();
    $s=$c->prepare("INSERT INTO erp_sales_order_items(sales_order_id,product_id,product_code,product,qty,price,tva_rate,subtotal,montant_tva,total) VALUES(?,?,?,?,4,100,19,400,76,476)");$s->bind_param('iiss',$orderId,$productId,$code,$productName);$s->execute();$s->close();
    validateDeliveryAgainstOrder($c,$orderId,$userId,$clientId,$items);wfCheck(true,'confirmed order permits matching delivery',$failures);
    try{validateDeliveryAgainstOrder($c,$orderId,$userId,$clientId,[['product_id'=>$productId,'product_code'=>$code,'product'=>$productName,'qty'=>5]]);$excessDeliveryDenied=false;}catch(Throwable){$excessDeliveryDenied=true;}wfCheck($excessDeliveryDenied,'delivery cannot exceed ordered quantity',$failures);
    $deliveryNumber="BL-TMP-$marker";$s=$c->prepare("INSERT INTO erp_delivery_notes(delivery_number,document_type,client_id,sales_order_id,delivery_date,status,item_count,stock_applied,user_id) VALUES(?,'DELIVERY',?,?,?,'DELIVERED',1,1,?)");$s->bind_param('siisi',$deliveryNumber,$clientId,$orderId,$date,$userId);$s->execute();$deliveryId=(int)$s->insert_id;$s->close();
    $s=$c->prepare("INSERT INTO erp_delivery_note_items(delivery_note_id,product_id,product_code,product,qty,price,tva_rate,subtotal,montant_tva,total,unit) VALUES(?,?,?,?,4,100,19,400,76,476,'pièce')");$s->bind_param('iiss',$deliveryId,$productId,$code,$productName);$s->execute();$s->close();
    validateInvoiceAgainstDeliveredNote($c,$deliveryId,$userId,$clientId,$items);wfCheck(true,'delivered note permits matching invoice',$failures);
    $invoiceNumber="FAC-TMP-$marker";$type='FACTURE';$status='UNPAID';$s=$c->prepare("INSERT INTO erp_invoices(invoice,custom_code,sales_order_id,delivery_note_id,source_flow,invoice_date,invoice_due_date,subtotal,subtotal_tnd,base_tva,montant_tva,tax_total_tnd,subtotal_ttc,shipping,discount,vat,total,total_tnd,notes,invoice_type,status,is_validated,timbre,user_id) VALUES(?,?,?,?,'DELIVERY',?,?,400,400,400,76,76,476,0,0,19,476,476,?,?,?,1,0,?)");$s->bind_param('ssiisssssi',$invoiceNumber,$clientCode,$orderId,$deliveryId,$date,$due,$notes,$type,$status,$userId);$s->execute();$invoiceId=(int)$s->insert_id;$s->close();
    $s=$c->prepare("INSERT INTO erp_invoice_items(invoice_id,invoice,product_id,product_code,product,qty,tva_rate,montant_tva,tax_tnd,price,subtotal,subtotal_tnd,subtotalTTC,total_tnd,invoice_date) VALUES(?,?,?,?,?,4,19,76,76,100,400,400,476,476,?)");$s->bind_param('isisss',$invoiceId,$invoiceNumber,$productId,$code,$productName,$date);$s->execute();$s->close();
    $amount=200.0;$s=$c->prepare("INSERT INTO erp_invoice_payments(invoice_id,user_id,amount,payment_date,method,recorded_by) VALUES(?,?,?,?,'CASH',?)");$s->bind_param('iidsi',$invoiceId,$userId,$amount,$date,$userId);$s->execute();$s->close();$partial=syncInvoiceSettlementState($c,$invoiceId,$userId);wfCheck($partial['derived_status']==='PARTIALLY_PAID'&&abs((float)$partial['remaining_balance']-276)<0.0005,'first payment creates correct partial balance',$failures);
    $amount=276.0;$s=$c->prepare("INSERT INTO erp_invoice_payments(invoice_id,user_id,amount,payment_date,method,recorded_by) VALUES(?,?,?,?,'CASH',?)");$s->bind_param('iidsi',$invoiceId,$userId,$amount,$date,$userId);$s->execute();$s->close();$paid=syncInvoiceSettlementState($c,$invoiceId,$userId);wfCheck($paid['derived_status']==='PAID'&&abs((float)$paid['remaining_balance'])<0.0005,'final payment closes invoice exactly',$failures);
    wfCheck($devisId>0&&$orderId>0&&$deliveryId>0&&$invoiceId>0,'quotation to paid invoice chain is complete',$failures);
}finally{$c->rollback();}
$s=$c->prepare('SELECT COUNT(*) FROM users WHERE email=?');$s->bind_param('s',$email);$s->execute();$remaining=(int)$s->get_result()->fetch_row()[0];$s->close();wfCheck($remaining===0,'sales workflow fixtures rolled back',$failures);
if($failures!==[])exit(1);echo 'Sales workflow integration suite passed.'.PHP_EOL;
