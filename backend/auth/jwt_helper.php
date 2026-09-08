<?php
require_once __DIR__ . '/../vendor/autoload.php';
require_once __DIR__ . '/../config/env.php';

use Firebase\JWT\JWT;
use Firebase\JWT\Key;

if (empty($_ENV['JWT_SECRET'])) {
    loadEnv(__DIR__ . '/../.env');
}

if (strlen((string)($_ENV['JWT_SECRET'] ?? '')) < 32) {
    throw new RuntimeException('JWT_SECRET must contain at least 32 characters.');
}

function generateJwt(array $user, int $expiresInSeconds = 86400): string
{
    $now = time();

    $payload = [
        'iss' => $_ENV['JWT_ISSUER'] ?? 'facturation_app',
        'iat' => $now,
        'exp' => $now + $expiresInSeconds,
        'type' => 'access',
        'user' => jwtUserIdentity($user),
    ];

    return JWT::encode($payload, $_ENV['JWT_SECRET'], 'HS256');
}

function decodeJwt(string $token): object
{
    return JWT::decode($token, new Key($_ENV['JWT_SECRET'], 'HS256'));
}

function generateTwoFactorChallenge(array $user, bool $rememberMe, int $expiresInSeconds = 300): string
{
    $now = time();
    $payload = [
        'iss' => $_ENV['JWT_ISSUER'] ?? 'facturation_app',
        'iat' => $now,
        'exp' => $now + $expiresInSeconds,
        'jti' => bin2hex(random_bytes(16)),
        'type' => 'two_factor_challenge',
        'user_id' => (int)$user['id'],
        'email' => (string)($user['email'] ?? ''),
        'company_id' => (int)($user['company_id'] ?? $user['tenant_id'] ?? 0),
        'remember_me' => $rememberMe,
    ];

    return JWT::encode($payload, $_ENV['JWT_SECRET'], 'HS256');
}

function decodeTwoFactorChallenge(string $token): object
{
    $decoded = decodeJwt($token);
    if (($decoded->type ?? '') !== 'two_factor_challenge' || (int)($decoded->user_id ?? 0) <= 0) {
        throw new UnexpectedValueException('Invalid two-factor challenge.');
    }

    return $decoded;
}

function getBearerToken(): ?string
{
    $token = $_SERVER['HTTP_X_ACCESS_TOKEN'] ?? null;

    if (!$token) {
        $token = $_COOKIE['ef_access'] ?? null;
    }

    if (!$token && function_exists('apache_request_headers')) {
        $requestHeaders = apache_request_headers();
        $token = $requestHeaders['X-Access-Token'] ?? $requestHeaders['x-access-token'] ?? null;
    }

    if (!$token) {
        return null;
    }

    return trim($token);
}

function generateRefreshJwt(array $user, int $expiresInSeconds = 2592000): string
{
    $now = time();

    $payload = [
        'iss' => $_ENV['JWT_ISSUER'] ?? 'facturation_app',
        'iat' => $now,
        'exp' => $now + $expiresInSeconds,
        'jti' => bin2hex(random_bytes(16)),
        'type' => 'refresh',
        'user' => jwtUserIdentity($user),
    ];

    return JWT::encode($payload, $_ENV['JWT_SECRET'], 'HS256');
}

function jwtUserIdentity(array $user): array
{
    $companyId = (int)($user['company_id'] ?? $user['tenant_id'] ?? 0);
    return [
        'id' => (int)$user['id'],
        'email' => (string)($user['email'] ?? ''),
        'role' => safeJwtRole($user['role'] ?? null),
        'company_id' => $companyId,
        'tenant_id' => $companyId,
        'membership_id' => (int)($user['membership_id'] ?? 0),
        'membership_version' => (int)($user['membership_version'] ?? 0),
    ];
}

function safeJwtRole($value): string
{
    $role = strtoupper(trim((string)$value));
    $allowedRoles = ['ADMINISTRATOR', 'COMMERCIAL', 'STOCK', 'ACCOUNTING'];

    return in_array($role, $allowedRoles, true) ? $role : 'UNAUTHORIZED';
}
