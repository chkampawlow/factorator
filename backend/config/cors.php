<?php

require_once __DIR__ . '/env.php';

function configuredCorsOrigins(): array
{
    static $origins = null;
    if (is_array($origins)) return $origins;

    if (!isset($_ENV['CORS_ALLOWED_ORIGINS'])) {
        $envPath = dirname(__DIR__) . '/.env';
        if (is_file($envPath)) loadEnv($envPath);
    }

    $configured = trim((string)($_ENV['CORS_ALLOWED_ORIGINS'] ?? getenv('CORS_ALLOWED_ORIGINS') ?: ''));
    if ($configured === '') {
        $configured = 'http://localhost:4200,http://127.0.0.1:4200';
    }

    $origins = array_values(array_unique(array_filter(array_map(
        static fn(string $origin): string => rtrim(trim($origin), '/'),
        explode(',', $configured)
    ))));

    return $origins;
}

function applyCors(
    string $allowedMethods = 'GET, POST, PUT, DELETE, OPTIONS',
    string $allowedHeaders = 'Content-Type, Accept, Authorization, X-Access-Token, X-Request-ID, Idempotency-Key'
): void {
    $origin = rtrim(trim((string)($_SERVER['HTTP_ORIGIN'] ?? '')), '/');
    if ($origin !== '' && in_array($origin, configuredCorsOrigins(), true)) {
        header('Access-Control-Allow-Origin: ' . $origin);
        header('Access-Control-Allow-Credentials: true');
        header('Vary: Origin');
    }

    header('Access-Control-Allow-Headers: ' . $allowedHeaders);
    header('Access-Control-Allow-Methods: ' . $allowedMethods);
    header('Access-Control-Max-Age: 86400');
}
