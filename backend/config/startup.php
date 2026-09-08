<?php

require_once __DIR__ . '/env.php';

function applicationConfigurationErrors(array $environment): array
{
    $errors = [];
    foreach (['APP_ENV','DB_HOST','DB_USER','DB_PASS','DB_NAME','JWT_SECRET','TWO_FACTOR_ENCRYPTION_KEY',
        'MAIL_HOST','MAIL_USERNAME','MAIL_PASSWORD','MAIL_FROM_ADDRESS'] as $key) {
        if (!isset($environment[$key]) || trim((string)$environment[$key]) === '') $errors[] = $key . ' is required';
    }
    if (isset($environment['JWT_SECRET']) && strlen((string)$environment['JWT_SECRET']) < 32) {
        $errors[] = 'JWT_SECRET must contain at least 32 characters';
    }
    $twoFactorKey = base64_decode((string)($environment['TWO_FACTOR_ENCRYPTION_KEY'] ?? ''), true);
    if ($twoFactorKey === false || strlen($twoFactorKey) !== 32) {
        $errors[] = 'TWO_FACTOR_ENCRYPTION_KEY must be a base64-encoded 32-byte key';
    }
    if (isset($environment['MAIL_FROM_ADDRESS']) && $environment['MAIL_FROM_ADDRESS'] !== ''
        && !filter_var($environment['MAIL_FROM_ADDRESS'], FILTER_VALIDATE_EMAIL)) {
        $errors[] = 'MAIL_FROM_ADDRESS must be a valid email address';
    }
    $appEnvironment = strtolower(trim((string)($environment['APP_ENV'] ?? '')));
    if (!in_array($appEnvironment, ['development','staging','production'], true)) $errors[] = 'APP_ENV is invalid';
    if ($appEnvironment === 'production') {
        $origins = array_filter(array_map('trim', explode(',', (string)($environment['CORS_ALLOWED_ORIGINS'] ?? ''))));
        if ($origins === [] || in_array('*', $origins, true)) $errors[] = 'CORS_ALLOWED_ORIGINS must be explicit in production';
        foreach ($origins as $origin) if (!str_starts_with($origin, 'https://')) $errors[] = 'Production CORS origins must use HTTPS';
    }
    if (!empty($environment['ERROR_MONITOR_WEBHOOK_URL']) && empty($environment['ERROR_MONITOR_WEBHOOK_SECRET'])) {
        $errors[] = 'ERROR_MONITOR_WEBHOOK_SECRET is required when monitoring alerts are enabled';
    }
    return array_values(array_unique($errors));
}

function enforceStartupConfiguration(): void
{
    static $validated = false;
    if ($validated) return;
    try {
        loadEnv(dirname(__DIR__) . '/.env');
        $errors = applicationConfigurationErrors($_ENV);
    } catch (Throwable $error) {
        $errors = [$error->getMessage()];
    }
    if ($errors !== []) {
        http_response_code(500);
        header('Content-Type: application/json; charset=UTF-8');
        echo json_encode(['success'=>false,'message'=>'Application configuration is invalid.','error_code'=>'CONFIGURATION_ERROR','errors'=>$errors]);
        exit;
    }
    $validated = true;
}
