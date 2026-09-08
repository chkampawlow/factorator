<?php

declare(strict_types=1);

require_once __DIR__.'/../config/response.php';
require_once __DIR__.'/../config/db.php';
require_once __DIR__.'/../auth/auth_required.php';
require_once __DIR__.'/../auth/role_helper.php';
require_once __DIR__.'/exchange_difference_service.php';

try {
    if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'GET') jsonResponse(['success'=>false,'message'=>'Method not allowed.'],405);
    $userId=(int)requireAuth()->id;
    $conn=db();
    requirePermission($conn,$userId,'reports.view');
    $from=(string)($_GET['from']??date('Y-m-01'));
    $to=(string)($_GET['to']??date('Y-m-d'));
    $limit=(int)($_GET['limit']??100);
    jsonResponse(['success'=>true]+buildTenantExchangeDifferenceReport($conn,$userId,$from,$to,$limit));
} catch (InvalidArgumentException $e) {
    jsonResponse(['success'=>false,'message'=>$e->getMessage()],422);
} catch (Throwable $e) {
    jsonResponse(['success'=>false,'message'=>'Could not calculate exchange differences.','error_code'=>'EXCHANGE_DIFFERENCE_REPORT_FAILED'],500);
}
