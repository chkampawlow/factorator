<?php

declare(strict_types=1);

header('Content-Type: application/json');

require_once __DIR__ . '/../config/response.php';
require_once __DIR__ . '/../config/db.php';
require_once __DIR__ . '/../config/pagination.php';
require_once __DIR__ . '/../auth/auth_required.php';
require_once __DIR__ . '/../auth/role_helper.php';

$debugStage = 'request';

try {
    $debugStage = 'authentication';
    $principal = requireAuth();
    $actorId = authActorId($principal);
    $tenantId = authTenantId($principal);
    $conn = db();

    $debugStage = 'authorization';
    requirePermission($conn, $actorId, 'expenses.view');

    [$page, $pageSize, $offset] = paginationInput($_GET);
    $search = trim((string)($_GET['search'] ?? ''));
    $status = strtoupper(trim((string)($_GET['status'] ?? '')));
    $from = trim((string)($_GET['date_from'] ?? ''));
    $to = trim((string)($_GET['date_to'] ?? ''));
    $where = ['e.user_id=?'];
    $types = 'i';
    $args = [$tenantId];

    if ($search !== '') {
        $where[] = "CONCAT_WS(' ',e.title,e.category,e.description,s.name,e.source_document_number) LIKE ?";
        $types .= 's';
        $args[] = '%' . $search . '%';
    }
    if ($status !== '') {
        $where[] = 'e.status=?';
        $types .= 's';
        $args[] = $status;
    }
    if ($from !== '') {
        $where[] = 'e.expense_date>=?';
        $types .= 's';
        $args[] = $from;
    }
    if ($to !== '') {
        $where[] = 'e.expense_date<=?';
        $types .= 's';
        $args[] = $to;
    }

    $whereSql = implode(' AND ', $where);
    $join = ' FROM expense_notes e LEFT JOIN suppliers s ON s.id=e.supplier_id AND s.user_id=e.user_id';

    $debugStage = 'aggregate_query';
    $query = $conn->prepare(
        "SELECT COUNT(*) total,ROUND(COALESCE(SUM(e.amount),0),3) amount {$join} WHERE {$whereSql}"
    );
    $query->bind_param($types, ...$args);
    $query->execute();
    $aggregates = $query->get_result()->fetch_assoc() ?: [];
    $query->close();

    $order = paginationSort($_GET, [
        'date' => 'e.expense_date',
        'amount' => 'e.amount',
        'title' => 'e.title',
        'created' => 'e.id',
    ], 'date');

    $debugStage = 'page_query';
    $query = $conn->prepare(
        "SELECT e.*,s.name supplier_name,s.reference supplier_reference {$join} "
        . "WHERE {$whereSql} ORDER BY {$order},e.id DESC LIMIT ? OFFSET ?"
    );
    $queryTypes = $types . 'ii';
    $queryArgs = [...$args, $pageSize, $offset];
    $query->bind_param($queryTypes, ...$queryArgs);
    $query->execute();
    $rows = $query->get_result()->fetch_all(MYSQLI_ASSOC);
    $query->close();

    $total = (int)($aggregates['total'] ?? 0);
    unset($aggregates['total']);
    paginatedResponse($rows, $page, $pageSize, $total, $aggregates);
} catch (Throwable $error) {
    structuredLog('ERROR', 'EXPENSE_LIST.LOAD_FAILED', [
        'stage' => $debugStage,
        'exception' => get_class($error),
        'message' => $error->getMessage(),
    ]);
    jsonResponse([
        'success' => false,
        'message' => 'Could not load expenses.',
        'error_code' => 'EXPENSE_LIST_FAILED',
    ], 500);
}
