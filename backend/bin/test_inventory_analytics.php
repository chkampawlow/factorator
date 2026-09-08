<?php
declare(strict_types=1);
if(PHP_SAPI!=='cli'){http_response_code(404);exit;}
require_once __DIR__.'/../config/db.php';require_once __DIR__.'/../reports/inventory_analytics_service.php';
$c=db();$database=(string)$c->query('SELECT DATABASE()')->fetch_row()[0];if(!preg_match('/(?:^|_)(?:test|testing|local)(?:_|$)/i',$database)){fwrite(STDERR,"REFUSED on $database\n");exit(2);}
$failures=[];function inventoryCheck(bool $ok,string $label,array &$failures):void{echo($ok?'PASS ':'FAIL ').$label.PHP_EOL;if(!$ok)$failures[]=$label;}
try{validateInventoryAnalyticsInput('2026-08-11',365,180,90);$thresholdRejected=false;}catch(InvalidArgumentException){$thresholdRejected=true;}inventoryCheck($thresholdRejected,'dead-stock threshold must exceed slow-moving threshold',$failures);
$c->begin_transaction();
try{
    $marker=bin2hex(random_bytes(4));$fiscal='I'.$marker;$email="inventory-$marker@example.test";$password=str_repeat('x',60);
    $s=$c->prepare("INSERT INTO users(organization_name,fiscal_id,email,password_hash,email_verified_at) VALUES('Inventory test',?,?,?,NOW())");$s->bind_param('sss',$fiscal,$email,$password);$s->execute();$tenant=(int)$s->insert_id;$s->close();
    $products=[['ACTIVE',2.0,10.0,3.0],['SLOW',9.0,10.0,3.0],['DEAD',5.0,10.0,3.0]];$ids=[];
    foreach($products as [$suffix,$stock,$cost,$reorder]){$code="$suffix-$marker";$name="$suffix product";$s=$c->prepare("INSERT INTO products(code,name,item_type,price,last_purchase_price,average_cost,tva_rate,unit,stock_quantity,reorder_point,user_id) VALUES(?,?,'PRODUCT',20,?,?,19,'pièce',?,?,?)");$s->bind_param('ssddddi',$code,$name,$cost,$cost,$stock,$reorder,$tenant);$s->execute();$ids[$suffix]=(int)$s->insert_id;$s->close();}
    $movement=function(int $product,string $type,float $quantity,float $cost,float $cogs,string $date)use($c,$tenant):void{$value=$quantity*$cost;$s=$c->prepare("INSERT INTO product_stock_movements(user_id,product_id,movement_type,quantity,unit_cost,movement_value,cogs_value,reference_type,reference_id,note,created_at) VALUES(?,?,?,?,?,?,?,'TEST',?,'Inventory analytics rollback fixture',?)");$reference=$product;$s->bind_param('iisddddis',$tenant,$product,$type,$quantity,$cost,$value,$cogs,$reference,$date);$s->execute();$s->close();};
    $movement($ids['ACTIVE'],'INITIAL',10,10,0,'2025-08-15 09:00:00');$movement($ids['ACTIVE'],'INVOICE_OUT',-8,10,80,'2026-08-01 09:00:00');
    $movement($ids['SLOW'],'INITIAL',10,10,0,'2025-08-15 09:00:00');$movement($ids['SLOW'],'INVOICE_OUT',-1,10,10,'2026-04-01 09:00:00');
    $movement($ids['DEAD'],'INITIAL',5,10,0,'2025-08-15 09:00:00');
    $report=buildTenantInventoryAnalytics($c,$tenant,'2026-08-11',365,90,180,10);
    inventoryCheck($report['period']===['from'=>'2025-08-12','to'=>'2026-08-11'],'turnover window is inclusive and deterministic',$failures);
    inventoryCheck($report['summary']['products']===3&&$report['summary']['low_stock']===1,'product and reorder-point counts reconcile',$failures);
    inventoryCheck($report['summary']['slow_moving']===1&&$report['summary']['dead_stock']===1,'slow and dead stock are classified independently',$failures);
    inventoryCheck($report['summary']['inventory_value_tnd']==='160.000'&&$report['summary']['cogs_tnd']==='90.000','inventory value and COGS preserve millime totals',$failures);
    inventoryCheck($report['summary']['turnover_ratio']==='1.125'&&$report['summary']['days_inventory_outstanding']==='324.444','turnover and inventory days use average opening and closing value',$failures);
    inventoryCheck(($report['lists']['low_stock'][0]['product_id']??0)===$ids['ACTIVE'],'low-stock list uses the product reorder point',$failures);
    inventoryCheck(($report['lists']['slow_moving'][0]['movement_status']??'')==='SLOW'&&($report['lists']['dead_stock'][0]['movement_status']??'')==='DEAD','risk lists expose their source classification',$failures);
}finally{$c->rollback();}
$empty=buildTenantInventoryAnalytics($c,random_int(800000000,899999999),'2026-08-11',365,90,180,10);
inventoryCheck($empty['summary']['products']===0&&$empty['summary']['inventory_value_tnd']==='0.000','empty tenant inventory state is explicit',$failures);
if($failures!==[])exit(1);echo'Inventory analytics suite passed.'.PHP_EOL;
