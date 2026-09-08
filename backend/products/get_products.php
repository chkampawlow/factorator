<?php
header('Content-Type: application/json');

require_once __DIR__ . '/../config/response.php';
require_once __DIR__ . '/../config/db.php';
require_once __DIR__ . '/../auth/auth_required.php';
require_once __DIR__ . '/../auth/role_helper.php';
require_once __DIR__ . '/../config/field_projection.php';

require_once __DIR__ . '/product_inventory.php';

try {
    if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
        jsonResponse([
            "success" => false,
            "message" => "Method not allowed. Use GET."
        ], 405);
        exit;
    }

    $authUser = requireAuth();
    $user_id = (int)$authUser->id;

    $conn = db();requireAnyPermission($conn,$user_id,['products.view','services.view','stock.view','orders.view','deliveries.view','invoices.view','supplierOrders.view','supplierReceptions.view','reports.view']);
    ensureProductInventorySchema($conn);

    $stmt = $conn->prepare("
        SELECT
            p.id,
            p.code,
            p.name,
            p.category,
            p.item_type,
            p.price,
            p.selling_price_required,
            p.last_purchase_price,
            p.tva_rate,
            p.unit,
            CASE
                WHEN p.item_type = 'SERVICE' THEN 0
                ELSE ROUND(COALESCE(sm.stock_quantity, 0), 3)
            END AS stock_quantity
            ,p.reorder_point
        FROM products p
        LEFT JOIN (
            SELECT product_id, user_id, SUM(quantity) AS stock_quantity
            FROM product_stock_movements
            GROUP BY product_id, user_id
        ) sm ON sm.product_id = p.id AND sm.user_id = p.user_id
        WHERE p.user_id = ?
        ORDER BY p.id DESC
    ");
    $stmt->bind_param("i", $user_id);
    $stmt->execute();

    $result = $stmt->get_result();

    $rows = [];
    while ($row = $result->fetch_assoc()) {
        $rows[] = $row;
    }

    $stmt->close();
    $role = currentUserRole($conn, $user_id);
    $rows = projectRows($rows, static fn(array $row): array => projectProductFields($row, $role));

    jsonResponse([
        "success" => true,
        "data" => $rows
    ]);
} catch (Throwable $e) {
    jsonResponse([
        "success" => false,
        "message" => $e->getMessage()
    ], 400);
}
?>
