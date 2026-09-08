<?php

function authCookieSecure(): bool
{
    $forwardedProto = strtolower(trim(explode(',', (string)($_SERVER['HTTP_X_FORWARDED_PROTO'] ?? ''))[0]));
    return (!empty($_SERVER['HTTPS']) && strtolower((string)$_SERVER['HTTPS']) !== 'off') || $forwardedProto === 'https';
}

function setAuthCookies(string $accessToken, string $refreshToken, int $accessTtl, int $refreshTtl): void
{
    $common = ['secure' => authCookieSecure(), 'httponly' => true, 'samesite' => 'Lax'];
    setcookie('ef_access', $accessToken, $common + ['expires' => time() + $accessTtl, 'path' => '/backend/']);
    setcookie('ef_refresh', $refreshToken, $common + ['expires' => time() + $refreshTtl, 'path' => '/backend/auth/']);
}

function clearAuthCookies(): void
{
    $common = ['expires' => time() - 3600, 'secure' => authCookieSecure(), 'httponly' => true, 'samesite' => 'Lax'];
    setcookie('ef_access', '', $common + ['path' => '/backend/']);
    setcookie('ef_refresh', '', $common + ['path' => '/backend/auth/']);
}

function refreshTokenFromRequest(?array $data): string
{
    $cookieToken = trim((string)($_COOKIE['ef_refresh'] ?? ''));
    return $cookieToken !== '' ? $cookieToken : trim((string)($data['refresh_token'] ?? ''));
}
