<?php

if(PHP_SAPI!=='cli'){http_response_code(404);exit;}
require_once __DIR__.'/../config/db.php';
require_once __DIR__.'/../config/audit.php';
require_once __DIR__.'/../config/audit_reconstruction.php';

$conn=db();$tenantId=(int)$conn->query("SELECT id FROM users WHERE account_status='ACTIVE' ORDER BY id LIMIT 1")->fetch_row()[0];
$entityId='rollback-'.bin2hex(random_bytes(8));$conn->begin_transaction();
try{
    auditLog($conn,$tenantId,$tenantId,'PAYMENT.POSTED','RECONSTRUCTION_TEST',$entityId,null,
        ['invoice_id'=>9001,'amount'=>'137.425','status'=>'POSTED','settlement'=>['paid'=>'137.425','remaining'=>'862.575']],'CLI_TEST');
    auditLog($conn,$tenantId,$tenantId,'PAYMENT.VOIDED','RECONSTRUCTION_TEST',$entityId,
        ['status'=>'POSTED','settlement'=>['paid'=>'137.425','remaining'=>'862.575']],
        ['status'=>'VOID','void_reason'=>'Duplicate bank entry','settlement'=>['paid'=>'0.000','remaining'=>'1000.000']],'CLI_TEST');
    auditLog($conn,$tenantId,$tenantId,'PAYMENT.REPOSTED','RECONSTRUCTION_TEST',$entityId,
        ['status'=>'VOID','settlement'=>['paid'=>'0.000','remaining'=>'1000.000']],
        ['status'=>'POSTED','amount'=>'137.425','settlement'=>['paid'=>'137.425','remaining'=>'862.575']],'CLI_TEST');
    $events=loadAuditEntityEvents($conn,$tenantId,'RECONSTRUCTION_TEST',$entityId);$result=reconstructAuditTimeline($events);
    $expected=['invoice_id'=>9001,'amount'=>'137.425','status'=>'POSTED','settlement'=>['paid'=>'137.425','remaining'=>'862.575'],'void_reason'=>'Duplicate bank entry'];
    $stateMatches=$result['current_state']==$expected;
    $brokenEvents=$events;$brokenEvents[2]['before_values']['settlement']['paid']='999.000';
    $brokenChainDetected=!reconstructAuditTimeline($brokenEvents)['reconstructable'];
    $persisted=(int)$conn->query("SELECT COUNT(*) FROM app_audit_log WHERE entity_type='RECONSTRUCTION_TEST' AND entity_id='".$conn->real_escape_string($entityId)."'")->fetch_row()[0];
    $conn->rollback();$remaining=(int)$conn->query("SELECT COUNT(*) FROM app_audit_log WHERE entity_type='RECONSTRUCTION_TEST' AND entity_id='".$conn->real_escape_string($entityId)."'")->fetch_row()[0];
    $criticalActions=['PAYMENT.POSTED','PAYMENT.VOIDED','WITHHOLDING.RECORDED','STOCK.MOVEMENT_RECORDED','INVOICE.VALIDATED','INVOICE.CANCELLED','USER.ROLE_CHANGED','TENANT.ARCHIVED'];
    $coverage=[];foreach($criticalActions as $action){$files=[];$iterator=new RecursiveIteratorIterator(new RecursiveDirectoryIterator(dirname(__DIR__),FilesystemIterator::SKIP_DOTS),RecursiveIteratorIterator::LEAVES_ONLY,RecursiveIteratorIterator::CATCH_GET_CHILD);foreach($iterator as $file){$relative=str_replace(dirname(__DIR__).'/', '',$file->getPathname());if($file->getExtension()==='php'&&!str_starts_with($relative,'bin/')&&str_contains((string)file_get_contents($file->getPathname()),$action))$files[]=$relative;}$coverage[$action]=$files;}
    $missing=array_keys(array_filter($coverage,fn($files)=>$files===[]));$success=$result['reconstructable']&&$brokenChainDetected&&$stateMatches&&$persisted===3&&$remaining===0&&$missing===[];
    echo json_encode(['success'=>$success,'events_replayed'=>$persisted,'rollback_left_records'=>$remaining,'state_matches'=>$stateMatches,'broken_chain_detected'=>$brokenChainDetected,'issues'=>$result['issues'],'critical_action_coverage'=>$coverage],JSON_PRETTY_PRINT|JSON_UNESCAPED_SLASHES).PHP_EOL;exit($success?0:1);
}catch(Throwable $e){try{$conn->rollback();}catch(Throwable $ignored){}throw $e;}
