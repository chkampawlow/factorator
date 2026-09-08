<?php

declare(strict_types=1);

header('Content-Type: application/json; charset=utf-8');

require_once __DIR__ . '/../config/response.php';
require_once __DIR__ . '/../config/db.php';
require_once __DIR__ . '/../auth/auth_required.php';
require_once __DIR__ . '/../auth/role_helper.php';

$debugStage = 'request';

try {
    if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'GET') {
        jsonResponse([
            'success' => false,
            'message' => 'Method not allowed. Use GET.',
        ], 405);
    }

    $debugStage = 'authentication';
    $principal = requireAuth();
    $tenantId = authTenantId($principal);

    $debugStage = 'authorization';
    $conn = db();
    requireAnyPermission($conn, $tenantId, [
        'suppliers.view',
        'supplierOrders.view',
        'supplierReceptions.view',
    ]);

    $search = trim((string)($_GET['search'] ?? ''));
    $limit = min(50, max(1, (int)($_GET['limit'] ?? 50)));
    $like = '%' . $search . '%';

    $debugStage = 'supplier_options_query';
    $statement = $conn->prepare("SELECT id,reference,type,name,email,phone,address,fiscal_id fiscalId
        FROM suppliers
        WHERE user_id=?
          AND (?='' OR CONCAT_WS(' ',reference,name,email,phone,fiscal_id) LIKE ?)
        ORDER BY name,id
        LIMIT ?");
    $statement->bind_param('issi', $tenantId, $search, $like, $limit);
    $statement->execute();
    $rows = $statement->get_result()->fetch_all(MYSQLI_ASSOC);
    $statement->close();

    structuredLog('INFO', 'SUPPLIER_OPTIONS.LOADED', [
        'result_count' => count($rows),
        'search_applied' => $search !== '',
    ]);

    jsonResponse([
        'success' => true,
        'data' => $rows,
    ]);
} catch (Throwable $error) {
    structuredLog('ERROR', 'SUPPLIER_OPTIONS.LOAD_FAILED', [
        'stage' => $debugStage,
        'exception' => get_class($error),
        'message' => $error->getMessage(),
    ]);
    jsonResponse([
        'success' => false,
        'message' => 'Could not load supplier options.',
        'error_code' => 'SUPPLIER_OPTIONS_FAILED',
    ], 500);
}
