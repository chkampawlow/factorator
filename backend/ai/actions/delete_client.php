<?php

declare(strict_types=1);

require_once __DIR__ . '/_bootstrap.php';

$data = input();
$userId = authenticatedUserId();
$clientId = positiveId($data, 'id');
$pdo = db();

/*
| Soft-delete because your clients table already contains archive fields.
| This preserves invoices, orders, and delivery history.
*/
$statement = $pdo->prepare(
    'UPDATE clients
     SET is_archived = 1,
         archived_at = NOW()
     WHERE id = :id
       AND user_id = :user_id
       AND is_archived = 0'
);

$statement->execute([
    'id' => $clientId,
    'user_id' => $userId,
]);

if ($statement->rowCount() === 0) {
    respond(404, [
        'success' => false,
        'message' => 'Client not found or already archived.',
    ]);
}

respond(200, [
    'success' => true,
    'message' => 'Client archived successfully.',
    'client_id' => $clientId,
]);
