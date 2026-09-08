<?php

header('Content-Type: application/json');
require_once __DIR__ . '/../config/response.php';
require_once __DIR__ . '/../config/db.php';
require_once __DIR__ . '/../config/pagination.php';
require_once __DIR__ . '/../auth/auth_required.php';
require_once __DIR__ . '/../auth/role_helper.php';
require_once __DIR__ . '/../config/field_projection.php';
require_once __DIR__ . '/product_inventory.php';

try {
    $uid = (int)requireAuth()->id;
    $c = db();
    ensureProductInventorySchema($c);
    $itemType = strtoupper(trim((string)($_GET['item_type'] ?? '')));
    if ($itemType === 'PRODUCT') requirePermission($c, $uid, 'products.view');
    elseif ($itemType === 'SERVICE') requirePermission($c, $uid, 'services.view');
    else requireAnyPermission($c, $uid, ['products.view', 'services.view', 'stock.view']);
    [$page, $size, $offset] = paginationInput($_GET);
    $search = trim((string)($_GET['search'] ?? ''));
    $stock = trim((string)($_GET['stock'] ?? ''));
    $pricing = trim((string)($_GET['pricing'] ?? ''));
    $where = ['p.user_id=?'];
    $types = 'i';
    $args = [$uid];
    if ($search !== '') {
        $where[] = "CONCAT_WS(' ',p.code,p.barcode,p.name,p.category,p.unit) LIKE ?";
        $types .= 's';
        $args[] = '%' . $search . '%';
    }
    if (in_array($itemType, ['PRODUCT', 'SERVICE'], true)) {
        $where[] = 'p.item_type=?';
        $types .= 's';
        $args[] = $itemType;
    }
    if ($stock === 'low') $where[] = "p.item_type='PRODUCT' AND p.stock_quantity<p.reorder_point";
    if ($pricing === 'required') $where[] = "p.item_type='PRODUCT' AND p.selling_price_required=1";
    $w = implode(' AND ', $where);

    $s = $c->prepare("SELECT COUNT(*) total,ROUND(COALESCE(SUM(CASE WHEN p.item_type='PRODUCT' THEN p.stock_quantity ELSE 0 END),0),3) stock_units,ROUND(COALESCE(SUM(CASE WHEN p.item_type='PRODUCT' THEN p.stock_quantity*p.average_cost ELSE 0 END),0),3) stock_value FROM products p WHERE $w");
    $s->bind_param($types, ...$args);
    $s->execute();
    $agg = $s->get_result()->fetch_assoc();
    $s->close();
    $order = paginationSort($_GET, ['name' => 'p.name', 'code' => 'p.code', 'stock' => 'p.stock_quantity', 'created' => 'p.id'], 'created');
    $s = $c->prepare("SELECT p.id,p.code,p.barcode,p.name,p.category,p.item_type,p.price,p.selling_price_required,p.last_purchase_price,p.average_cost,p.tva_rate,p.unit,IF(p.item_type='SERVICE',0,p.stock_quantity) stock_quantity,p.reorder_point FROM products p WHERE $w ORDER BY $order LIMIT ? OFFSET ?");
    $queryTypes = $types . 'ii';
    $queryArgs = [...$args, $size, $offset];
    $s->bind_param($queryTypes, ...$queryArgs);
    $s->execute();
    $rows = $s->get_result()->fetch_all(MYSQLI_ASSOC);
    $s->close();
    $total = (int)($agg['total'] ?? 0);
    unset($agg['total']);
    $role = currentUserRole($c, $uid);
    $rows = projectRows($rows, static fn(array $row): array => projectProductFields($row, $role));
    $agg = projectProductAggregates($agg, $role);
    paginatedResponse($rows, $page, $size, $total, $agg);
} catch (Throwable $e) {
    jsonResponse(['success' => false, 'message' => 'Could not load products.', 'error_code' => 'PRODUCT_LIST_FAILED'], 500);
}
