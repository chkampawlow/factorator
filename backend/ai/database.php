<?php

declare(strict_types=1);

/*
|--------------------------------------------------------------------------
| Database connection
|--------------------------------------------------------------------------
| Update the values below if your MariaDB credentials are different.
*/

function db(): PDO
{
    static $pdo = null;

    if ($pdo instanceof PDO) {
        return $pdo;
    }

    $host = '127.0.0.1';
    $port = '3306';
    $database = 'facturation_local';
    $username = 'root';
    $password = '';

    $dsn = sprintf(
        'mysql:host=%s;port=%s;dbname=%s;charset=utf8mb4',
        $host,
        $port,
        $database
    );

    try {
        $pdo = new PDO(
            $dsn,
            $username,
            $password,
            [
                PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
                PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
                PDO::ATTR_EMULATE_PREPARES => false,
            ]
        );

        return $pdo;
    } catch (PDOException $exception) {
        http_response_code(500);

        header('Content-Type: application/json; charset=utf-8');

        echo json_encode([
            'success' => false,
            'message' => 'Database connection failed.',
            'error' => $exception->getMessage(),
        ]);

        exit;
    }
}