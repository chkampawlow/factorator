<?php

header('Content-Type: application/json');

require_once __DIR__ . '/../config/response.php';
require_once __DIR__ . '/../config/db.php';
require_once __DIR__ . '/../config/pagination.php';
require_once __DIR__ . '/../auth/auth_required.php';
require_once __DIR__ . '/../auth/role_helper.php';
require_once __DIR__ . '/order_service.php';

try {
    $debugStage = 'authentication';
    $principal = requireAuth();
    $actorId = authActorId($principal);
    $tenantId = authTenantId($principal);
    $conn = db();
    $debugStage = 'authorization';
    requirePermission($conn, $actorId, 'supplierOrders.view');
    [$page, $pageSize, $offset] = paginationInput($_GET);
    $search = trim((string)($_GET['search'] ?? ''));
    $status = strtoupper(trim((string)($_GET['status'] ?? '')));
    $supplierId = max(0, (int)($_GET['supplier_id'] ?? 0));
    $where = ['so.user_id=?'];
    $types = 'i';
    $args = [$tenantId];
    if ($search !== '') {
        $where[] = "CONCAT_WS(' ',so.order_number,s.name,so.status) LIKE ?";
        $types .= 's';
        $args[] = '%' . $search . '%';
    }
    if ($status !== '') {
        $where[] = 'so.status=?';
        $types .= 's';
        $args[] = $status;
    }
    if ($supplierId > 0) {
        $where[] = 'so.supplier_id=?';
        $types .= 'i';
        $args[] = $supplierId;
    }

    $whereSql = implode(' AND ', $where);
    $join = ' FROM erp_supplier_orders so JOIN suppliers s ON s.id=so.supplier_id AND s.user_id=so.user_id';
    $debugStage = 'aggregate_query';
    $query = $conn->prepare("SELECT COUNT(*) total,ROUND(COALESCE(SUM(so.total),0),3) amount $join WHERE $whereSql");
    $query->bind_param($types, ...$args);
    $query->execute();
    $aggregates = $query->get_result()->fetch_assoc();
    $query->close();

    $debugStage = 'page_query';
    $query = $conn->prepare("SELECT so.*,s.name supplier_name,
        (SELECT COALESCE(SUM(soi.qty),0) FROM erp_supplier_order_items soi WHERE soi.supplier_order_id=so.id) ordered_qty,
        (SELECT COALESCE(SUM(sri.accepted_qty),0)
         FROM erp_supplier_receptions sr
         JOIN erp_supplier_reception_items sri ON sri.supplier_reception_id=sr.id
         WHERE sr.supplier_order_id=so.id AND sr.user_id=so.user_id AND sr.status='REVIEWED' AND sr.stock_applied=1) received_qty
        $join WHERE $whereSql ORDER BY so.id DESC LIMIT ? OFFSET ?");
    $queryTypes = $types . 'ii';
    $queryArgs = [...$args, $pageSize, $offset];
    $query->bind_param($queryTypes, ...$queryArgs);
    $query->execute();
    $headers = $query->get_result()->fetch_all(MYSQLI_ASSOC);
    $query->close();

    $rows = [];
    if ($headers) {
        $ids = array_map(static fn(array $row): int => (int)$row['id'], $headers);
        $idSql = implode(',', $ids);
        $debugStage = 'item_query';
        $itemsResult = $conn->query("SELECT * FROM erp_supplier_order_items WHERE supplier_order_id IN($idSql) ORDER BY id");
        $itemsByOrder = [];
        while ($item = $itemsResult->fetch_assoc()) {
            $itemsByOrder[(int)$item['supplier_order_id']][] = supplierOrderItemRow($item);
        }
        $itemsResult->close();
        foreach ($headers as $header) {
            $rows[] = supplierOrderRow($header, $itemsByOrder[(int)$header['id']] ?? []);
        }
    }

    $total = (int)$aggregates['total'];
    unset($aggregates['total']);
    paginatedResponse($rows, $page, $pageSize, $total, $aggregates);
} catch (Throwable $error) {
    structuredLog('ERROR', 'SUPPLIER_ORDER_LIST.LOAD_FAILED', [
        'stage' => $debugStage ?? 'request',
        'exception' => get_class($error),
        'message' => $error->getMessage(),
    ]);
    jsonResponse(['success' => false, 'message' => 'Could not load supplier orders.', 'error_code' => 'SUPPLIER_ORDER_LIST_FAILED'], 500);
}
