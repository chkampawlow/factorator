<?php

header('Content-Type: application/json');
require_once __DIR__ . '/../config/response.php';
require_once __DIR__ . '/../config/db.php';
require_once __DIR__ . '/../auth/auth_required.php';
require_once __DIR__ . '/../auth/role_helper.php';
require_once __DIR__ . '/../config/field_projection.php';
require_once __DIR__ . '/product_inventory.php';

try {
    $userId = (int)requireAuth()->id;
    $conn = db();
    requireAnyPermission($conn, $userId, [
        'products.view', 'services.view', 'stock.view', 'orders.view',
        'deliveries.view', 'invoices.view', 'supplierOrders.view',
        'supplierReceptions.view', 'reports.view',
        'invoices.view', 'invoices.create', 'invoices.edit',
        'devis.view', 'devis.create', 'devis.edit',
        'avoirs.view', 'avoirs.create', 'avoirs.edit',
    ]);
    $search = trim((string)($_GET['search'] ?? ''));
    $saleReady = (string)($_GET['sale_ready'] ?? '') === '1';
    $limit = min(50, max(1, (int)($_GET['limit'] ?? 50)));
    $like = '%' . $search . '%';
    // Sales workflows receive catalog identity and selling data only. Purchase
    // cost, average cost, reorder policy, and margin internals stay private to
    // stock/accounting endpoints.
    ensureProductInventorySchema($conn);
    $saleReadyWhere = $saleReady ? " AND (item_type='SERVICE' OR selling_price_required=0)" : '';
    $stmt = $conn->prepare("SELECT id,code,barcode,name,category,item_type,price,selling_price_required,tva_rate,unit,IF(item_type='SERVICE',0,stock_quantity) stock_quantity FROM products WHERE user_id=? AND (?='' OR CONCAT_WS(' ',code,barcode,name,category,unit) LIKE ?)$saleReadyWhere ORDER BY name,id LIMIT ?");
    $stmt->bind_param('issi', $userId, $search, $like, $limit);
    $stmt->execute();
    $rows = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);
    $stmt->close();
    $role = currentUserRole($conn, $userId);
    $rows = projectRows($rows, static fn(array $row): array => projectProductFields($row, $role));
    jsonResponse(['success' => true, 'data' => $rows]);
} catch (Throwable $e) {
    jsonResponse(['success' => false, 'message' => 'Could not load product options.', 'error_code' => 'PRODUCT_OPTIONS_FAILED'], 500);
}
