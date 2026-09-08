<?php

if(PHP_SAPI!=='cli'){http_response_code(404);exit;}
require_once __DIR__.'/../config/db.php';
$conn=db();$tenantId=(int)($argv[1]??32);
$stmt=$conn->prepare("SELECT p.*,s.closing_credit source_closing_credit FROM erp_vat_periods p
    LEFT JOIN erp_vat_periods s ON s.id=p.source_period_id AND s.user_id=p.user_id
    WHERE p.user_id=? ORDER BY p.period_start");$stmt->bind_param('i',$tenantId);$stmt->execute();$rows=$stmt->get_result()->fetch_all(MYSQLI_ASSOC);$stmt->close();
$issues=[];foreach($rows as $row){$available=round((float)$row['opening_credit']+(float)$row['vat_deductible'],3);
    $expectedPayable=round(max(0,(float)$row['vat_collected']-$available),3);$expectedClosing=round(max(0,$available-(float)$row['vat_collected']),3);
    if(abs($expectedPayable-(float)$row['vat_payable'])>=0.0005)$issues[]=$row['period_start'].':payable';
    if(abs($expectedClosing-(float)$row['closing_credit'])>=0.0005)$issues[]=$row['period_start'].':closing_credit';
    if((float)$row['vat_payable']>0.0005&&(float)$row['closing_credit']>0.0005)$issues[]=$row['period_start'].':payable_and_credit';
    if($row['source_period_id']!==null&&abs((float)$row['opening_credit']-(float)$row['source_closing_credit'])>=0.0005)$issues[]=$row['period_start'].':carryforward_mismatch';
}
$success=$issues===[];echo json_encode(['success'=>$success,'tenant_id'=>$tenantId,'periods_checked'=>count($rows),'issues'=>$issues,
    'formula'=>'available=opening+deductible; payable=max(collected-available,0); closing=max(available-collected,0)'],JSON_PRETTY_PRINT|JSON_UNESCAPED_SLASHES).PHP_EOL;exit($success?0:1);
