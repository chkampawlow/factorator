<?php

declare(strict_types=1);

if (PHP_SAPI !== 'cli') {
    http_response_code(404);
    exit;
}

require_once __DIR__ . '/../config/db.php';

$connection = db();

try {
    $connection->begin_transaction();

    $clientResult = $connection->query(
        "UPDATE clients SET name = UPPER(TRIM(name)) WHERE name IS NOT NULL"
    );
    $updatedClients = $connection->affected_rows;

    $supplierResult = $connection->query(
        "UPDATE suppliers SET name = UPPER(TRIM(name)) WHERE name IS NOT NULL"
    );
    $updatedSuppliers = $connection->affected_rows;

    $connection->commit();

    echo "Client names updated: {$updatedClients}" . PHP_EOL;
    echo "Supplier names updated: {$updatedSuppliers}" . PHP_EOL;
    echo "All existing names are now uppercase." . PHP_EOL;
} catch (Throwable $error) {
    $connection->rollback();
    fwrite(STDERR, 'Uppercase migration failed: ' . $error->getMessage() . PHP_EOL);
    exit(1);
}
