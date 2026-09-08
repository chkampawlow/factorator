<?php

header('Content-Type: application/json');

require_once __DIR__ . '/../config/response.php';
require_once __DIR__ . '/../config/db.php';
require_once __DIR__ . '/../config/validator.php';
require_once __DIR__ . '/../config/idempotency.php';
require_once __DIR__ . '/../auth/auth_required.php';
require_once __DIR__ . '/../auth/role_helper.php';

require_once __DIR__ . '/product_inventory.php';



try {
    if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
        jsonResponse([
            "success" => false,
            "message" => "Method not allowed. Use POST."
        ], 405);
        exit;
    }

    $authUser = requireAuth();
    $user_id = (int)$authUser->id;

    $data = requireJsonBody();
    $idempotencyKey = requiredIdempotencyKey($data);

    $code = getOptionalString($data, 'code');
    $barcode = strtoupper(getOptionalString($data, 'barcode'));
    $name = getRequiredString($data, 'name', 'Product name');
    $category = getOptionalString($data, 'category');
    $unit = getOptionalString($data, 'unit');
    $item_type = strtoupper(getOptionalString($data, 'item_type') ?: 'PRODUCT');
    validateEnum($item_type, ['PRODUCT', 'SERVICE'], 'Item type');

    $price = isset($data['price']) && $data['price'] !== ''
        ? validatePositiveNumber($data['price'], 'Price')
        : 0.0;
    $last_purchase_price = isset($data['last_purchase_price']) && $data['last_purchase_price'] !== ''
        ? validatePositiveNumber($data['last_purchase_price'], 'Last purchase price')
        : 0.0;

    $tva_rate = isset($data['tva_rate']) && $data['tva_rate'] !== ''
        ? validatePositiveNumber($data['tva_rate'], 'TVA rate')
        : 0.0;
    $stock_quantity = isset($data['stock_quantity']) && $data['stock_quantity'] !== ''
        ? validatePositiveNumber($data['stock_quantity'], 'Stock quantity')
        : 0.0;
    $reorderPoint = isset($data['reorder_point']) && $data['reorder_point'] !== ''
        ? validatePositiveNumber($data['reorder_point'], 'Reorder point')
        : 3.0;
    if ($item_type === 'SERVICE') {
        $stock_quantity = 0.0;
    }
    $sellingPriceRequired = $item_type === 'PRODUCT' && $price <= 0 ? 1 : 0;

    validateMaxLength($code, 100, 'Code');
    validateMaxLength($barcode, 64, 'Barcode');
    validateMaxLength($name, 255, 'Product name');
    validateMaxLength($category, 120, 'Category');
    validateMaxLength($unit, 50, 'Unit');

    $conn = db();
    requirePermission($conn, $user_id, $item_type === 'SERVICE' ? 'services.create' : 'products.create');
    ensureProductInventorySchema($conn);
    $conn->begin_transaction();

    $requestHash = idempotencyRequestHash(['code' => $code, 'barcode' => $barcode, 'name' => $name, 'category' => $category, 'unit' => $unit, 'item_type' => $item_type, 'price' => $price, 'last_purchase_price' => $last_purchase_price, 'tva_rate' => $tva_rate, 'stock_quantity' => $stock_quantity, 'reorder_point' => $reorderPoint]);
    $replayedId = claimIdempotencyKey($conn, $user_id, 'product.create', $idempotencyKey, $requestHash);
    if ($replayedId !== null) {
        $conn->commit();
        jsonResponse(['success' => true, 'id' => $replayedId, 'replayed' => true]);
    }

    $stmt = $conn->prepare("
        INSERT INTO products (
            user_id,
            code,
            barcode,
            name,
            category,
            item_type,
            price,
            selling_price_required,
            last_purchase_price,
            tva_rate,
            unit,
            stock_quantity
            ,reorder_point
        )
        VALUES (?, ?, NULLIF(?, ''), ?, NULLIF(?, ''), ?, ?, ?, ?, ?, ?, ?, ?)
    ");

    if (!$stmt) {
        throw new Exception("Failed to prepare add product query: " . $conn->error);
    }

    $stmt->bind_param(
        "isssssdiddsdd",
        $user_id,
        $code,
        $barcode,
        $name,
        $category,
        $item_type,
        $price,
        $sellingPriceRequired,
        $last_purchase_price,
        $tva_rate,
        $unit,
        $stock_quantity,
        $reorderPoint
    );

    $stmt->execute();

    if ($stmt->error) {
        throw new Exception("Failed to create product: " . $stmt->error);
    }

    $productId = $stmt->insert_id;
    $stmt->close();
    if ($item_type === 'PRODUCT' && $barcode === '') {
        $barcode = 'EF-P-' . str_pad((string)$productId, 8, '0', STR_PAD_LEFT);
        $barcodeStmt = $conn->prepare('UPDATE products SET barcode=? WHERE id=? AND user_id=?');
        $barcodeStmt->bind_param('sii',$barcode,$productId,$user_id);$barcodeStmt->execute();$barcodeStmt->close();
    }

    if ($item_type === 'PRODUCT' && $stock_quantity > 0) {
        recordProductStockMovement(
            $conn,
            $productId,
            $user_id,
            $stock_quantity,
            'INITIAL',
            'PRODUCT',
            $productId,
            'Opening stock'
        );
    }
    syncProductStockQuantity($conn, $productId, $user_id);
    completeIdempotencyKey($conn, $user_id, 'product.create', $idempotencyKey, (int)$productId);
    $conn->commit();

    jsonResponse([
        "success" => true,
        "id" => $productId,
        "replayed" => false,
        "message" => "Product created successfully"
    ]);
} catch (Throwable $e) {
    if (isset($conn)) {
        try {
            $conn->rollback();
        } catch (Throwable $ignored) {
        }
    }
    jsonResponse([
        "success" => false,
        "message" => $e->getMessage()
    ], 400);
}
