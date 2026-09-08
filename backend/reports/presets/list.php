<?php
declare(strict_types=1);header('Content-Type: application/json');
require_once __DIR__.'/../../config/response.php';require_once __DIR__.'/../../config/db.php';require_once __DIR__.'/../../auth/auth_required.php';require_once __DIR__.'/../../auth/role_helper.php';require_once __DIR__.'/../report_preset_service.php';
try{if(($_SERVER['REQUEST_METHOD']??'')!=='GET')jsonResponse(['success'=>false,'message'=>'Method not allowed.'],405);$uid=(int)requireAuth()->id;$conn=db();requirePermission($conn,$uid,'reports.view');jsonResponse(['success'=>true,'data'=>listReportPresets($conn,$uid)]);}catch(Throwable $e){jsonResponse(['success'=>false,'message'=>'Could not load report presets.','error_code'=>'REPORT_PRESET_LIST_FAILED'],500);}
