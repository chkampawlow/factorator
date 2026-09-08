<?php
require_once __DIR__.'/workflow_schema.php';

function workflowAggregateItems(array $items): array {
    $map=[]; foreach($items as $item){$key=workflowItemKey($item['product_id']??0,(string)($item['product_code']??''),(string)($item['product']??''));$map[$key]=($map[$key]??0)+abs((float)($item['qty']??0));} return $map;
}

function validateOrderAgainstAcceptedDevis(mysqli $c,int $devisId,int $userId,int $clientId,array $items,int $excludeOrderId=0):void {
    $s=$c->prepare("SELECT id,custom_code,status,invoice_type FROM erp_invoices WHERE id=? AND user_id=? LIMIT 1 FOR UPDATE");$s->bind_param('ii',$devisId,$userId);$s->execute();$d=$s->get_result()->fetch_assoc();$s->close();
    if(!$d||strtoupper((string)$d['invoice_type'])!=='DEVIS'||strtoupper((string)$d['status'])!=='ACCEPTED')throw new Exception('Only an accepted devis can create an order');
    if((int)$d['custom_code']!==$clientId)throw new Exception('Order client must match the accepted devis');
    $s=$c->prepare('SELECT product_id,product_code,product,qty FROM erp_invoice_items WHERE invoice_id=?');$s->bind_param('i',$devisId);$s->execute();$source=workflowAggregateItems($s->get_result()->fetch_all(MYSQLI_ASSOC));$s->close();
    $s=$c->prepare("SELECT oi.product_id,oi.product_code,oi.product,oi.qty FROM erp_sales_order_items oi JOIN erp_sales_orders o ON o.id=oi.sales_order_id WHERE o.user_id=? AND o.source_devis_id=? AND o.id<>? AND o.status<>'CANCELLED'");$s->bind_param('iii',$userId,$devisId,$excludeOrderId);$s->execute();$used=workflowAggregateItems($s->get_result()->fetch_all(MYSQLI_ASSOC));$s->close();
    foreach(workflowAggregateItems($items) as $key=>$qty){if(!isset($source[$key]))throw new Exception('Order contains an item not present in the accepted devis');if(($used[$key]??0)+$qty>$source[$key]+0.0001)throw new Exception('Ordered quantity exceeds the remaining accepted devis quantity');}
}

function validateDeliveryAgainstOrder(mysqli $c,int $orderId,int $userId,int $clientId,array $items,int $excludeDeliveryId=0):void {
    $s=$c->prepare('SELECT id,client_id,status FROM erp_sales_orders WHERE id=? AND user_id=? LIMIT 1 FOR UPDATE');$s->bind_param('ii',$orderId,$userId);$s->execute();$o=$s->get_result()->fetch_assoc();$s->close();
    if(!$o||!in_array((string)$o['status'],['CONFIRMED','PARTIALLY_DELIVERED'],true))throw new Exception('Delivery requires a confirmed or partially delivered order');if((int)$o['client_id']!==$clientId)throw new Exception('Delivery client must match the order');
    $s=$c->prepare('SELECT product_id,product_code,product,qty FROM erp_sales_order_items WHERE sales_order_id=?');$s->bind_param('i',$orderId);$s->execute();$source=workflowAggregateItems($s->get_result()->fetch_all(MYSQLI_ASSOC));$s->close();
    $s=$c->prepare("SELECT di.product_id,di.product_code,di.product,di.qty FROM erp_delivery_note_items di JOIN erp_delivery_notes d ON d.id=di.delivery_note_id WHERE d.user_id=? AND d.sales_order_id=? AND d.id<>? AND d.status<>'CANCELLED'");$s->bind_param('iii',$userId,$orderId,$excludeDeliveryId);$s->execute();$used=workflowAggregateItems($s->get_result()->fetch_all(MYSQLI_ASSOC));$s->close();
    foreach(workflowAggregateItems($items) as $key=>$qty){if(!isset($source[$key]))throw new Exception('Delivery contains an item not present in the order');if(($used[$key]??0)+$qty>$source[$key]+0.0001)throw new Exception('Delivered quantity exceeds the remaining ordered quantity');}
}

function validateInvoiceAgainstDeliveredNote(mysqli $c,int $deliveryId,int $userId,int $clientId,array $items,int $excludeInvoiceId=0):void {
    $s=$c->prepare("SELECT id,client_id,status FROM erp_delivery_notes WHERE id=? AND user_id=? LIMIT 1 FOR UPDATE");$s->bind_param('ii',$deliveryId,$userId);$s->execute();$d=$s->get_result()->fetch_assoc();$s->close();if(!$d||(string)$d['status']!=='DELIVERED')throw new Exception('Invoice creation requires a delivered delivery note');if((int)$d['client_id']!==$clientId)throw new Exception('Invoice client must match the delivery note');
    $s=$c->prepare('SELECT product_id,product_code,product,qty FROM erp_delivery_note_items WHERE delivery_note_id=?');$s->bind_param('i',$deliveryId);$s->execute();$source=workflowAggregateItems($s->get_result()->fetch_all(MYSQLI_ASSOC));$s->close();
    $s=$c->prepare("SELECT ii.product_id,ii.product_code,ii.product,ii.qty FROM erp_invoice_items ii JOIN erp_invoices i ON i.id=ii.invoice_id WHERE i.user_id=? AND i.delivery_note_id=? AND i.id<>? AND i.invoice_type='FACTURE' AND IFNULL(i.is_validated,0)=1");$s->bind_param('iii',$userId,$deliveryId,$excludeInvoiceId);$s->execute();$used=workflowAggregateItems($s->get_result()->fetch_all(MYSQLI_ASSOC));$s->close();
    foreach(workflowAggregateItems($items) as $key=>$qty){if(!isset($source[$key]))throw new Exception('Invoice contains an item not present in the delivery note');if(($used[$key]??0)+$qty>$source[$key]+0.0001)throw new Exception('Invoiced quantity exceeds the remaining delivered quantity');}
}
