<?php

require_once __DIR__ . '/../config/startup.php';

$valid = [
    'DB_HOST'=>'127.0.0.1','DB_USER'=>'app','DB_PASS'=>'secret','DB_NAME'=>'app',
    'JWT_SECRET'=>str_repeat('j',32),'TWO_FACTOR_ENCRYPTION_KEY'=>base64_encode(str_repeat('k',32)),
    'MAIL_HOST'=>'smtp.example.com','MAIL_USERNAME'=>'mailer','MAIL_PASSWORD'=>'secret',
    'MAIL_FROM_ADDRESS'=>'billing@example.com','APP_ENV'=>'development',
];

function configCase(string $name, array $configuration, bool $shouldPass): void
{
    $passed = applicationConfigurationErrors($configuration) === [];
    if ($passed !== $shouldPass) throw new RuntimeException('FAIL ' . $name . ': ' . implode('; ', applicationConfigurationErrors($configuration)));
    echo 'PASS ' . $name . "\n";
}

configCase('complete development configuration', $valid, true);
configCase('missing database password', array_diff_key($valid, ['DB_PASS'=>true]), false);
configCase('short JWT secret', [...$valid, 'JWT_SECRET'=>'short'], false);
configCase('invalid 2FA encryption key', [...$valid, 'TWO_FACTOR_ENCRYPTION_KEY'=>'invalid'], false);
configCase('invalid mail sender', [...$valid, 'MAIL_FROM_ADDRESS'=>'invalid'], false);
configCase('production wildcard CORS', [...$valid, 'APP_ENV'=>'production', 'CORS_ALLOWED_ORIGINS'=>'*'], false);
configCase('production HTTP CORS', [...$valid, 'APP_ENV'=>'production', 'CORS_ALLOWED_ORIGINS'=>'http://app.example.com'], false);
configCase('monitoring without signing secret', [...$valid, 'ERROR_MONITOR_WEBHOOK_URL'=>'https://monitor.example.com'], false);
configCase('complete production configuration', [...$valid, 'APP_ENV'=>'production', 'CORS_ALLOWED_ORIGINS'=>'https://app.example.com'], true);
