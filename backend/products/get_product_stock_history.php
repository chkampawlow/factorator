<?php
header('Content-Type: application/json');

require_once __DIR__ . '/../config/response.php';
require_once __DIR__ . '/../config/db.php';
require_once __DIR__ . '/../auth/auth_required.php';
require_once __DIR__ . '/../auth/role_helper.php';

require_once __DIR__ . '/../config/pagination.php';
require_once __DIR__ . '/../config/field_projection.php';
require_once __DIR__ . '/product_inventory.php';


try {
    if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
        jsonResponse([
            'success' => false,
            'message' => 'Method not allowed. Use GET.'
        ], 405);
        exit;
    }

    $authUser = requireAuth();
    $userId = authTenantId($authUser);
    $actorId = authActorId($authUser);
    $productId = isset($_GET['id']) ? (int)$_GET['id'] : 0;

    if ($productId <= 0) {
        throw new Exception('Invalid product id');
    }

    $conn = db();
    requirePermission($conn, $actorId, 'stock.view');
    ensureProductInventorySchema($conn);

    $productStmt = $conn->prepare("
        SELECT id, code, name, item_type, price, last_purchase_price, tva_rate, unit, stock_quantity, reorder_point
        FROM products
        WHERE id = ? AND user_id = ?
        LIMIT 1
    ");
    if (!$productStmt) {
        throw new Exception('Failed to prepare product query: ' . $conn->error);
    }
    $productStmt->bind_param('ii', $productId, $userId);
    $productStmt->execute();
    $product = $productStmt->get_result()->fetch_assoc();
    $productStmt->close();

    if (!$product) {
        throw new Exception('Product not found or unauthorized');
    }

    $itemType = strtoupper((string)($product['item_type'] ?? 'PRODUCT'));
    $currentStock = $itemType === 'SERVICE' ? 0.0 : getProductStockQuantity($conn, $productId, $userId);
    [$page, $pageSize, $offset] = paginationInput($_GET);
    $movementType = strtoupper(trim((string)($_GET['movement_type'] ?? '')));

    $countSql = 'SELECT COUNT(*) total FROM product_stock_movements WHERE product_id = ? AND user_id = ?';
    $countTypes = 'ii';
    $countArgs = [$productId, $userId];
    if ($movementType !== '') {
        $countSql .= ' AND movement_type = ?';
        $countTypes .= 's';
        $countArgs[] = $movementType;
    }
    $countStmt = $conn->prepare($countSql);
    $countStmt->bind_param($countTypes, ...$countArgs);
    $countStmt->execute();
    $total = (int)$countStmt->get_result()->fetch_assoc()['total'];
    $countStmt->close();

    $movementStmt = $conn->prepare("
        SELECT *
        FROM (
            SELECT
                id,
                movement_type,
                quantity,
                reference_type,
                reference_id,
                note,
                created_at,
                ROUND(
                    ? - COALESCE(
                        SUM(quantity) OVER (
                            ORDER BY created_at DESC, id DESC
                            ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING
                        ),
                        0
                    ),
                    3
                ) AS balance_after
            FROM product_stock_movements
            WHERE product_id = ? AND user_id = ?
        ) movements
        " . ($movementType !== '' ? 'WHERE movement_type = ?' : '') . "
        ORDER BY created_at DESC, id DESC LIMIT ? OFFSET ?
    ");
    if (!$movementStmt) {
        throw new Exception('Failed to prepare movement query: ' . $conn->error);
    }
    if ($movementType !== '') {
        $movementStmt->bind_param('diisii', $currentStock, $productId, $userId, $movementType, $pageSize, $offset);
    } else {
        $movementStmt->bind_param('diiii', $currentStock, $productId, $userId, $pageSize, $offset);
    }
    $movementStmt->execute();
    $movementRows = $movementStmt->get_result()->fetch_all(MYSQLI_ASSOC);
    $movementStmt->close();

    $movements = [];

    foreach ($movementRows as $row) {
        $quantity = round((float)($row['quantity'] ?? 0), 3);
        $afterBalance = round((float)$row['balance_after'],3);
        $beforeBalance = round($afterBalance - $quantity, 3);

        $row['quantity'] = $quantity;
        $row['balance_after'] = $afterBalance;
        $row['balance_before'] = $beforeBalance;
        $movements[] = $row;

    }

    $productPayload = projectProductFields([
        'id' => (int)$product['id'],
        'code' => $product['code'],
        'name' => $product['name'],
        'item_type' => $itemType,
        'price' => (float)$product['price'],
        'last_purchase_price' => (float)($product['last_purchase_price'] ?? 0),
        'tva_rate' => (float)$product['tva_rate'],
        'unit' => $product['unit'],
        'stock_quantity' => $currentStock,
        'reorder_point' => (float)($product['reorder_point'] ?? 0),
    ], currentUserRole($conn, $actorId));

    jsonResponse([
        'success' => true,
        'product' => $productPayload,
        'movements' => $movements,
        'data'=>$movements,'page'=>$page,'page_size'=>$pageSize,'total'=>$total,'aggregates'=>(object)['current_stock'=>$currentStock],
    ]);
} catch (Throwable $e) {
    jsonResponse([
        'success' => false,
        'message' => $e->getMessage()
    ], resourceExceptionStatus($e));
}
?>
