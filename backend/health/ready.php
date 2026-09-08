<?php

header('Content-Type: application/json; charset=UTF-8');
header('Cache-Control: no-store');

require_once __DIR__ . '/../config/response.php';
require_once __DIR__ . '/../config/db.php';

$checks = ['database'=>false,'schema'=>false,'logging'=>false];
try {
    $conn = db();
    $checks['database'] = (int)$conn->query('SELECT 1')->fetch_row()[0] === 1;
    $requiredTables = ['users','erp_invoices','product_stock_movements','app_audit_log','schema_migrations'];
    $quoted = "'" . implode("','", array_map([$conn,'real_escape_string'],$requiredTables)) . "'";
    $tableCount = (int)$conn->query("SELECT COUNT(*) FROM information_schema.TABLES
        WHERE TABLE_SCHEMA=(SELECT DATABASE()) AND TABLE_NAME IN ($quoted)")->fetch_row()[0];
    if ($tableCount === 0) {
        $schema = $conn->real_escape_string((string)$conn->query('SELECT DATABASE()')->fetch_row()[0]);
        $tableCount = (int)$conn->query("SELECT COUNT(*) FROM information_schema.TABLES
            WHERE TABLE_SCHEMA='$schema' AND TABLE_NAME IN ($quoted)")->fetch_row()[0];
    }
    $checks['schema'] = $tableCount === count($requiredTables);

    $logPath = appLogPath();
    $logDirectory = dirname($logPath);
    $checks['logging'] = (is_dir($logDirectory) && is_writable($logDirectory))
        || (!is_dir($logDirectory) && is_writable(dirname($logDirectory)));
} catch (Throwable $e) {
    structuredLog('ERROR','HEALTH.READINESS_FAILED',['exception'=>get_class($e),'message'=>$e->getMessage()]);
}

$ready = !in_array(false,$checks,true);
http_response_code($ready ? 200 : 503);
echo json_encode([
    'status'=>$ready ? 'READY' : 'NOT_READY',
    'service'=>'el-fatoura-api',
    'checks'=>$checks,
    'request_id'=>appRequestId(),
    'timestamp'=>(new DateTimeImmutable('now',new DateTimeZone('UTC')))->format(DateTimeInterface::ATOM),
], JSON_UNESCAPED_SLASHES);
