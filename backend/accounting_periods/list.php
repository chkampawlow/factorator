<?php
header('Content-Type: application/json');
require_once __DIR__ . '/../config/response.php';
require_once __DIR__ . '/../config/db.php';
require_once __DIR__ . '/../auth/auth_required.php';
require_once __DIR__ . '/../auth/role_helper.php';



try {
    if ($_SERVER['REQUEST_METHOD'] !== 'GET') jsonResponse(['success'=>false,'message'=>'Method not allowed'],405);
    $userId=(int)requireAuth()->id; $conn=db(); requirePermission($conn,$userId,'accounting.periods.manage');
    $stmt=$conn->prepare("SELECT p.id,p.period_start,p.period_end,p.status,p.reviewed_by,p.reviewed_at,p.locked_by,p.locked_at,p.filed_by,p.filed_at,p.created_at,p.updated_at,COALESCE(s.snapshots,0) snapshots,s.latest_snapshot_sha256 FROM erp_accounting_periods p LEFT JOIN(SELECT period_id,COUNT(*) snapshots,SUBSTRING_INDEX(GROUP_CONCAT(snapshot_sha256 ORDER BY version DESC),',',1) latest_snapshot_sha256 FROM erp_accounting_period_snapshots GROUP BY period_id)s ON s.period_id=p.id WHERE p.user_id=? ORDER BY p.period_start DESC");
    $stmt->bind_param('i',$userId); $stmt->execute(); $rows=$stmt->get_result()->fetch_all(MYSQLI_ASSOC); $stmt->close();
    jsonResponse(['success'=>true,'data'=>$rows]);
} catch(Throwable $e) { jsonResponse(['success'=>false,'message'=>$e->getMessage()],400); }
