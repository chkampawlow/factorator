<?php

header('Content-Type: application/json');
require_once __DIR__ . '/../config/response.php';
require_once __DIR__ . '/../config/db.php';
require_once __DIR__ . '/../config/audit_reconstruction.php';
require_once __DIR__ . '/../auth/auth_required.php';
require_once __DIR__ . '/../auth/role_helper.php';
require_once __DIR__ . '/report_error.php';

try{
    $userId=(int)requireAuth()->id;$conn=db();requirePermission($conn,$userId,'reports.view');
    $type=strtoupper(trim((string)($_GET['entity_type']??'')));$id=trim((string)($_GET['entity_id']??''));
    if($type===''||$id===''||strlen($type)>80||strlen($id)>100)throw new InvalidArgumentException('Entity type and ID are required');
    $events=loadAuditEntityEvents($conn,$userId,$type,$id);if(!$events)throw new OutOfBoundsException('No audit events found for this entity');
    $result=reconstructAuditTimeline($events);
    jsonResponse(['success'=>true,'entity_type'=>$type,'entity_id'=>$id,'event_count'=>count($events)]+$result);
}catch(Throwable $e){reportFailureResponse($e,'Could not load the audit timeline.','AUDIT_TIMELINE_LOAD_FAILED');}
