<?php

header('Content-Type: application/json');

require_once __DIR__ . '/../config/response.php';
require_once __DIR__ . '/../config/db.php';
require_once __DIR__ . '/../auth/auth_required.php';
require_once __DIR__ . '/../auth/role_helper.php';
require_once __DIR__ . '/../config/field_projection.php';
require_once __DIR__ . '/../invoices/workflow_schema.php';

try {
    if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
        jsonResponse(['success' => false, 'message' => 'Method not allowed'], 405);
    }

    $userId = (int)requireAuth()->id;
    $conn = db();
    requirePermission($conn, $userId, 'orders.view');
    ensureInvoiceWorkflowSchema($conn);

    $page = max(1, (int)($_GET['page'] ?? 1));
    $pageSize = min(100, max(1, (int)($_GET['page_size'] ?? 20)));
    $search = trim((string)($_GET['search'] ?? ''));
    $status = strtoupper(trim((string)($_GET['status'] ?? '')));
    $from = trim((string)($_GET['date_from'] ?? ''));
    $to = trim((string)($_GET['date_to'] ?? ''));

    $where = ['so.user_id=?'];
    $types = 'i';
    $args = [$userId];
    if ($search !== '') {
        $where[] = "CONCAT_WS(' ',so.order_number,c.name,so.status) LIKE ?";
        $types .= 's';
        $args[] = '%' . $search . '%';
    }
    if ($status !== '') {
        $where[] = 'so.status=?';
        $types .= 's';
        $args[] = $status;
    }
    if ($from !== '') {
        $where[] = 'so.order_date>=?';
        $types .= 's';
        $args[] = $from;
    }
    if ($to !== '') {
        $where[] = 'so.order_date<=?';
        $types .= 's';
        $args[] = $to;
    }
    $whereSql = implode(' AND ', $where);

    $count = $conn->prepare("SELECT COUNT(*) total
        FROM erp_sales_orders so
        LEFT JOIN clients c ON c.id=so.client_id AND c.user_id=so.user_id
        WHERE $whereSql");
    $count->bind_param($types, ...$args);
    $count->execute();
    $total = (int)$count->get_result()->fetch_assoc()['total'];
    $count->close();

    $summary = $conn->prepare("SELECT
        COALESCE(SUM(status='DRAFT'),0) drafts,
        COALESCE(SUM(status='CONFIRMED'),0) confirmed,
        COALESCE(SUM(status='PARTIALLY_DELIVERED'),0) partially_delivered,
        COALESCE(SUM(status='DELIVERED'),0) delivered,
        COALESCE(SUM(status='INVOICED'),0) invoiced,
        COALESCE(SUM(status='CANCELLED'),0) cancelled
        FROM erp_sales_orders WHERE user_id=?");
    $summary->bind_param('i', $userId);
    $summary->execute();
    $aggregates = $summary->get_result()->fetch_assoc() ?: [];
    $summary->close();
    foreach ($aggregates as $key => $value) $aggregates[$key] = (int)$value;

    $sql = "SELECT so.*,c.name client_name,c.email client_email,sd.invoice source_devis_number,
            (SELECT COUNT(*) FROM erp_delivery_notes dn WHERE dn.sales_order_id=so.id AND dn.user_id=so.user_id) delivery_count,
            (SELECT COUNT(*) FROM erp_invoices i WHERE i.sales_order_id=so.id AND i.user_id=so.user_id AND UPPER(i.invoice_type) NOT IN('DEVIS','AVOIR')) invoice_count
        FROM erp_sales_orders so
        LEFT JOIN clients c ON c.id=so.client_id AND c.user_id=so.user_id
        LEFT JOIN erp_invoices sd ON sd.id=so.source_devis_id AND sd.user_id=so.user_id
        WHERE $whereSql
        ORDER BY so.id DESC LIMIT ? OFFSET ?";
    $queryTypes = $types . 'ii';
    $queryArgs = [...$args, $pageSize, ($page - 1) * $pageSize];
    $stmt = $conn->prepare($sql);
    $stmt->bind_param($queryTypes, ...$queryArgs);
    $stmt->execute();
    $rows = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);
    $stmt->close();
    $rows = projectRows($rows, 'projectOperationalDocumentFields');

    jsonResponse([
        'success' => true,
        'data' => $rows,
        'total' => $total,
        'page' => $page,
        'page_size' => $pageSize,
        'aggregates' => $aggregates,
    ]);
} catch (Throwable $e) {
    jsonResponse(['success' => false, 'message' => 'Could not load sales orders.', 'error_code' => 'ORDER_LIST_FAILED'], 500);
}
