<?php

header('Content-Type: application/json');

require_once __DIR__ . '/../config/response.php';
require_once __DIR__ . '/../config/db.php';
require_once __DIR__ . '/../config/pagination.php';
require_once __DIR__ . '/../auth/auth_required.php';
require_once __DIR__ . '/../auth/role_helper.php';
require_once __DIR__ . '/../config/field_projection.php';
require_once __DIR__ . '/list_query.php';

try {
    $userId = (int)requireAuth()->id;
    $conn = db();
    requirePermission($conn, $userId, 'clients.view');

    [$page, $pageSize, $offset] = paginationInput($_GET);
    $search = trim((string)($_GET['search'] ?? ''));
    $type = trim((string)($_GET['type'] ?? ''));
    $availableColumns = clientListAvailableColumns($conn);
    $missingMigrationColumns = clientListMissingMigrationColumns($availableColumns);

    if ($missingMigrationColumns) {
        structuredLog('WARNING', 'CLIENT.LIST_SCHEMA_COMPATIBILITY', [
            'missing_columns' => $missingMigrationColumns,
            'required_migrations' => [
                '2026-08-06-invoice-date-controls.sql',
                '2026-09-02-client-supplier-references.sql',
            ],
        ]);
    }

    $where = ['user_id=?'];
    $types = 'i';
    $arguments = [$userId];

    if ($search !== '') {
        $where[] = clientListSearchSql($availableColumns);
        $types .= 's';
        $arguments[] = '%' . $search . '%';
    }
    if ($type !== '') {
        $where[] = "CASE WHEN type='person' THEN 'individual' ELSE type END=?";
        $types .= 's';
        $arguments[] = $type;
    }

    $whereSql = implode(' AND ', $where);
    $countStatement = $conn->prepare("SELECT COUNT(*) total FROM clients WHERE $whereSql");
    $countStatement->bind_param($types, ...$arguments);
    $countStatement->execute();
    $total = (int)$countStatement->get_result()->fetch_assoc()['total'];
    $countStatement->close();

    $order = paginationSort($_GET, ['name' => 'name', 'created' => 'id'], 'created');
    $selectSql = clientListSelectSql($availableColumns);
    $listStatement = $conn->prepare(
        "SELECT $selectSql FROM clients WHERE $whereSql ORDER BY $order LIMIT ? OFFSET ?"
    );
    $listTypes = $types . 'ii';
    $listArguments = [...$arguments, $pageSize, $offset];
    $listStatement->bind_param($listTypes, ...$listArguments);
    $listStatement->execute();
    $rows = $listStatement->get_result()->fetch_all(MYSQLI_ASSOC);
    $listStatement->close();

    $role = currentUserRole($conn, $userId);
    $rows = projectRows(
        $rows,
        static fn(array $row): array => projectClientFields($row, $role)
    );

    paginatedResponse($rows, $page, $pageSize, $total);
} catch (Throwable $error) {
    structuredLog('ERROR', 'CLIENT.LIST_FAILED', [
        'exception' => get_class($error),
        'message' => $error->getMessage(),
        'file' => basename($error->getFile()),
        'line' => $error->getLine(),
    ]);
    jsonResponse([
        'success' => false,
        'message' => 'Could not load clients.',
        'error_code' => 'CLIENT_LIST_FAILED',
    ], 500);
}
