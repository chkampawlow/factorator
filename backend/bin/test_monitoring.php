<?php

if (PHP_SAPI !== 'cli') { http_response_code(404); exit; }
require_once __DIR__ . '/../config/response.php';

$_ENV['ERROR_MONITOR_WEBHOOK_URL'] = 'not-a-valid-url';
$started = microtime(true);
$delivered = appSendMonitoringAlert(['level'=>'ERROR','context'=>['password'=>'[REDACTED]']]);
$duration = (microtime(true)-$started)*1000;
$success = $duration < 100;
echo json_encode(['success'=>$success && $delivered === false,'invalid_url_ignored'=>$delivered === false,
    'duration_ms'=>round($duration,3)],JSON_PRETTY_PRINT) . PHP_EOL;
exit($success && $delivered === false ? 0 : 1);
