<?php
declare(strict_types=1);

function loadEnv(string $path): void
{
    if (!is_file($path) || !is_readable($path)) {
        throw new RuntimeException('.env file is missing or unreadable.');
    }

    $lines = file(
        $path,
        FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES
    );

    if ($lines === false) {
        throw new RuntimeException('.env file could not be loaded.');
    }

    foreach ($lines as $line) {

        $line = trim($line);

        if ($line === '' || str_starts_with($line, '#')) {
            continue;
        }

        if (!str_contains($line, '=')) {
            continue;
        }

        [$key, $value] = explode('=', $line, 2);

        $key = trim($key);
        $value = trim($value);

        if ($key === '') {
            continue;
        }

        if (strlen($value) >= 2) {
            $first = $value[0];
            $last = $value[strlen($value) - 1];

            if (
                ($first === '"' && $last === '"') ||
                ($first === "'" && $last === "'")
            ) {
                $value = substr($value, 1, -1);
            }
        }

        // Force .env values into all PHP environment views
        $_ENV[$key] = $value;
        $_SERVER[$key] = $value;

        putenv($key);
        putenv($key . '=' . $value);
    }
}