<?php
header('Content-Type: application/json');
require_once __DIR__ . '/../config/response.php';
require_once __DIR__ . '/../config/db.php';
require_once __DIR__ . '/../auth/auth_required.php';
require_once __DIR__ . '/../auth/role_helper.php';

require_once __DIR__ . '/product_inventory.php';

try {
    $user = requireAuth(); $uid=(int)$user->id; $conn = db();requireAnyPermission($conn,$uid,['stock.view','reports.view']); ensureProductInventorySchema($conn);
    $stmt = $conn->prepare("SELECT id,code,name,stock_quantity,average_cost,ROUND(stock_quantity*average_cost,3) inventory_value FROM products WHERE user_id=? AND item_type='PRODUCT' ORDER BY name");
    $stmt->bind_param('i',$uid); $stmt->execute();
    $rows=$stmt->get_result()->fetch_all(MYSQLI_ASSOC); $stmt->close();
    $total=array_reduce($rows,fn($sum,$r)=>$sum+(float)$r['inventory_value'],0.0);
    jsonResponse(['success'=>true,'valuation_method'=>'WEIGHTED_AVERAGE','total_value'=>round($total,3),'products'=>$rows]);
} catch(Throwable $e){ jsonResponse(['success'=>false,'message'=>$e->getMessage()],400); }
