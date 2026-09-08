<?php

header('Content-Type: application/json');
require_once __DIR__ . '/../config/response.php';
require_once __DIR__ . '/../config/db.php';
require_once __DIR__ . '/../config/pagination.php';
require_once __DIR__ . '/../auth/auth_required.php';
require_once __DIR__ . '/../auth/role_helper.php';
require_once __DIR__ . '/invoice_service.php';

$debugStage = 'request';

try {
    if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'GET') jsonResponse(['success'=>false,'message'=>'Method not allowed'],405);
    $debugStage = 'authentication';
    $userId = (int)requireAuth()->id;
    $conn = db();
    $debugStage = 'authorization';
    requirePermission($conn, $userId, 'supplierInvoices.view');
    [$page, $pageSize, $offset] = paginationInput($_GET);
    $search = trim((string)($_GET['search'] ?? ''));
    $status = strtoupper(trim((string)($_GET['status'] ?? '')));
    $where = ['si.user_id=?'];
    $types = 'i';
    $args = [$userId];
    if ($search !== '') {
        $where[] = "CONCAT_WS(' ',si.invoice_number,s.name,so.order_number,si.status) LIKE ?";
        $types .= 's';
        $args[] = '%' . $search . '%';
    }
    if ($status !== '' && in_array($status, ['DRAFT','VALIDATED','PARTIALLY_PAID','PAID','CANCELLED'], true)) {
        $where[] = 'si.status=?';
        $types .= 's';
        $args[] = $status;
    }
    $whereSql = implode(' AND ', $where);
    $baseJoin = ' FROM erp_supplier_invoices si JOIN suppliers s ON s.id=si.supplier_id AND s.user_id=si.user_id LEFT JOIN erp_supplier_orders so ON so.id=si.supplier_order_id AND so.user_id=si.user_id';
    $debugStage = 'aggregate_query';
    $count = $conn->prepare("SELECT COUNT(*) total,ROUND(COALESCE(SUM(si.total_ttc_tnd),0),3) total_tnd,ROUND(COALESCE(SUM(GREATEST(si.total_ttc_tnd-(si.credited_amount+COALESCE((SELECT SUM(sp.amount) FROM erp_supplier_payments sp WHERE sp.supplier_invoice_id=si.id AND sp.user_id=si.user_id AND sp.voided_at IS NULL),0))*si.exchange_rate,0)),0),3) outstanding_tnd $baseJoin WHERE $whereSql");
    $count->bind_param($types, ...$args);
    $count->execute();
    $aggregates = $count->get_result()->fetch_assoc();
    $count->close();

    $debugStage = 'list_query';
    $query = $conn->prepare(supplierInvoiceHeaderSelect() . " WHERE $whereSql ORDER BY si.invoice_date DESC,si.id DESC LIMIT ? OFFSET ?");
    $queryTypes = $types . 'ii';
    $queryArgs = [...$args, $pageSize, $offset];
    $query->bind_param($queryTypes, ...$queryArgs);
    $query->execute();
    $rows = array_map('supplierInvoiceListRow', $query->get_result()->fetch_all(MYSQLI_ASSOC));
    $query->close();
    $total = (int)($aggregates['total'] ?? 0);
    unset($aggregates['total']);
    paginatedResponse($rows, $page, $pageSize, $total, $aggregates);
} catch (Throwable $error) {
    structuredLog('ERROR', 'SUPPLIER_INVOICE.LIST_FAILED', [
        'stage' => $debugStage,
        'exception' => get_class($error),
        'message' => $error->getMessage(),
    ]);
    jsonResponse(['success'=>false,'message'=>'Could not load supplier invoices.','error_code'=>'SUPPLIER_INVOICE_LIST_FAILED'],500);
}
