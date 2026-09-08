<?php

header('Content-Type: application/json');
require_once __DIR__.'/../config/response.php';require_once __DIR__.'/../config/db.php';require_once __DIR__.'/../config/audit.php';
require_once __DIR__.'/../auth/auth_required.php';require_once __DIR__.'/../auth/role_helper.php';require_once __DIR__.'/vat_period_service.php';
require_once __DIR__.'/filing_archive_service.php';require_once __DIR__.'/report_error.php';
try{
    if($_SERVER['REQUEST_METHOD']!=='POST')jsonResponse(['success'=>false,'message'=>'Method not allowed'],405);
    $auth=requireAuth();$userId=authTenantId($auth);$actorId=authActorId($auth);$data=json_decode(file_get_contents('php://input'),true)?:[];$month=trim((string)($data['month']??''));
    $target=strtoupper(trim((string)($data['status']??'DRAFT')));if(!in_array($target,['DRAFT','REVIEWED','LOCKED','FILED'],true))throw new InvalidArgumentException('Invalid VAT period status');
    $opening=round((float)($data['opening_credit']??0),3);if($opening<0)throw new InvalidArgumentException('Opening VAT credit cannot be negative');
    [$start,$end]=vatMonthDates($month);$conn=db();requirePermission($conn,$userId,'reports.view');$conn->begin_transaction();
    $stmt=$conn->prepare('SELECT * FROM erp_vat_periods WHERE user_id=? AND period_start=? AND period_end=? FOR UPDATE');$stmt->bind_param('iss',$userId,$start,$end);$stmt->execute();$existing=$stmt->get_result()->fetch_assoc();$stmt->close();
    if($existing&&($existing['status']==='FILED'||($existing['status']==='LOCKED'&&$target!=='FILED')))throw new DomainException('Locked or filed VAT periods are immutable');
    $current=$existing['status']??null;$allowed=[null=>['DRAFT'], 'DRAFT'=>['DRAFT','REVIEWED'], 'REVIEWED'=>['REVIEWED','LOCKED'], 'LOCKED'=>['FILED'], 'FILED'=>[]];
    if(!in_array($target,$allowed[$current]??[],true))throw new DomainException('Invalid VAT period status transition');
    if($existing&&$existing['status']==='LOCKED'&&$target==='FILED'){
        $calculation=['period_start'=>$start,'period_end'=>$end,'opening_credit'=>(float)$existing['opening_credit'],
            'vat_collected'=>(float)$existing['vat_collected'],'vat_deductible'=>(float)$existing['vat_deductible'],
            'available_credit'=>(float)$existing['opening_credit']+(float)$existing['vat_deductible'],
            'vat_payable'=>(float)$existing['vat_payable'],'closing_credit'=>(float)$existing['closing_credit'],
            'source_period_id'=>$existing['source_period_id']===null?null:(int)$existing['source_period_id']];
    }else{$calculation=calculateVatPeriod($conn,$userId,$start,$end,$opening);}
    if($calculation['source_period_id']!==null&&$opening>0.0005)throw new DomainException('Opening credit is inherited from the previous reviewed period and cannot be overridden');
    $source=$calculation['source_period_id'];$reviewed=$target==='REVIEWED'?$actorId:null;$locked=$target==='LOCKED'?$actorId:null;$filed=$target==='FILED'?$actorId:null;
    if($existing){$id=(int)$existing['id'];$stmt=$conn->prepare("UPDATE erp_vat_periods SET opening_credit=?,vat_collected=?,vat_deductible=?,vat_payable=?,closing_credit=?,status=?,source_period_id=?,reviewed_by=COALESCE(reviewed_by,?),reviewed_at=IF(?='REVIEWED',COALESCE(reviewed_at,NOW()),reviewed_at),locked_by=COALESCE(locked_by,?),locked_at=IF(?='LOCKED',COALESCE(locked_at,NOW()),locked_at),filed_by=COALESCE(filed_by,?),filed_at=IF(?='FILED',COALESCE(filed_at,NOW()),filed_at) WHERE id=? AND user_id=?");$stmt->bind_param('dddddsiisisisii',$calculation['opening_credit'],$calculation['vat_collected'],$calculation['vat_deductible'],$calculation['vat_payable'],$calculation['closing_credit'],$target,$source,$reviewed,$target,$locked,$target,$filed,$target,$id,$userId);
    }else{$stmt=$conn->prepare("INSERT INTO erp_vat_periods(user_id,period_start,period_end,opening_credit,vat_collected,vat_deductible,vat_payable,closing_credit,status,source_period_id,reviewed_by,reviewed_at) VALUES(?,?,?,?,?,?,?,?,?,?,?,IF(?='REVIEWED',NOW(),NULL))");$stmt->bind_param('issdddddsiis',$userId,$start,$end,$calculation['opening_credit'],$calculation['vat_collected'],$calculation['vat_deductible'],$calculation['vat_payable'],$calculation['closing_credit'],$target,$source,$reviewed,$target);}
    $stmt->execute();if(!$existing)$id=(int)$stmt->insert_id;$stmt->close();
    $archive=null;if($target==='FILED')$archive=createFilingArchive($conn,$userId,'VAT',$id,$actorId);
    auditLog($conn,$userId,$actorId,'VAT_PERIOD.'.$target,'VAT_PERIOD',$id,$existing?:null,$calculation+['status'=>$target,'filing_archive'=>$archive]);$conn->commit();
    jsonResponse(['success'=>true,'id'=>$id,'status'=>$target,'filing_archive'=>$archive]+$calculation);
}catch(Throwable $e){if(isset($conn)){try{$conn->rollback();}catch(Throwable $ignored){}}reportFailureResponse($e,'Could not save the VAT period.','VAT_PERIOD_SAVE_FAILED');}
