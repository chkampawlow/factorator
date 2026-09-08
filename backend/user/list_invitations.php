<?php

declare(strict_types=1);

header('Content-Type: application/json');

require_once __DIR__ . '/../config/db.php';
require_once __DIR__ . '/../config/response.php';
require_once __DIR__ . '/../config/pagination.php';
require_once __DIR__ . '/../auth/auth_required.php';
require_once __DIR__ . '/../auth/role_helper.php';

try {
    if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'GET') {
        jsonResponse(['success' => false, 'message' => 'Method not allowed. Use GET.'], 405);
    }

    $auth = requireAuth();
    $conn = db();
    $companyId = authTenantId($auth);
    requireAdministratorRole($conn, $companyId);

    [$page, $pageSize, $offset] = paginationInput($_GET);
    $search = trim((string)($_GET['search'] ?? ''));
    $status = strtoupper(trim((string)($_GET['status'] ?? '')));
    $allowedStatuses = ['PENDING', 'ACCEPTED', 'REVOKED', 'EXPIRED'];
    if ($status !== '' && !in_array($status, $allowedStatuses, true)) {
        jsonResponse([
            'success' => false,
            'message' => 'Invalid invitation status filter.',
            'code' => 'INVITATION_STATUS_INVALID',
        ], 422);
    }

    $effectiveStatusSql = "CASE\n        WHEN ci.status = 'PENDING' AND ci.expires_at <= NOW() THEN 'EXPIRED'\n        ELSE ci.status\n    END";
    $where = ['ci.company_id = ?'];
    $types = 'i';
    $args = [$companyId];
    if ($search !== '') {
        $where[] = "CONCAT_WS(' ', ci.email, ci.display_name, ci.role) LIKE ?";
        $types .= 's';
        $args[] = '%' . $search . '%';
    }
    if ($status !== '') {
        $where[] = "{$effectiveStatusSql} = ?";
        $types .= 's';
        $args[] = $status;
    }
    $whereSql = implode(' AND ', $where);

    $countStmt = $conn->prepare("\n        SELECT COUNT(*) AS total\n        FROM company_invitations ci\n        WHERE {$whereSql}\n    ");
    $countStmt->bind_param($types, ...$args);
    $countStmt->execute();
    $total = (int)$countStmt->get_result()->fetch_assoc()['total'];
    $countStmt->close();

    $stmt = $conn->prepare("\n        SELECT\n            ci.id AS invitation_id, ci.email, ci.display_name, ci.role,\n            {$effectiveStatusSql} AS status, ci.expires_at, ci.created_at,\n            ci.accepted_at, ci.revoked_at, ci.invited_by\n        FROM company_invitations ci\n        WHERE {$whereSql}\n        ORDER BY ci.created_at DESC, ci.id DESC\n        LIMIT ? OFFSET ?\n    ");
    $listTypes = $types . 'ii';
    $listArgs = [...$args, $pageSize, $offset];
    $stmt->bind_param($listTypes, ...$listArgs);
    $stmt->execute();
    $rows = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);
    $stmt->close();

    foreach ($rows as &$row) {
        $row['invitation_id'] = (int)$row['invitation_id'];
        $row['invited_by'] = (int)$row['invited_by'];
        $row['role'] = normalizeUserRole($row['role'] ?? null);
        $row['entry_type'] = 'INVITATION';
        $row['can_revoke'] = $row['status'] === 'PENDING';
    }
    unset($row);

    $aggregateStmt = $conn->prepare("\n        SELECT effective_status AS status, COUNT(*) AS total\n        FROM (\n            SELECT {$effectiveStatusSql} AS effective_status\n            FROM company_invitations ci\n            WHERE ci.company_id = ?\n        ) invitation_statuses\n        GROUP BY effective_status\n    ");
    $aggregateStmt->bind_param('i', $companyId);
    $aggregateStmt->execute();
    $aggregateRows = $aggregateStmt->get_result()->fetch_all(MYSQLI_ASSOC);
    $aggregateStmt->close();
    $aggregates = array_fill_keys($allowedStatuses, 0);
    foreach ($aggregateRows as $aggregateRow) {
        $aggregates[(string)$aggregateRow['status']] = (int)$aggregateRow['total'];
    }

    jsonResponse([
        'success' => true,
        'data' => $rows,
        'page' => $page,
        'page_size' => $pageSize,
        'total' => $total,
        'aggregates' => $aggregates,
    ]);
} catch (Throwable $e) {
    structuredLog('ERROR', 'MEMBERSHIP.INVITATION_LIST_ERROR', [
        'exception' => get_class($e),
        'message' => $e->getMessage(),
    ]);
    jsonResponse([
        'success' => false,
        'message' => 'Unable to list invitations right now.',
        'code' => 'INVITATION_LIST_FAILED',
    ], 500);
}
