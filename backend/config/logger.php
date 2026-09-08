<?php

function appSetLogContext(?int $tenantId = null, ?int $actorId = null): void
{
    $GLOBALS['app_log_context'] = ['tenant_id' => $tenantId, 'actor_id' => $actorId];
}

function appLogRedact($value, ?string $key = null)
{
    $redactedKeys = [
        'password','password_hash','authorization','token','access_token','refresh_token',
        'two_factor_challenge','code','secret','google2fa_secret','proof_path','attachment_path',
        'email','phone','address','cin','fiscal_id','user_agent','ip','remote_addr',
    ];
    if ($key !== null && in_array(strtolower($key), $redactedKeys, true)) return '[REDACTED]';
    if (is_array($value)) {
        $clean = [];
        foreach ($value as $itemKey => $item) $clean[$itemKey] = appLogRedact($item, (string)$itemKey);
        return $clean;
    }
    if (is_object($value)) return appLogRedact((array)$value, $key);
    if (is_string($value)) {
        $value = preg_replace('/Bearer\s+[A-Za-z0-9._~+\/-]+=*/i', 'Bearer [REDACTED]', $value);
        $value = preg_replace('/[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}/i', '[REDACTED_EMAIL]', $value);
        return mb_substr($value, 0, 2000);
    }
    return $value;
}

function appLogPath(): string
{
    $configured = trim((string)($_ENV['APP_LOG_PATH'] ?? ''));
    if ($configured !== '') return $configured;
    $filename = PHP_SAPI === 'cli' ? 'app-cli.jsonl' : 'app.jsonl';
    return dirname(__DIR__) . '/storage/logs/' . $filename;
}

function appRotateLog(string $path): void
{
    $maxBytes = max(1048576, (int)($_ENV['APP_LOG_MAX_BYTES'] ?? 10485760));
    clearstatcache(true, $path);
    if (!is_file($path) || filesize($path) < $maxBytes) return;
    @rename($path, $path . '.' . gmdate('Ymd-His'));
}

function structuredLog(string $level, string $event, array $context = []): void
{
    try {
        $path = appLogPath();
        $directory = dirname($path);
        if (!is_dir($directory) && !mkdir($directory, 0700, true) && !is_dir($directory)) {
            throw new RuntimeException('Could not create log directory');
        }
        appRotateLog($path);
        $identity = $GLOBALS['app_log_context'] ?? ['tenant_id'=>null,'actor_id'=>null];
        $uri = (string)($_SERVER['REQUEST_URI'] ?? 'CLI');
        $record = [
            'timestamp' => (new DateTimeImmutable('now', new DateTimeZone('UTC')))->format('Y-m-d\TH:i:s.u\Z'),
            'level' => strtoupper($level),
            'event' => $event,
            'request_id' => function_exists('appRequestId') ? appRequestId() : null,
            'method' => (string)($_SERVER['REQUEST_METHOD'] ?? 'CLI'),
            'endpoint' => parse_url($uri, PHP_URL_PATH) ?: 'CLI',
            'tenant_id' => $identity['tenant_id'] ?? null,
            'actor_id' => $identity['actor_id'] ?? null,
            'context' => appLogRedact($context),
        ];
        $line = json_encode($record, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES | JSON_INVALID_UTF8_SUBSTITUTE) . PHP_EOL;
        file_put_contents($path, $line, FILE_APPEND | LOCK_EX);
        @chmod($path, 0600);
        appSendMonitoringAlert($record);
    } catch (Throwable $loggingError) {
        error_log('[structured-logger-failed] ' . $loggingError->getMessage());
    }
}

function appSendMonitoringAlert(array $record): bool
{
    $level = strtoupper((string)($record['level'] ?? 'INFO'));
    if (!in_array($level, ['ERROR','CRITICAL'], true)) return false;
    $url = trim((string)($_ENV['ERROR_MONITOR_WEBHOOK_URL'] ?? ''));
    if ($url === '' || !filter_var($url, FILTER_VALIDATE_URL)) return false;
    $scheme = strtolower((string)parse_url($url, PHP_URL_SCHEME));
    if (!in_array($scheme, ['https','http'], true) || !function_exists('curl_init')) return false;

    $payload = json_encode(['application'=>'el-fatoura','event'=>$record],
        JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES | JSON_INVALID_UTF8_SUBSTITUTE);
    $headers = ['Content-Type: application/json','User-Agent: El-Fatoura-Monitor/1.0'];
    $secret = trim((string)($_ENV['ERROR_MONITOR_WEBHOOK_SECRET'] ?? ''));
    if ($secret !== '') $headers[] = 'X-El-Fatoura-Signature: sha256=' . hash_hmac('sha256', $payload, $secret);
    $curl = curl_init($url);
    curl_setopt_array($curl, [
        CURLOPT_POST=>true, CURLOPT_POSTFIELDS=>$payload, CURLOPT_HTTPHEADER=>$headers,
        CURLOPT_RETURNTRANSFER=>false, CURLOPT_CONNECTTIMEOUT_MS=>300, CURLOPT_TIMEOUT_MS=>800,
        CURLOPT_FOLLOWLOCATION=>false, CURLOPT_MAXREDIRS=>0,
        CURLOPT_PROTOCOLS=>CURLPROTO_HTTP|CURLPROTO_HTTPS,
        CURLOPT_REDIR_PROTOCOLS=>CURLPROTO_HTTP|CURLPROTO_HTTPS,
        CURLOPT_WRITEFUNCTION=>static fn($handle,string $chunk): int => strlen($chunk),
    ]);
    $sent = curl_exec($curl);
    $status = (int)curl_getinfo($curl, CURLINFO_HTTP_CODE);
    curl_close($curl);
    return $sent !== false && $status >= 200 && $status < 300;
}

function registerStructuredFatalLogger(): void
{
    register_shutdown_function(static function (): void {
        $error = error_get_last();
        if (!$error || !in_array($error['type'], [E_ERROR,E_PARSE,E_CORE_ERROR,E_COMPILE_ERROR], true)) return;
        structuredLog('CRITICAL', 'PHP.FATAL', [
            'error_type'=>$error['type'], 'message'=>$error['message'],
            'file'=>basename($error['file']), 'line'=>$error['line'],
        ]);
    });
}
