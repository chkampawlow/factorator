<?php
header('Content-Type: application/json');
require_once __DIR__ . '/../config/response.php';
require_once __DIR__ . '/../config/db.php';
require_once __DIR__ . '/../config/idempotency.php';
require_once __DIR__ . '/../auth/auth_required.php';
require_once __DIR__ . '/../auth/role_helper.php';
require_once __DIR__ . '/product_inventory.php';

try {
    if ($_SERVER['REQUEST_METHOD']!=='POST') throw new Exception('Method not allowed');
    $user=requireAuth(); $data=json_decode(file_get_contents('php://input'),true) ?: [];
    $productId=(int)($data['product_id']??0); $delta=round((float)($data['quantity_delta']??0),3);
    $code=strtoupper(trim((string)($data['reason_code']??''))); $detail=trim((string)($data['reason_detail']??''));
    $key=requiredIdempotencyKey($data);
    if($productId<=0 || abs($delta)<0.0001 || $code==='' || $detail==='') throw new Exception('Product, non-zero quantity, reason code and reason detail are required');
    if(!in_array($code,['COUNT_CORRECTION','DAMAGE','LOSS','FOUND','OTHER'],true)) throw new Exception('Invalid stock adjustment reason');
    if(mb_strlen($detail)>255) throw new Exception('The adjustment explanation is too long');
    $lot=trim((string)($data['lot_number']??''))?:null; $serial=trim((string)($data['serial_number']??''))?:null;
    if(($lot!==null && mb_strlen($lot)>100) || ($serial!==null && mb_strlen($serial)>150)) throw new Exception('Lot or serial number is too long');
    $conn=db(); $uid=authTenantId($user); $actorId=authActorId($user); requirePermission($conn,$actorId,'stock.adjust'); ensureProductInventorySchema($conn); $conn->begin_transaction();
    $productLock=$conn->prepare('SELECT item_type FROM products WHERE id=? AND user_id=? FOR UPDATE');
    $productLock->bind_param('ii',$productId,$uid);$productLock->execute();$product=$productLock->get_result()->fetch_assoc();$productLock->close();
    if(!$product) throw new Exception('Product not found or unauthorized');
    if(strtoupper((string)($product['item_type']??'PRODUCT'))==='SERVICE') throw new Exception('A service does not use stock movements');
    $currentQuantity=getProductStockQuantity($conn,$productId,$uid);
    if($currentQuantity+$delta < -0.0001) throw new Exception('Adjustment cannot create negative stock');
    $hash=idempotencyRequestHash(['product_id'=>$productId,'quantity_delta'=>$delta,'reason_code'=>$code,'reason_detail'=>$detail,'lot_number'=>$lot,'serial_number'=>$serial]);
    $replayedId=claimIdempotencyKey($conn,$uid,'stock.adjustment.create',$key,$hash);if($replayedId!==null){$quantity=getProductStockQuantity($conn,$productId,$uid);$conn->commit();jsonResponse(['success'=>true,'adjustment_id'=>$replayedId,'stock_quantity'=>$quantity,'replayed'=>true]);}
    $stmt=$conn->prepare("INSERT INTO erp_inventory_adjustments(user_id,product_id,quantity_delta,reason_code,reason_detail,lot_number,serial_number,created_by) VALUES(?,?,?,?,?,?,?,?)");
    $stmt->bind_param('iidsissi',$uid,$productId,$delta,$code,$detail,$lot,$serial,$actorId); $stmt->execute(); $id=(int)$stmt->insert_id; $stmt->close();
    recordProductStockMovement($conn,$productId,$uid,$delta,'ADJUSTMENT','INVENTORY_ADJUSTMENT',$id,$detail,null,$code,$lot,$serial,'INVENTORY_ADJUSTMENT:'.$id);
    $quantity=syncProductStockQuantity($conn,$productId,$uid);completeIdempotencyKey($conn,$uid,'stock.adjustment.create',$key,$id); $conn->commit();
    jsonResponse(['success'=>true,'adjustment_id'=>$id,'stock_quantity'=>$quantity,'replayed'=>false]);
} catch(Throwable $e){ if(isset($conn)) try{$conn->rollback();}catch(Throwable $ignored){} jsonResponse(['success'=>false,'message'=>$e->getMessage()],400); }
