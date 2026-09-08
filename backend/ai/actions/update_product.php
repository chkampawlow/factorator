<?php

declare(strict_types=1);

require_once __DIR__ . '/_bootstrap.php';

$data = input();
$userId = authenticatedUserId();
$productId = positiveId($data, 'id');
$pdo = db();

$statement = $pdo->prepare(
    'SELECT *
     FROM products
     WHERE id = :id
       AND user_id = :user_id
     LIMIT 1'
);
$statement->execute([
    'id' => $productId,
    'user_id' => $userId,
]);
$product = $statement->fetch();

if (!$product) {
    respond(404, [
        'success' => false,
        'message' => 'Product or service not found.',
    ]);
}

$name = trim((string) ($data['name'] ?? $product['name']));
$code = array_key_exists('code', $data)
    ? optionalString($data, 'code', 100)
    : $product['code'];
$itemType = strtoupper(trim((string) ($data['item_type'] ?? $product['item_type'])));
$price = array_key_exists('price', $data)
    ? decimalValue($data['price'], 'price')
    : (float) $product['price'];
$tvaRate = array_key_exists('tva_rate', $data)
    ? decimalValue($data['tva_rate'], 'tva_rate')
    : (float) $product['tva_rate'];
$unit = array_key_exists('unit', $data)
    ? optionalString($data, 'unit', 100)
    : $product['unit'];
$newStock = array_key_exists('stock_quantity', $data)
    ? decimalValue($data['stock_quantity'], 'stock_quantity')
    : (float) $product['stock_quantity'];

if ($name === '') {
    respond(422, [
        'success' => false,
        'message' => 'name is required.',
    ]);
}

if (!in_array($itemType, ['PRODUCT', 'SERVICE'], true)) {
    respond(422, [
        'success' => false,
        'message' => 'item_type must be PRODUCT or SERVICE.',
    ]);
}

if ($tvaRate > 100) {
    respond(422, [
        'success' => false,
        'message' => 'tva_rate cannot exceed 100.',
    ]);
}

if ($itemType === 'SERVICE') {
    $newStock = 0.0;
}

if ($code !== null) {
    $duplicate = $pdo->prepare(
        'SELECT id
         FROM products
         WHERE user_id = :user_id
           AND code = :code
           AND id <> :id
         LIMIT 1'
    );
    $duplicate->execute([
        'user_id' => $userId,
        'code' => $code,
        'id' => $productId,
    ]);

    if ($duplicate->fetch()) {
        respond(409, [
            'success' => false,
            'message' => 'Another item already uses this code.',
        ]);
    }
}

$oldStock = (float) $product['stock_quantity'];
$stockDifference = round($newStock - $oldStock, 3);

try {
    $pdo->beginTransaction();

    $update = $pdo->prepare(
        'UPDATE products
         SET code = :code,
             name = :name,
             item_type = :item_type,
             price = :price,
             tva_rate = :tva_rate,
             unit = :unit,
             stock_quantity = :stock
         WHERE id = :id
           AND user_id = :user_id'
    );

    $update->execute([
        'code' => $code,
        'name' => $name,
        'item_type' => $itemType,
        'price' => $price,
        'tva_rate' => $tvaRate,
        'unit' => $unit,
        'stock' => $newStock,
        'id' => $productId,
        'user_id' => $userId,
    ]);

    if ($stockDifference != 0.0) {
        $movement = $pdo->prepare(
            'INSERT INTO product_stock_movements
                (user_id, product_id, movement_type, quantity,
                 reference_type, reference_id, note)
             VALUES
                (:user_id, :product_id, \'ADJUSTMENT\', :quantity,
                 \'PRODUCT\', :reference_id, \'Stock set from product editor\')'
        );
        $movement->execute([
            'user_id' => $userId,
            'product_id' => $productId,
            'quantity' => $stockDifference,
            'reference_id' => $productId,
        ]);
    }

    $pdo->commit();

    respond(200, [
        'success' => true,
        'message' => 'Product or service updated successfully.',
        'product_id' => $productId,
        'stock_adjustment' => $stockDifference,
    ]);
} catch (Throwable $exception) {
    if ($pdo->inTransaction()) {
        $pdo->rollBack();
    }

    throw $exception;
}
