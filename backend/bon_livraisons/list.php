<?php
header('Content-Type: application/json');
require_once __DIR__ . '/../config/response.php';
require_once __DIR__ . '/../config/db.php';
require_once __DIR__ . '/../auth/auth_required.php';
require_once __DIR__ . '/../auth/role_helper.php';
require_once __DIR__ . '/../config/field_projection.php';

require_once __DIR__ . '/helpers.php';
require_once __DIR__ . '/workflow_summary.php';


try {
    if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
        jsonResponse(['success' => false, 'message' => 'Method not allowed'], 405);
    }

    $userId = (int)requireAuth()->id;
    $conn = db();requirePermission($conn,$userId,'deliveries.view');
    ensureDeliverySchema($conn);
    $page = max(1, (int)($_GET['page'] ?? 1));
    $pageSize = min(100, max(1, (int)($_GET['page_size'] ?? 20)));
    $search = trim((string)($_GET['search'] ?? ''));
    $status = strtoupper(trim((string)($_GET['status'] ?? '')));
    $dateFrom = trim((string)($_GET['date_from'] ?? ''));
    $dateTo = trim((string)($_GET['date_to'] ?? ''));
    $salesOrderId = (int)($_GET['sales_order_id'] ?? 0);
    $where = ['dn.user_id = ?'];
    $types = 'i';
    $params = [$userId];
    if ($search !== '') {
        $where[] = "CONCAT_WS(' ', dn.delivery_number, c.name, dn.status, so.order_number) LIKE ?";
        $types .= 's';
        $params[] = '%' . $search . '%';
    }
    if ($status !== '') {
        $where[] = 'UPPER(dn.status) = ?';
        $types .= 's';
        $params[] = $status;
    }
    if ($dateFrom !== '') {
        $where[] = 'dn.delivery_date >= ?';
        $types .= 's';
        $params[] = $dateFrom;
    }
    if ($dateTo !== '') {
        $where[] = 'dn.delivery_date <= ?';
        $types .= 's';
        $params[] = $dateTo;
    }
    if ($salesOrderId > 0) {
        $where[] = 'dn.sales_order_id = ?';
        $types .= 'i';
        $params[] = $salesOrderId;
    }
    $whereSql = implode(' AND ', $where);

    $countStmt = $conn->prepare("SELECT COUNT(*) AS total
        FROM erp_delivery_notes dn
        LEFT JOIN clients c ON c.id = dn.client_id AND c.user_id = dn.user_id
        LEFT JOIN erp_sales_orders so ON so.id = dn.sales_order_id AND so.user_id = dn.user_id
        WHERE $whereSql");
    $countStmt->bind_param($types, ...$params);
    $countStmt->execute();
    $total = (int)($countStmt->get_result()->fetch_assoc()['total'] ?? 0);
    $countStmt->close();

    $readinessJoins = deliveryWorkflowReadinessJoins();
    $sql = "SELECT dn.*, c.name AS client_name, c.email AS client_email, so.order_number,
            (SELECT COUNT(*) FROM erp_invoices i WHERE i.delivery_note_id=dn.id AND i.user_id=dn.user_id) invoice_count,
            COALESCE(invoice_drafts.draft_invoice_count,0) draft_invoice_count,
            invoice_drafts.draft_invoice_id,
            COALESCE(validated_invoices.validated_invoice_count,0) validated_invoice_count,
            CASE WHEN dn.status='DELIVERED' AND dn.document_type='DELIVERY'
                       AND COALESCE(readiness.has_remaining,0)=1
                       AND COALESCE(invoice_drafts.draft_invoice_count,0)=0
                 THEN 1 ELSE 0 END ready_to_invoice
        FROM erp_delivery_notes dn
        LEFT JOIN clients c ON c.id = dn.client_id AND c.user_id = dn.user_id
        LEFT JOIN erp_sales_orders so ON so.id = dn.sales_order_id AND so.user_id = dn.user_id
        $readinessJoins
        WHERE $whereSql ORDER BY dn.id DESC";
    $sql .= ' LIMIT ? OFFSET ?';
    $types .= 'ii';
    $params[] = $pageSize;
    $params[] = ($page - 1) * $pageSize;
    $stmt = $conn->prepare($sql);
    $stmt->bind_param($types, ...$params);
    $stmt->execute();
    $rows = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);
    $stmt->close();
    $rows = projectRows($rows, 'projectOperationalDocumentFields');

    jsonResponse(['success' => true, 'data' => $rows, 'total' => $total, 'page' => $page, 'page_size' => $pageSize, 'aggregates' => deliveryWorkflowSummary($conn, $userId)]);
} catch (Throwable $e) {
    jsonResponse(['success' => false, 'message' => 'Could not load delivery notes.', 'error_code' => 'DELIVERY_LIST_FAILED'], 500);
}
