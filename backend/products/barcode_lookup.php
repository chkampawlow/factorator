<?php
declare(strict_types=1);
header('Content-Type: application/json');
require_once __DIR__.'/../config/response.php';
require_once __DIR__.'/../config/db.php';
require_once __DIR__.'/../auth/auth_required.php';
require_once __DIR__.'/../auth/role_helper.php';
require_once __DIR__.'/../config/field_projection.php';
try {
    if (($_SERVER['REQUEST_METHOD'] ?? 'GET') !== 'GET') jsonResponse(['success'=>false,'message'=>'Method not allowed.'],405);
    $uid=(int)requireAuth()->id;
    $barcode=strtoupper(trim((string)($_GET['barcode']??'')));
    if ($barcode==='' || strlen($barcode)>64 || !preg_match('/^[A-Z0-9._:\/-]+$/',$barcode)) {
        jsonResponse(['success'=>false,'message'=>'Invalid barcode.','error_code'=>'INVALID_BARCODE'],422);
    }
    $c=db();requireAnyPermission($c,$uid,['products.view','services.view','stock.view','orders.view','deliveries.view','invoices.view']);
    $s=$c->prepare('SELECT id,code,barcode,name,category,item_type,price,selling_price_required,last_purchase_price,average_cost,tva_rate,unit,stock_quantity,reorder_point FROM products WHERE user_id=? AND UPPER(barcode)=? LIMIT 1');
    $s->bind_param('is',$uid,$barcode);$s->execute();$product=$s->get_result()->fetch_assoc();$s->close();
    if(!$product) jsonResponse(['success'=>false,'message'=>'Product not found.','error_code'=>'PRODUCT_NOT_FOUND'],404);
    jsonResponse(['success'=>true,'product'=>projectProductFields($product,currentUserRole($c,$uid))]);
} catch(Throwable $e) {
    jsonResponse(['success'=>false,'message'=>'Could not look up barcode.','error_code'=>'BARCODE_LOOKUP_FAILED'],500);
}
