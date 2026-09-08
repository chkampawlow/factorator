<?php
require_once __DIR__.'/../config/tenant_scope.php';
header('Content-Type: application/json');
require_once __DIR__.'/../config/response.php';
require_once __DIR__.'/../config/db.php';
require_once __DIR__.'/../auth/auth_required.php';
require_once __DIR__.'/../auth/role_helper.php';
require_once __DIR__.'/../taxes/tax_profile_service.php';

$debugStage = 'request';

try {
    if($_SERVER['REQUEST_METHOD']!=='POST')throw new Exception('Method not allowed');
    $debugStage='authentication';$principal=requireAuth();$uid=authTenantId($principal);$actorId=authActorId($principal);$d=json_decode(file_get_contents('php://input'),true)?:[];
    $supplier=(int)($d['supplier_id']??0);$number=trim((string)($d['invoice_number']??''));$date=(string)($d['invoice_date']??'');$due=(string)($d['due_date']??'');
    $currency=strtoupper(trim((string)($d['currency']??'TND')));$rate=decimalInput($d['exchange_rate']??($currency==='TND'?'1':''),'Exchange rate',8);$rateDate=(string)($d['exchange_rate_date']??$date);
    $stamp=decimalInput($d['stamp_duty']??'0','Stamp duty');if(bccomp($stamp,'0',6)<0)throw new Exception('Stamp duty cannot be negative');
    $lines=$d['lines']??[];$operationProfile=(int)($d['tax_profile_id']??0);$order=(int)($d['supplier_order_id']??0);
    $status=strtoupper((string)($d['status']??'DRAFT'));if(!in_array($status,['DRAFT','VALIDATED'],true))throw new Exception('Invalid supplier invoice status');
    if($supplier<=0||$number===''||!preg_match('/^\d{4}-\d{2}-\d{2}$/',$date)||!preg_match('/^\d{4}-\d{2}-\d{2}$/',$due)||$due<$date||!preg_match('/^\d{4}-\d{2}-\d{2}$/',$rateDate)||!in_array($currency,['TND','EUR','USD'],true)||bccomp($rate,'0',8)<=0||($currency==='TND'&&bccomp($rate,'1',8)!==0)||!is_array($lines)||!$lines)throw new Exception('Supplier, number, valid dates, currency, exchange rate and lines are required');
    $debugStage='authorization';$conn=db();requirePermission($conn,$uid,'supplierInvoices.create');if($status==='VALIDATED')requirePermission($conn,$uid,'supplierInvoices.validate');requireTenantSupplier($conn,$uid,$supplier);requireTenantSupplierOrder($conn,$uid,$order,$supplier);ensureTaxProfileSchema($conn);$conn->begin_transaction();
    $debugStage='line_matching';
    $ht=$tax=$ttc=$htTnd=$taxTnd=$ttcTnd='0.000';$normalized=[];$seenReceptionItems=[];
    $match=$conn->prepare("SELECT sri.catalog_id,sri.accepted_qty,sri.tva_rate,sr.supplier_id,sr.supplier_order_id,sr.status,sr.stock_applied,
        COALESCE((SELECT SUM(existing.quantity) FROM erp_supplier_invoice_items existing JOIN erp_supplier_invoices existing_invoice ON existing_invoice.id=existing.supplier_invoice_id WHERE existing.supplier_reception_item_id=sri.id AND existing_invoice.user_id=sr.user_id AND existing_invoice.status<>'CANCELLED'),0) billed_qty,
        COALESCE((SELECT SUM(return_item.quantity) FROM erp_supplier_return_items return_item JOIN erp_supplier_returns supplier_return ON supplier_return.id=return_item.supplier_return_id WHERE return_item.supplier_reception_item_id=sri.id AND supplier_return.user_id=sr.user_id AND supplier_return.status='CONFIRMED'),0) returned_qty
        FROM erp_supplier_reception_items sri JOIN erp_supplier_receptions sr ON sr.id=sri.supplier_reception_id
        WHERE sri.id=? AND sr.user_id=? FOR UPDATE");
    foreach($lines as $line){
        $product=(int)($line['product_id']??0);requireTenantProduct($conn,$uid,$product);
        $receptionItem=(int)($line['supplier_reception_item_id']??0);
        $source=null;
        if($order>0&&$receptionItem<=0)throw new Exception('Every purchase-order invoice line must be linked to a confirmed supplier reception line');
        if($receptionItem>0){
            if(isset($seenReceptionItems[$receptionItem]))throw new Exception('A supplier reception line can appear only once on an invoice');
            $seenReceptionItems[$receptionItem]=true;$match->bind_param('ii',$receptionItem,$uid);$match->execute();$source=$match->get_result()->fetch_assoc();
            if(!$source||(int)$source['supplier_id']!==$supplier||(int)$source['catalog_id']!==$product||strtoupper((string)$source['status'])!=='REVIEWED'||(int)$source['stock_applied']!==1)throw new Exception('Supplier invoice line is not linked to an authorized confirmed reception');
            if($order>0&&(int)$source['supplier_order_id']!==$order)throw new Exception('Supplier invoice and reception must belong to the same purchase order');
            $incomingQty=(float)decimalInput($line['quantity']??0,'Quantity');$available=round((float)$source['accepted_qty']-(float)$source['billed_qty']-(float)$source['returned_qty'],3);
            if($incomingQty>$available+0.0005)throw new Exception('Invoice quantity exceeds the unbilled accepted reception quantity');
        }
        $lineProfileId=(int)($line['tax_profile_id']??$operationProfile);
        if($lineProfileId<=0&&is_array($source))$lineProfileId=ensureProductTaxProfileForVatRate($conn,$uid,$product,(float)($source['tva_rate']??0),$date);
        $profile=resolveTaxProfile($conn,$uid,$lineProfileId,$product,$date);
        $calc=calculateTaxLine($line['quantity']??0,$line['unit_price']??0,'0',$profile,$rate);$lineTax=bcadd($calc['fodec_amount'],$calc['vat'],3);
        $ht=bcadd($ht,$calc['subtotal'],3);$tax=bcadd($tax,$lineTax,3);$ttc=bcadd($ttc,$calc['total'],3);$htTnd=bcadd($htTnd,$calc['subtotal_tnd'],3);$taxTnd=bcadd($taxTnd,$calc['tax_tnd'],3);$ttcTnd=bcadd($ttcTnd,$calc['total_tnd'],3);
        $normalized[]=[$line,$profile,$calc,$lineTax];
    }
    $match->close();
    $stampTnd=money3(bcmul($stamp,$rate,8));$ttc=bcadd($ttc,$stamp,3);$ttcTnd=bcadd($ttcTnd,$stampTnd,3);
    $order=$order?:null;$notes=trim((string)($d['notes']??''));
    $debugStage='invoice_header';$s=$conn->prepare("INSERT INTO erp_supplier_invoices(user_id,supplier_id,supplier_order_id,tax_profile_id,invoice_number,invoice_date,due_date,status,currency,exchange_rate,exchange_rate_date,total_ht,total_ht_tnd,total_vat,total_tax_tnd,stamp_duty,stamp_duty_tnd,total_ttc,total_ttc_tnd,notes,created_by,validated_at) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,IF(?='VALIDATED',NOW(),NULL))");
    $s->bind_param('iiiisssssdsddddddddsis',$uid,$supplier,$order,$operationProfile,$number,$date,$due,$status,$currency,$rate,$rateDate,$ht,$htTnd,$tax,$taxTnd,$stamp,$stampTnd,$ttc,$ttcTnd,$notes,$actorId,$status);$s->execute();$id=(int)$s->insert_id;$s->close();
    $debugStage='invoice_items';
    $i=$conn->prepare("INSERT INTO erp_supplier_invoice_items(supplier_invoice_id,supplier_reception_item_id,product_id,tax_profile_id,description,quantity,unit_price,vat_rate,fodec_rate,fodec_amount,tax_regime,deductibility_rate,legal_basis,certificate_reference,total_ht,total_ht_tnd,total_vat,deductible_vat_tnd,non_deductible_vat_tnd,total_tax_tnd,total_ttc,total_ttc_tnd) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)");
    foreach($normalized as [$line,$profile,$calc,$lineTax]){
        $ri=(int)($line['supplier_reception_item_id']??0)?:null;$pid=(int)($line['product_id']??0)?:null;
        $profileId=(int)$profile['id'];$desc=trim((string)($line['description']??''));$qty=decimalInput($line['quantity'],'Quantity');$price=decimalInput($line['unit_price'],'Unit price');
        $deductible=money3(bcmul($calc['vat_tnd'],bcdiv($calc['deductibility_rate'],'100',6),8));$nonDeductible=money3(bcsub($calc['vat_tnd'],$deductible,6));
        $i->bind_param('iiiisdddddsdssdddddddd',$id,$ri,$pid,$profileId,$desc,$qty,$price,$calc['vat_rate'],$calc['fodec_rate'],$calc['fodec_amount'],$calc['tax_regime'],$calc['deductibility_rate'],$calc['legal_basis'],$calc['certificate_reference'],$calc['subtotal'],$calc['subtotal_tnd'],$lineTax,$deductible,$nonDeductible,$calc['tax_tnd'],$calc['total'],$calc['total_tnd']);$i->execute();
    }
    $i->close();$debugStage='commit';$conn->commit();jsonResponse(['success'=>true,'id'=>$id,'currency'=>$currency,'exchange_rate'=>$rate,'stamp_duty'=>$stamp,'stamp_duty_tnd'=>$stampTnd,'total_ttc'=>$ttc,'total_ttc_tnd'=>$ttcTnd,'message'=>'Supplier invoice saved; totals were recalculated by the backend and stock was not changed']);
} catch(Throwable $e) {
    if(isset($conn))try{$conn->rollback();}catch(Throwable $ignored){}
    structuredLog('ERROR','SUPPLIER_INVOICE.SAVE_FAILED',['stage'=>$debugStage,'exception'=>get_class($e),'message'=>$e->getMessage(),'supplier_id'=>$supplier??0,'supplier_order_id'=>$order??0]);
    jsonResponse(['success'=>false,'message'=>$e->getMessage(),'error_code'=>'SUPPLIER_INVOICE_SAVE_FAILED'],400);
}
