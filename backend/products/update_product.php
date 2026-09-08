<?php

header('Content-Type: application/json');

require_once __DIR__ . '/../config/response.php';
require_once __DIR__ . '/../config/db.php';
require_once __DIR__ . '/../config/validator.php';
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

    $id = getRequiredInt($data, 'id', 'Product ID');
    $codeProvided = array_key_exists('code', $data);
    $barcodeProvided = array_key_exists('barcode', $data);
    $categoryProvided = array_key_exists('category', $data);
    $unitProvided = array_key_exists('unit', $data);
    $itemTypeProvided = isset($data['item_type']) && trim((string)$data['item_type']) !== '';
    $priceProvided = isset($data['price']) && $data['price'] !== '';
    $purchasePriceProvided = isset($data['last_purchase_price']) && $data['last_purchase_price'] !== '';
    $tvaProvided = isset($data['tva_rate']) && $data['tva_rate'] !== '';
    $reorderPointProvided = isset($data['reorder_point']) && $data['reorder_point'] !== '';
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
    $reorderPoint = isset($data['reorder_point']) && $data['reorder_point'] !== ''
        ? validatePositiveNumber($data['reorder_point'], 'Reorder point')
        : 3.0;
    $conn = db();
    $typeStmt = $conn->prepare("SELECT code,barcode,category,item_type,price,last_purchase_price,tva_rate,unit,reorder_point FROM products WHERE id = ? AND user_id = ? LIMIT 1");
    $typeStmt->bind_param("ii", $id, $user_id);
    $typeStmt->execute();
    $existingProduct = $typeStmt->get_result()->fetch_assoc();
    $typeStmt->close();
    if (!$existingProduct) {
        throw new Exception("Product not found or not allowed");
    }
    $existingType = strtoupper((string)($existingProduct['item_type'] ?? 'PRODUCT'));
    if (!$codeProvided) $code = (string)($existingProduct['code'] ?? '');
    if (!$barcodeProvided) $barcode = strtoupper((string)($existingProduct['barcode'] ?? ''));
    if (!$categoryProvided) $category = (string)($existingProduct['category'] ?? '');
    if (!$unitProvided) $unit = (string)($existingProduct['unit'] ?? '');
    if (!$itemTypeProvided) $item_type = $existingType;
    if (!$priceProvided) $price = (float)($existingProduct['price'] ?? 0);
    if (!$purchasePriceProvided) $last_purchase_price = (float)($existingProduct['last_purchase_price'] ?? 0);
    if (!$tvaProvided) $tva_rate = (float)($existingProduct['tva_rate'] ?? 0);
    if (!$reorderPointProvided) $reorderPoint = (float)($existingProduct['reorder_point'] ?? 3);
    $sellingPriceRequired = $item_type === 'PRODUCT' && $price <= 0 ? 1 : 0;
    validateMaxLength($code, 100, 'Code');
    validateMaxLength($barcode, 64, 'Barcode');
    validateMaxLength($name, 255, 'Product name');
    validateMaxLength($category, 120, 'Category');
    validateMaxLength($unit, 50, 'Unit');
    requirePermission($conn, $user_id, $existingType === 'SERVICE' ? 'services.edit' : 'products.edit');
    if ($item_type !== $existingType) {
        requirePermission($conn, $user_id, $item_type === 'SERVICE' ? 'services.edit' : 'products.edit');
    }
    ensureProductInventorySchema($conn);
    $conn->begin_transaction();

    $stmt = $conn->prepare("
        UPDATE products
        SET code = ?, barcode = NULLIF(?, ''), name = ?, category = NULLIF(?, ''), item_type = ?, price = ?, selling_price_required = ?, last_purchase_price = ?, tva_rate = ?, unit = ?, reorder_point = ?
        WHERE id = ? AND user_id = ?
    ");

    if (!$stmt) {
        throw new Exception("Failed to prepare update product query: " . $conn->error);
    }

    $stmt->bind_param(
        "sssssdiddsdii",
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
        $reorderPoint,
        $id,
        $user_id
    );

    $stmt->execute();

    if ($stmt->error) {
        throw new Exception("Failed to update product: " . $stmt->error);
    }

    $stmt->close();
    if ($item_type === 'PRODUCT' && $barcode === '') {
        $barcode = 'EF-P-' . str_pad((string)$id, 8, '0', STR_PAD_LEFT);
        $barcodeStmt = $conn->prepare('UPDATE products SET barcode=? WHERE id=? AND user_id=?');
        $barcodeStmt->bind_param('sii', $barcode, $id, $user_id);
        $barcodeStmt->execute();
        $barcodeStmt->close();
    }
    $existsStmt = $conn->prepare("SELECT id FROM products WHERE id = ? AND user_id = ? LIMIT 1");
    if (!$existsStmt) {
        throw new Exception("Failed to verify product: " . $conn->error);
    }
    $existsStmt->bind_param("ii", $id, $user_id);
    $existsStmt->execute();
    $exists = $existsStmt->get_result()->fetch_assoc();
    $existsStmt->close();
    if (!$exists) {
        throw new Exception("Product not found or not allowed");
    }

    if ($item_type === 'SERVICE') {
        adjustProductStockTo($conn, $id, $user_id, 0.0, 'ADJUSTMENT', 'Service item keeps no stock');
    } else {
        syncProductStockQuantity($conn, $id, $user_id);
    }
    $conn->commit();

    jsonResponse([
        "success" => true,
        "message" => "Product updated successfully"
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
