<?php

require_once __DIR__ . '/env.php';
require_once __DIR__ . '/response.php';

mysqli_report(MYSQLI_REPORT_ERROR | MYSQLI_REPORT_STRICT);

/* ==============================
   LOAD ENV FILE
============================== */

try {
    loadEnv(__DIR__ . '/../.env');
} catch (Throwable $e) {
    jsonResponse([
        "success" => false,
        "message" => "Failed to load environment configuration"
    ], 500);
}


/* ==============================
   DATABASE CONNECTION
============================== */

function db(): mysqli
{
    static $conn = null;

    if ($conn instanceof mysqli) {
        return $conn;
    }

    try {
        $host = trim((string)($_ENV['DB_HOST'] ?? ''));
        $user = trim((string)($_ENV['DB_USER'] ?? ''));
        $pass = (string)($_ENV['DB_PASS'] ?? '');
        $name = trim((string)($_ENV['DB_NAME'] ?? ''));
        $port = (int)($_ENV['DB_PORT'] ?? 3306);

        if ($host === '' || $user === '' || $pass === '' || $name === '') {
            throw new RuntimeException('Database configuration is incomplete.');
        }

        if ($port < 1 || $port > 65535) {
            throw new RuntimeException('Database port is invalid.');
        }

        $conn = new mysqli($host, $user, $pass, $name, $port);

        $conn->set_charset("utf8mb4");

        return $conn;

    } catch (Throwable $e) {

        jsonResponse([
            "success" => false,
            "message" => "Database connection failed"
        ], 500);

        exit;
    }
}
