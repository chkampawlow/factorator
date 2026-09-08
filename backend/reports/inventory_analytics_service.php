<?php

declare(strict_types=1);

function validateInventoryAnalyticsInput(string $asOf, int $windowDays, int $slowDays, int $deadDays): void
{
    if (!preg_match('/^\d{4}-\d{2}-\d{2}$/', $asOf)) throw new InvalidArgumentException('Invalid inventory analysis date.');
    if ($windowDays < 1 || $windowDays > 1095) throw new InvalidArgumentException('Inventory turnover window must be between 1 and 1095 days.');
    if ($slowDays < 1 || $deadDays <= $slowDays || $deadDays > 3650) throw new InvalidArgumentException('Dead-stock days must be greater than slow-moving days.');
}

function inventoryAnalyticsQuery(mysqli $conn, string $sql, string $types, array $args): array
{
    $stmt=$conn->prepare($sql);$stmt->bind_param($types,...$args);$stmt->execute();$rows=$stmt->get_result()->fetch_all(MYSQLI_ASSOC);$stmt->close();return $rows;
}

function inventoryAnalyticsAmount(float $value): string
{
    return number_format(round($value,3),3,'.','');
}

function inventoryAnalyticsFactsSql(int $userId,string $asOf, string $from, int $windowDays, int $slowDays, int $deadDays): array
{
    $stock="SELECT product_id,
      ROUND(SUM(CASE WHEN created_at<? THEN quantity ELSE 0 END),3) opening_quantity,
      ROUND(SUM(quantity),3) closing_quantity,
      ROUND(SUM(CASE WHEN created_at>=? AND created_at<DATE_ADD(?,INTERVAL 1 DAY) AND quantity<0 THEN ABS(quantity) ELSE 0 END),3) outbound_quantity,
      ROUND(SUM(CASE WHEN created_at>=? AND created_at<DATE_ADD(?,INTERVAL 1 DAY) THEN cogs_value ELSE 0 END),3) cogs_tnd,
      MIN(DATE(created_at)) first_movement_date,
      MAX(CASE WHEN quantity<0 THEN DATE(created_at) END) last_outbound_date
      FROM product_stock_movements WHERE user_id=? AND created_at<DATE_ADD(?,INTERVAL 1 DAY) GROUP BY product_id";
    $base="SELECT p.id product_id,p.code,p.name,p.category,p.unit,p.average_cost,p.reorder_point,p.stock_quantity stored_quantity,
      COALESCE(s.opening_quantity,0) opening_quantity,COALESCE(s.closing_quantity,0) closing_quantity,
      COALESCE(s.outbound_quantity,0) outbound_quantity,COALESCE(s.cogs_tnd,0) cogs_tnd,
      s.first_movement_date,s.last_outbound_date,
      CASE WHEN s.first_movement_date IS NULL THEN NULL ELSE DATEDIFF('$asOf',COALESCE(s.last_outbound_date,s.first_movement_date)) END days_without_outbound
      FROM products p LEFT JOIN($stock)s ON s.product_id=p.id WHERE p.user_id=? AND p.item_type='PRODUCT'";
    $metrics="SELECT base.*,
      ROUND(GREATEST((opening_quantity+closing_quantity)/2,0),3) average_quantity,
      ROUND(GREATEST(closing_quantity,0)*average_cost,3) inventory_value_tnd,
      ROUND(GREATEST((opening_quantity+closing_quantity)/2,0)*average_cost,3) average_inventory_value_tnd,
      ROUND(CASE WHEN GREATEST((opening_quantity+closing_quantity)/2,0)*average_cost<0.0005 THEN 0 ELSE cogs_tnd/(GREATEST((opening_quantity+closing_quantity)/2,0)*average_cost) END,3) turnover_ratio,
      ROUND(CASE WHEN cogs_tnd<0.0005 THEN 0 ELSE $windowDays/(cogs_tnd/NULLIF(GREATEST((opening_quantity+closing_quantity)/2,0)*average_cost,0)) END,3) days_inventory_outstanding,
      (closing_quantity<reorder_point) low_stock,
      (closing_quantity>0 AND average_cost<0.0000005) zero_cost,
      (outbound_quantity>0 AND average_cost>=0.0000005 AND cogs_tnd<0.0005) missing_cogs,
      (ABS(stored_quantity-closing_quantity)>=0.0005) ledger_discrepancy
      FROM($base)base";
    $facts="SELECT metrics.*,
      CASE
        WHEN closing_quantity<0 THEN 'NEGATIVE_STOCK'
        WHEN closing_quantity<=0 THEN 'OUT_OF_STOCK'
        WHEN days_without_outbound>=$deadDays THEN 'DEAD'
        WHEN first_movement_date IS NULL OR (last_outbound_date IS NULL AND days_without_outbound<$slowDays) THEN 'NEW'
        WHEN days_without_outbound>=$slowDays OR (cogs_tnd>0 AND average_inventory_value_tnd>0 AND turnover_ratio<1) THEN 'SLOW'
        ELSE 'ACTIVE'
      END movement_status
      FROM($metrics)metrics";
    return [$facts,'sssssisi',[$from,$from,$asOf,$from,$asOf,$userId,$asOf,$userId]];
}

function normalizeInventoryAnalyticsRow(array $row): array
{
    foreach(['average_cost','reorder_point','stored_quantity','opening_quantity','closing_quantity','outbound_quantity','cogs_tnd','average_quantity','inventory_value_tnd','average_inventory_value_tnd','turnover_ratio','days_inventory_outstanding'] as $key)$row[$key]=inventoryAnalyticsAmount((float)($row[$key]??0));
    foreach(['product_id','all_rank','status_rank','low_rank'] as $key)if(array_key_exists($key,$row))$row[$key]=(int)$row[$key];
    if(array_key_exists('days_without_outbound',$row))$row['days_without_outbound']=$row['days_without_outbound']===null?null:(int)$row['days_without_outbound'];
    foreach(['low_stock','zero_cost','missing_cogs','ledger_discrepancy'] as $key)$row[$key]=(bool)($row[$key]??false);
    return $row;
}

function normalizeInventoryAnalyticsSummary(array $row,int $windowDays):array
{
    foreach(['stock_units','inventory_value_tnd','average_inventory_value_tnd','cogs_tnd','outbound_quantity','turnover_ratio','days_inventory_outstanding'] as $key)$row[$key]=inventoryAnalyticsAmount((float)($row[$key]??0));
    foreach(['products','low_stock','slow_moving','dead_stock','out_of_stock','negative_stock','zero_cost','missing_cogs','ledger_discrepancies'] as $key)$row[$key]=(int)($row[$key]??0);
    $row['window_days']=$windowDays;return$row;
}

function buildTenantInventoryAnalytics(mysqli $conn,int $userId,string $asOf,int $windowDays=365,int $slowDays=90,int $deadDays=180,int $limit=100):array
{
    if($userId<=0)throw new InvalidArgumentException('Invalid inventory analytics tenant.');
    validateInventoryAnalyticsInput($asOf,$windowDays,$slowDays,$deadDays);$limit=min(200,max(1,$limit));
    $asOfDate=new DateTimeImmutable($asOf);$from=$asOfDate->sub(new DateInterval('P'.($windowDays-1).'D'))->format('Y-m-d');
    [$facts,$types,$args]=inventoryAnalyticsFactsSql($userId,$asOf,$from,$windowDays,$slowDays,$deadDays);
    $summarySql="SELECT COUNT(*) products,ROUND(COALESCE(SUM(closing_quantity),0),3) stock_units,
      ROUND(COALESCE(SUM(inventory_value_tnd),0),3) inventory_value_tnd,ROUND(COALESCE(SUM(average_inventory_value_tnd),0),3) average_inventory_value_tnd,
      ROUND(COALESCE(SUM(cogs_tnd),0),3) cogs_tnd,ROUND(COALESCE(SUM(outbound_quantity),0),3) outbound_quantity,
      ROUND(CASE WHEN SUM(average_inventory_value_tnd)<0.0005 THEN 0 ELSE SUM(cogs_tnd)/SUM(average_inventory_value_tnd) END,3) turnover_ratio,
      ROUND(CASE WHEN SUM(cogs_tnd)<0.0005 THEN 0 ELSE $windowDays/(SUM(cogs_tnd)/NULLIF(SUM(average_inventory_value_tnd),0)) END,3) days_inventory_outstanding,
      SUM(low_stock=1) low_stock,SUM(movement_status='SLOW') slow_moving,SUM(movement_status='DEAD') dead_stock,
      SUM(movement_status='OUT_OF_STOCK') out_of_stock,SUM(movement_status='NEGATIVE_STOCK') negative_stock,
      SUM(zero_cost=1) zero_cost,SUM(missing_cogs=1) missing_cogs,SUM(ledger_discrepancy=1) ledger_discrepancies FROM($facts)facts";
    $summary=normalizeInventoryAnalyticsSummary(inventoryAnalyticsQuery($conn,$summarySql,$types,$args)[0]??[],$windowDays);
    $ranked="SELECT facts.*,
      ROW_NUMBER() OVER(ORDER BY inventory_value_tnd DESC,product_id) all_rank,
      ROW_NUMBER() OVER(PARTITION BY movement_status ORDER BY inventory_value_tnd DESC,product_id) status_rank,
      ROW_NUMBER() OVER(PARTITION BY low_stock ORDER BY (reorder_point-closing_quantity) DESC,inventory_value_tnd DESC,product_id) low_rank
      FROM($facts)facts";
    $rows=inventoryAnalyticsQuery($conn,"SELECT * FROM($ranked)ranked WHERE all_rank<=? OR (low_stock=1 AND low_rank<=?) OR (movement_status IN('SLOW','DEAD') AND status_rank<=?) ORDER BY all_rank",$types.'iii',[...$args,$limit,$limit,$limit]);
    $buckets=['products'=>[],'low_stock'=>[],'slow_moving'=>[],'dead_stock'=>[]];
    foreach($rows as $raw){$row=normalizeInventoryAnalyticsRow($raw);if($row['all_rank']<=$limit)$buckets['products'][]=$row;if($row['low_stock']&&$row['low_rank']<=$limit)$buckets['low_stock'][]=$row;if($row['movement_status']==='SLOW'&&$row['status_rank']<=$limit)$buckets['slow_moving'][]=$row;if($row['movement_status']==='DEAD'&&$row['status_rank']<=$limit)$buckets['dead_stock'][]=$row;}
    usort($buckets['products'],static fn(array $a,array $b):int=>$a['all_rank']<=>$b['all_rank']);
    usort($buckets['low_stock'],static fn(array $a,array $b):int=>$a['low_rank']<=>$b['low_rank']);
    usort($buckets['slow_moving'],static fn(array $a,array $b):int=>$a['status_rank']<=>$b['status_rank']);
    usort($buckets['dead_stock'],static fn(array $a,array $b):int=>$a['status_rank']<=>$b['status_rank']);
    return['period'=>['from'=>$from,'to'=>$asOf],'thresholds'=>['slow_days'=>$slowDays,'dead_days'=>$deadDays],'valuation_method'=>'WEIGHTED_AVERAGE_CURRENT_COST','summary'=>$summary,'lists'=>$buckets,'row_limit'=>$limit,'cost_data_complete'=>$summary['zero_cost']===0&&$summary['missing_cogs']===0];
}
