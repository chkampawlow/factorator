<?php

require_once __DIR__ . '/env.php';

function applySecurityHeaders(): void
{
    header("Content-Security-Policy: default-src 'none'; frame-ancestors 'none'; base-uri 'none'; form-action 'none'");
    header('X-Content-Type-Options: nosniff');
    header('X-Frame-Options: DENY');
    header('Referrer-Policy: no-referrer');
    header('Permissions-Policy: camera=(), microphone=(), geolocation=(), payment=()');
    header('Cross-Origin-Resource-Policy: same-site');

    $environment = strtolower(trim((string)($_ENV['APP_ENV'] ?? getenv('APP_ENV') ?: 'development')));
    $forwardedProto = strtolower(trim(explode(',', (string)($_SERVER['HTTP_X_FORWARDED_PROTO'] ?? ''))[0]));
    $isHttps = (!empty($_SERVER['HTTPS']) && strtolower((string)$_SERVER['HTTPS']) !== 'off')
        || $forwardedProto === 'https';

    if ($environment === 'production' && $isHttps) {
        header('Strict-Transport-Security: max-age=31536000; includeSubDomains');
    }
}
