<?php

if (PHP_SAPI !== 'cli') { http_response_code(404); exit; }
require_once __DIR__ . '/../config/env.php';
loadEnv(__DIR__ . '/../.env');
require_once __DIR__ . '/../config/logger.php';

$url = trim((string)($argv[1] ?? ($_ENV['UPTIME_READY_URL'] ?? '')));
if ($url === '' || !filter_var($url,FILTER_VALIDATE_URL)) {
    fwrite(STDERR,"UPTIME_READY_URL is missing or invalid\n");
    exit(2);
}
$curl = curl_init($url);
$body='';
curl_setopt_array($curl,[CURLOPT_RETURNTRANSFER=>false,CURLOPT_CONNECTTIMEOUT=>3,
    CURLOPT_TIMEOUT=>8,CURLOPT_FOLLOWLOCATION=>false,CURLOPT_HTTPHEADER=>['Accept: application/json'],
    CURLOPT_PROTOCOLS=>CURLPROTO_HTTP|CURLPROTO_HTTPS,CURLOPT_REDIR_PROTOCOLS=>CURLPROTO_HTTP|CURLPROTO_HTTPS,
    CURLOPT_WRITEFUNCTION=>static function($handle,string $chunk)use(&$body):int{
        if(strlen($body)+strlen($chunk)>1024*1024)return 0;$body.=$chunk;return strlen($chunk);
    }]);
$started = microtime(true);
$completed = curl_exec($curl);
$error = curl_error($curl);
$status = (int)curl_getinfo($curl,CURLINFO_HTTP_CODE);
curl_close($curl);
$duration = round((microtime(true)-$started)*1000,1);
$decoded = $completed !== false ? json_decode($body,true) : null;
$healthy = $status===200 && is_array($decoded) && ($decoded['status']??'')==='READY';
if(!$healthy)structuredLog('ERROR','UPTIME.CHECK_FAILED',['status_code'=>$status,'duration_ms'=>$duration,
    'service_status'=>$decoded['status']??null,'transport_error'=>$error ?: null]);
echo json_encode(['success'=>$healthy,'status_code'=>$status,'duration_ms'=>$duration,
    'service_status'=>$decoded['status']??null,'error'=>$error ?: null],
    JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES) . PHP_EOL;
exit($healthy ? 0 : 1);
