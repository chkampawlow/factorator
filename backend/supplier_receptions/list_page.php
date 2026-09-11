<?php

declare(strict_types=1);

header('Content-Type: application/json');

require_once __DIR__ . '/../config/response.php';
require_once __DIR__ . '/../config/db.php';
require_once __DIR__ . '/../config/pagination.php';
require_once __DIR__ . '/../auth/auth_required.php';
require_once __DIR__ . '/../auth/role_helper.php';
require_once __DIR__ . '/reception_service.php';

$debugStage = 'request';

try {
    $debugStage = 'authentication';
    $principal = requireAuth();
    $actorId = authActorId($principal);
    $tenantId = authTenantId($principal);
    $conn = db();

    $debugStage = 'authorization';
    requirePermission($conn, $actorId, 'supplierReceptions.view');

    [$page, $pageSize, $offset] = paginationInput($_GET);
    $search = trim((string)($_GET['search'] ?? ''));
    $status = strtoupper(trim((string)($_GET['status'] ?? '')));
    $supplierOrderId = max(0, (int)($_GET['supplier_order_id'] ?? 0));
    $where = ['sr.user_id=?'];
    $types = 'i';
    $args = [$tenantId];

    if ($search !== '') {
        $where[] = "CONCAT_WS(' ',sr.invoice_number,s.name,sr.status,so.order_number) LIKE ?";
        $types .= 's';
        $args[] = '%' . $search . '%';
    }
    if ($status !== '') {
        $where[] = 'sr.status=?';
        $types .= 's';
        $args[] = $status;
    }
    if ($supplierOrderId > 0) {
        $where[] = 'sr.supplier_order_id=?';
        $types .= 'i';
        $args[] = $supplierOrderId;
    }

    $whereSql = implode(' AND ', $where);
    $join = ' FROM erp_supplier_receptions sr '
        . 'JOIN suppliers s ON s.id=sr.supplier_id AND s.user_id=sr.user_id '
        . 'LEFT JOIN erp_supplier_orders so ON so.id=sr.supplier_order_id AND so.user_id=sr.user_id';

    $debugStage = 'aggregate_query';
    $query = $conn->prepare(
        "SELECT COUNT(*) total,ROUND(COALESCE(SUM(sr.total_ttc),0),3) amount {$join} WHERE {$whereSql}"
    );
    $query->bind_param($types, ...$args);
    $query->execute();
    $aggregates = $query->get_result()->fetch_assoc() ?: [];
    $query->close();

    $debugStage = 'page_query';
    $query = $conn->prepare(
        "SELECT sr.*,s.name supplier_name,so.order_number {$join} "
        . "WHERE {$whereSql} ORDER BY sr.id DESC LIMIT ? OFFSET ?"
    );
    $queryTypes = $types . 'ii';
    $queryArgs = [...$args, $pageSize, $offset];
    $query->bind_param($queryTypes, ...$queryArgs);
    $query->execute();
    $headers = $query->get_result()->fetch_all(MYSQLI_ASSOC);
    $query->close();

    $rows = [];
    if ($headers !== []) {
        $ids = array_map(static fn(array $row): int => (int)$row['id'], $headers);
        $idSql = implode(',', $ids);
        $debugStage = 'item_query';
        $itemResult = $conn->query(
            "SELECT * FROM erp_supplier_reception_items "
            . "WHERE supplier_reception_id IN({$idSql}) ORDER BY id"
        );
        $itemsByReception = [];
        while ($item = $itemResult->fetch_assoc()) {
            $itemsByReception[(int)$item['supplier_reception_id']][] = supplierReceptionLineRow($item);
        }
        $itemResult->close();
        foreach ($headers as $header) {
            $rows[] = supplierReceptionRow(
                $header,
                $itemsByReception[(int)$header['id']] ?? []
            );
        }
    }

    $total = (int)($aggregates['total'] ?? 0);
    unset($aggregates['total']);
    paginatedResponse($rows, $page, $pageSize, $total, $aggregates);
} catch (Throwable $error) {
    structuredLog('ERROR', 'SUPPLIER_RECEPTION_LIST.LOAD_FAILED', [
        'stage' => $debugStage,
        'exception' => get_class($error),
        'message' => $error->getMessage(),
    ]);
    jsonResponse([
        'success' => false,
        'message' => 'Could not load supplier receptions.',
        'error_code' => 'SUPPLIER_RECEPTION_LIST_FAILED',
    ], 500);
}
