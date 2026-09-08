<?php

header('Content-Type: application/json');

require_once __DIR__ . '/../config/response.php';
require_once __DIR__ . '/../config/db.php';
require_once __DIR__ . '/../config/pagination.php';
require_once __DIR__ . '/../auth/auth_required.php';
require_once __DIR__ . '/../auth/role_helper.php';

try {
    $userId = (int) requireAuth()->id;
    $conn = db();
    requirePermission($conn, $userId, 'reports.view');
    [$page, $pageSize, $offset] = paginationInput($_GET);
    $action = strtoupper(trim((string) ($_GET['action'] ?? '')));
    $entityType = strtoupper(trim((string) ($_GET['entity_type'] ?? '')));
    $from = trim((string) ($_GET['date_from'] ?? ''));
    $to = trim((string) ($_GET['date_to'] ?? ''));

    $where = ['tenant_id=?'];
    $types = 'i';
    $args = [$userId];
    if ($action !== '') { $where[] = 'action=?'; $types .= 's'; $args[] = $action; }
    if ($entityType !== '') { $where[] = 'entity_type=?'; $types .= 's'; $args[] = $entityType; }
    if ($from !== '') { $where[] = 'created_at>=?'; $types .= 's'; $args[] = $from . ' 00:00:00'; }
    if ($to !== '') { $where[] = 'created_at<?'; $types .= 's'; $args[] = date('Y-m-d 00:00:00', strtotime($to . ' +1 day')); }
    $whereSql = implode(' AND ', $where);

    $count = $conn->prepare("SELECT COUNT(*) total FROM app_audit_log WHERE $whereSql");
    $count->bind_param($types, ...$args);
    $count->execute();
    $total = (int) $count->get_result()->fetch_assoc()['total'];
    $count->close();

    $stmt = $conn->prepare("SELECT id,actor_id,action,entity_type,entity_id,before_values,
            after_values,request_id,source,user_agent,created_at
        FROM app_audit_log WHERE $whereSql ORDER BY id DESC LIMIT ? OFFSET ?");
    $queryTypes = $types . 'ii';
    $queryArgs = [...$args, $pageSize, $offset];
    $stmt->bind_param($queryTypes, ...$queryArgs);
    $stmt->execute();
    $rows = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);
    $stmt->close();
    foreach ($rows as &$row) {
        $row['before_values'] = $row['before_values'] ? json_decode($row['before_values'], true) : null;
        $row['after_values'] = $row['after_values'] ? json_decode($row['after_values'], true) : null;
    }

    paginatedResponse($rows, $page, $pageSize, $total, ['append_only' => true]);
} catch (Throwable $e) {
    jsonResponse(['success' => false, 'message' => 'Could not load the audit log.'], 500);
}
