<?php

if (PHP_SAPI !== 'cli') { http_response_code(404); exit; }

$path = sys_get_temp_dir() . '/el-fatoura-structured-log-' . bin2hex(random_bytes(6)) . '.jsonl';
$_ENV['APP_LOG_PATH'] = $path;
require_once __DIR__ . '/../config/response.php';

appSetLogContext(17, 23);
structuredLog('ERROR', 'TEST.REDACTION', [
    'password'=>'top-secret-password',
    'access_token'=>'secret-token',
    'email'=>'person@example.com',
    'message'=>'Login for person@example.com used Bearer abc.def.ghi',
    'safe_value'=>'visible',
]);

$raw = (string)file_get_contents($path);
$record = json_decode(trim($raw), true);
$forbidden = ['top-secret-password','secret-token','person@example.com','abc.def.ghi'];
$leaks = array_values(array_filter($forbidden, fn($secret) => str_contains($raw, $secret)));
$success = is_array($record) && $leaks === []
    && ($record['request_id'] ?? '') !== ''
    && ($record['tenant_id'] ?? null) === 17
    && ($record['actor_id'] ?? null) === 23
    && ($record['context']['safe_value'] ?? null) === 'visible';

@unlink($path);
echo json_encode(['success'=>$success,'leaks'=>$leaks,'record'=>$record],
    JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES) . PHP_EOL;
exit($success ? 0 : 1);
