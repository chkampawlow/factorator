<?php

if (PHP_SAPI !== 'cli') { http_response_code(404); exit; }
require_once __DIR__ . '/../config/startup.php';

try {
    loadEnv(__DIR__ . '/../.env');
    $errors = applicationConfigurationErrors($_ENV);
} catch (Throwable $error) {
    $errors = [$error->getMessage()];
}
if ($errors !== []) {
    foreach ($errors as $error) fwrite(STDERR, 'FAIL ' . $error . PHP_EOL);
    exit(1);
}
echo "PASS application configuration is valid\n";
