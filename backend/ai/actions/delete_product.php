<?php

declare(strict_types=1);

require_once __DIR__ . '/_bootstrap.php';

$data = input();
$userId = authenticatedUserId();
$productId = positiveId($data, 'id');
$pdo = db();

$owned = $pdo->prepare(
    'SELECT id
     FROM products
     WHERE id = :id
       AND user_id = :user_id
     LIMIT 1'
);
$owned->execute([
    'id' => $productId,
    'user_id' => $userId,
]);

if (!$owned->fetch()) {
    respond(404, [
        'success' => false,
        'message' => 'Product or service not found.',
    ]);
}

/*
| Do not destroy an item that is already referenced by business documents.
| Add an is_archived column later if you want soft-delete for products.
*/
$references = [
    'erp_invoice_items' => 'product_id',
    'erp_sales_order_items' => 'product_id',
    'erp_delivery_note_items' => 'product_id',
];

foreach ($references as $table => $column) {
    $check = $pdo->prepare(
        "SELECT 1 FROM {$table} WHERE {$column} = :id LIMIT 1"
    );
    $check->execute(['id' => $productId]);

    if ($check->fetchColumn()) {
        respond(409, [
            'success' => false,
            'message' => 'This item is used by a document and cannot be deleted. Add product archiving instead.',
        ]);
    }
}

$delete = $pdo->prepare(
    'DELETE FROM products
     WHERE id = :id
       AND user_id = :user_id'
);
$delete->execute([
    'id' => $productId,
    'user_id' => $userId,
]);

respond(200, [
    'success' => true,
    'message' => 'Product or service deleted successfully.',
    'product_id' => $productId,
]);
