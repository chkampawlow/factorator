<?php

declare(strict_types=1);

require_once __DIR__ . '/_bootstrap.php';

$data = input();
$userId = authenticatedUserId();
$pdo = db();

ensureUserExists($pdo, $userId);

$name = requiredString($data, 'name');
$itemType = strtoupper(trim((string) ($data['item_type'] ?? 'PRODUCT')));

if (!in_array($itemType, ['PRODUCT', 'SERVICE'], true)) {
    respond(422, [
        'success' => false,
        'message' => 'item_type must be PRODUCT or SERVICE.',
    ]);
}

$code = optionalString($data, 'code', 100);
$price = decimalValue($data['price'] ?? null, 'price');
$tvaRate = decimalValue($data['tva_rate'] ?? 0, 'tva_rate');

if ($tvaRate > 100) {
    respond(422, [
        'success' => false,
        'message' => 'tva_rate cannot exceed 100.',
    ]);
}

$unit = optionalString($data, 'unit', 100);
$stock = decimalValue($data['stock_quantity'] ?? 0, 'stock_quantity');

if ($itemType === 'SERVICE') {
    $stock = 0.0;
}

if ($code === null) {
    $prefix = $itemType === 'SERVICE' ? 'SRV' : 'PRD';
    $code = $prefix . '-' . strtoupper(bin2hex(random_bytes(3)));
}

$duplicate = $pdo->prepare(
    'SELECT id
     FROM products
     WHERE user_id = :user_id
       AND code = :code
     LIMIT 1'
);
$duplicate->execute([
    'user_id' => $userId,
    'code' => $code,
]);

if ($duplicate->fetch()) {
    respond(409, [
        'success' => false,
        'message' => 'A product or service with this code already exists.',
    ]);
}

try {
    $pdo->beginTransaction();

    $statement = $pdo->prepare(
        'INSERT INTO products
            (code, name, item_type, price, tva_rate, unit, stock_quantity, user_id)
         VALUES
            (:code, :name, :item_type, :price, :tva_rate, :unit, :stock, :user_id)'
    );

    $statement->execute([
        'code' => $code,
        'name' => $name,
        'item_type' => $itemType,
        'price' => $price,
        'tva_rate' => $tvaRate,
        'unit' => $unit,
        'stock' => $stock,
        'user_id' => $userId,
    ]);

    $productId = (int) $pdo->lastInsertId();

    if ($itemType === 'PRODUCT' && $stock != 0.0) {
        $movement = $pdo->prepare(
            'INSERT INTO product_stock_movements
                (user_id, product_id, movement_type, quantity,
                 reference_type, reference_id, note)
             VALUES
                (:user_id, :product_id, \'INITIAL\', :quantity,
                 \'PRODUCT\', :reference_id, \'Opening stock\')'
        );

        $movement->execute([
            'user_id' => $userId,
            'product_id' => $productId,
            'quantity' => $stock,
            'reference_id' => $productId,
        ]);
    }

    $pdo->commit();

    respond(201, [
        'success' => true,
        'message' => ucfirst(strtolower($itemType)) . ' created successfully.',
        'product_id' => $productId,
        'code' => $code,
    ]);
} catch (Throwable $exception) {
    if ($pdo->inTransaction()) {
        $pdo->rollBack();
    }

    throw $exception;
}
