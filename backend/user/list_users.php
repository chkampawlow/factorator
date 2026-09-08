<?php

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
    $actorId = authActorId($auth);
    requireAdministratorRole($conn, $companyId);

    [$page, $pageSize, $offset] = paginationInput($_GET);
    $search = trim((string)($_GET['search'] ?? ''));
    $role = strtoupper(trim((string)($_GET['role'] ?? '')));
    $status = strtoupper(trim((string)($_GET['status'] ?? '')));
    if ($role !== '' && !in_array($role, availableUserRoles(), true)) {
        jsonResponse(['success' => false, 'message' => 'Invalid role filter.'], 422);
    }
    if ($status !== '' && !in_array($status, ['ACTIVE', 'SUSPENDED', 'REVOKED'], true)) {
        jsonResponse(['success' => false, 'message' => 'Invalid status filter.'], 422);
    }

    $where = ['cm.company_id = ?'];
    $types = 'i';
    $args = [$companyId];
    if ($search !== '') {
        $where[] = "CONCAT_WS(' ', u.display_name, u.email, cm.role, cm.status) LIKE ?";
        $types .= 's';
        $args[] = '%' . $search . '%';
    }
    if ($role !== '') {
        $where[] = 'cm.role = ?';
        $types .= 's';
        $args[] = $role;
    }
    if ($status !== '') {
        $where[] = 'cm.status = ?';
        $types .= 's';
        $args[] = $status;
    }
    $whereSql = implode(' AND ', $where);
    $from = ' FROM company_memberships cm JOIN users u ON u.id = cm.user_id';

    $countStmt = $conn->prepare("SELECT COUNT(*) AS total{$from} WHERE {$whereSql}");
    $countStmt->bind_param($types, ...$args);
    $countStmt->execute();
    $total = (int)$countStmt->get_result()->fetch_assoc()['total'];
    $countStmt->close();

    $stmt = $conn->prepare("\n        SELECT\n            cm.id AS membership_id, cm.user_id, cm.company_id AS tenant_id,\n            cm.role, cm.status, cm.is_owner, cm.version, cm.joined_at,\n            cm.suspended_at, cm.revoked_at, cm.created_at,\n            u.display_name, u.email, u.phone\n        {$from}\n        WHERE {$whereSql}\n        ORDER BY cm.is_owner DESC, cm.created_at ASC, cm.id ASC\n        LIMIT ? OFFSET ?\n    ");
    $listTypes = $types . 'ii';
    $listArgs = [...$args, $pageSize, $offset];
    $stmt->bind_param($listTypes, ...$listArgs);
    $stmt->execute();
    $rows = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);
    $stmt->close();

    $administratorStmt = $conn->prepare("\n        SELECT COUNT(*) AS total\n        FROM company_memberships\n        WHERE company_id = ? AND status = 'ACTIVE' AND role = 'ADMINISTRATOR'\n    ");
    $administratorStmt->bind_param('i', $companyId);
    $administratorStmt->execute();
    $activeAdministratorCount = (int)$administratorStmt->get_result()->fetch_assoc()['total'];
    $administratorStmt->close();

    foreach ($rows as &$row) {
        $row['membership_id'] = (int)$row['membership_id'];
        $row['user_id'] = (int)$row['user_id'];
        $row['tenant_id'] = (int)$row['tenant_id'];
        $row['is_owner'] = (int)$row['is_owner'] === 1;
        $row['is_current_user'] = (int)$row['user_id'] === $actorId;
        $row['version'] = (int)$row['version'];
        $row['role'] = normalizeUserRole($row['role'] ?? null);
        $row['entry_type'] = 'MEMBERSHIP';
        $manageable = !$row['is_owner'] && !$row['is_current_user'];
        $row['is_last_active_administrator'] = $row['status'] === 'ACTIVE'
            && $row['role'] === 'ADMINISTRATOR'
            && $activeAdministratorCount <= 1;
        $canDeactivate = $manageable && !$row['is_last_active_administrator'];
        $row['capabilities'] = [
            'can_update_role' => $manageable
                && $row['status'] === 'ACTIVE'
                && !$row['is_last_active_administrator'],
            'can_suspend' => $canDeactivate && $row['status'] === 'ACTIVE',
            'can_reactivate' => $manageable && $row['status'] === 'SUSPENDED',
            'can_remove' => $canDeactivate && $row['status'] !== 'REVOKED',
        ];
        // Transitional aliases used by the existing Angular table.
        $row['id'] = $row['user_id'];
        $row['organization_name'] = $row['display_name'] ?? '';
        $row['fiscal_id'] = '';
    }
    unset($row);

    $aggregateStmt = $conn->prepare("\n        SELECT status, COUNT(*) AS total\n        FROM company_memberships\n        WHERE company_id = ?\n        GROUP BY status\n    ");
    $aggregateStmt->bind_param('i', $companyId);
    $aggregateStmt->execute();
    $aggregateRows = $aggregateStmt->get_result()->fetch_all(MYSQLI_ASSOC);
    $aggregateStmt->close();
    $aggregates = ['ACTIVE' => 0, 'SUSPENDED' => 0, 'REVOKED' => 0];
    foreach ($aggregateRows as $aggregateRow) {
        $aggregates[(string)$aggregateRow['status']] = (int)$aggregateRow['total'];
    }

    jsonResponse([
        'success' => true,
        'roles' => availableUserRoles(),
        'data' => $rows,
        'page' => $page,
        'page_size' => $pageSize,
        'total' => $total,
        'aggregates' => $aggregates,
        'capabilities' => ['can_invite' => true],
    ]);
} catch (Throwable $e) {
    structuredLog('ERROR', 'MEMBERSHIP.LIST_ERROR', [
        'exception' => get_class($e),
        'message' => $e->getMessage(),
    ]);
    jsonResponse([
        'success' => false,
        'message' => 'Unable to list company members right now.',
        'code' => 'MEMBERSHIP_LIST_FAILED',
    ], 500);
}
