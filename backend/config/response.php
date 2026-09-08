<?php

require_once __DIR__ . '/startup.php';
enforceStartupConfiguration();
require_once __DIR__ . '/cors.php';
require_once __DIR__ . '/security_headers.php';
require_once __DIR__ . '/request_limits.php';
applyCors();
applySecurityHeaders();
applyRequestLimits();
header("Content-Type: application/json; charset=UTF-8");

function appRequestId(): string
{
    static $requestId = null;
    if ($requestId !== null) return $requestId;
    $provided = trim((string)($_SERVER['HTTP_X_REQUEST_ID'] ?? ''));
    if (preg_match('/^[A-Za-z0-9._:-]{8,64}$/', $provided)) {
        $requestId = $provided;
    } else {
        $hex = bin2hex(random_bytes(16));
        $requestId = substr($hex,0,8).'-'.substr($hex,8,4).'-4'.substr($hex,13,3)
            .'-'.dechex((hexdec($hex[16]) & 3) | 8).substr($hex,17,3).'-'.substr($hex,20,12);
    }
    header('X-Request-ID: ' . $requestId);
    return $requestId;
}

require_once __DIR__ . '/logger.php';
registerStructuredFatalLogger();
appRequestId();

if (($_SERVER['REQUEST_METHOD'] ?? '') === 'OPTIONS') {
    http_response_code(200);
    exit;
}

function jsonResponse(array $data, int $status = 200): void
{
    if (!array_key_exists('request_id', $data)) $data['request_id'] = appRequestId();
    if ($status >= 400) {
        structuredLog($status >= 500 ? 'ERROR' : 'WARNING', 'HTTP.RESPONSE_ERROR', [
            'status'=>$status,
            'error_code'=>$data['error_code'] ?? null,
            'message'=>$data['message'] ?? 'Request failed',
        ]);
    }
    http_response_code($status);
    echo json_encode($data, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
    exit;
}

function resourceExceptionStatus(Throwable $error, int $default = 400): int
{
    $message = strtolower($error->getMessage());
    return str_contains($message, 'not found') || str_contains($message, 'not allowed') || str_contains($message, 'unauthorized')
        ? 404
        : $default;
}
