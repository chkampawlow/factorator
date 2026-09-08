<?php

declare(strict_types=1);

require_once __DIR__ . '/../config/response.php';
require_once __DIR__ . '/../config/db.php';
require_once __DIR__ . '/../config/upload.php';
require_once __DIR__ . '/../config/audit.php';
require_once __DIR__ . '/../auth/auth_required.php';
require_once __DIR__ . '/../auth/role_helper.php';

try {
    $auth = requireAuth();
    $userId = authTenantId($auth);
    $actorId = authActorId($auth);
    $conn = db();
    requirePermission($conn, $userId, 'reports.view');
    $jobId = (int)($_GET['id'] ?? 0);
    if ($jobId <= 0) throw new InvalidArgumentException('Invalid job id.');

    $stmt = $conn->prepare("SELECT job_type,status,result_json FROM erp_background_jobs WHERE id=? AND user_id=? LIMIT 1");
    $stmt->bind_param('ii', $jobId, $userId);
    $stmt->execute();
    $job = $stmt->get_result()->fetch_assoc();
    $stmt->close();
    if (!$job || (string)$job['job_type'] !== 'REPORT_EXPORT') throw new RuntimeException('Report export not found.');
    if ((string)$job['status'] !== 'COMPLETED') throw new LogicException('Report export is not ready.');
    $result = json_decode((string)$job['result_json'], true);
    if (!is_array($result)) throw new RuntimeException('Report export metadata is invalid.');

    $relativePath = trim(str_replace('\\', '/', (string)($result['storage_path'] ?? '')), '/');
    if (!preg_match('#^jobs/' . $userId . '/exports/[a-f0-9]{48}\.csv$#', $relativePath)) {
        throw new RuntimeException('Report export path is invalid.');
    }
    $absolutePath = privateStorageRoot() . DIRECTORY_SEPARATOR . str_replace('/', DIRECTORY_SEPARATOR, $relativePath);
    if (!is_file($absolutePath)) throw new RuntimeException('Report export file is no longer available.');
    $size = filesize($absolutePath);
    if ($size === false || $size !== (int)($result['size'] ?? -1) || !hash_equals((string)($result['sha256'] ?? ''), hash_file('sha256', $absolutePath))) {
        throw new RuntimeException('Report export integrity check failed.');
    }
    $filename = preg_replace('/[^A-Za-z0-9._-]/', '_', basename((string)($result['filename'] ?? 'report.csv'))) ?: 'report.csv';
    auditLog($conn, $userId, $actorId, 'REPORT.EXPORT_DOWNLOADED', 'BACKGROUND_JOB', $jobId, null, [
        'filename' => $filename,
        'row_count' => (int)($result['row_count'] ?? 0),
    ]);
    header('Content-Type: text/csv; charset=utf-8');
    header('Content-Disposition: attachment; filename="' . $filename . '"');
    header('Content-Length: ' . $size);
    header('Cache-Control: private, no-store');
    readfile($absolutePath);
} catch (InvalidArgumentException $e) {
    jsonResponse(['success'=>false,'message'=>$e->getMessage()], 422);
} catch (LogicException $e) {
    jsonResponse(['success'=>false,'message'=>$e->getMessage()], 409);
} catch (RuntimeException $e) {
    jsonResponse(['success'=>false,'message'=>$e->getMessage()], 404);
} catch (Throwable $e) {
    jsonResponse(['success'=>false,'message'=>'Could not download the report export.','error_code'=>'EXPORT_DOWNLOAD_FAILED'], 500);
}
