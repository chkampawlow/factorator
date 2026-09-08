<?php

declare(strict_types=1);

header('Content-Type: application/json');

require_once __DIR__ . '/../config/response.php';
require_once __DIR__ . '/../config/db.php';
require_once __DIR__ . '/../auth/auth_required.php';
require_once __DIR__ . '/../auth/role_helper.php';
require_once __DIR__ . '/../config/field_projection.php';

try {
    if (($_SERVER['REQUEST_METHOD'] ?? 'GET') !== 'GET') {
        jsonResponse(['success' => false, 'message' => 'Method not allowed. Use GET.'], 405);
    }

    $userId = (int)requireAuth()->id;
    $productId = (int)($_GET['id'] ?? 0);
    if ($productId <= 0) {
        jsonResponse(['success' => false, 'message' => 'Invalid product id.'], 422);
    }

    $conn = db();
    requireAnyPermission($conn, $userId, ['products.view', 'services.view', 'stock.view', 'orders.view', 'deliveries.view', 'invoices.view', 'supplierOrders.view', 'supplierReceptions.view', 'reports.view']);
    $stmt = $conn->prepare("SELECT id,code,barcode,name,category,item_type,price,selling_price_required,last_purchase_price,average_cost,tva_rate,unit,IF(item_type='SERVICE',0,stock_quantity) stock_quantity,reorder_point FROM products WHERE id=? AND user_id=? LIMIT 1");
    $stmt->bind_param('ii', $productId, $userId);
    $stmt->execute();
    $product = $stmt->get_result()->fetch_assoc();
    $stmt->close();

    if (!$product) {
        jsonResponse(['success' => false, 'message' => 'Product not found.'], 404);
    }
    $product = projectProductFields($product, currentUserRole($conn, $userId));
    jsonResponse(['success' => true, 'product' => $product]);
} catch (Throwable $e) {
    jsonResponse(['success' => false, 'message' => 'Could not load the product.', 'error_code' => 'PRODUCT_GET_FAILED'], 500);
}
