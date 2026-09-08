<?php

declare(strict_types=1);

header('Content-Type: application/json; charset=utf-8');
header('Cache-Control: no-store, private');
require_once __DIR__ . '/../config/response.php';
require_once __DIR__ . '/../config/db.php';
require_once __DIR__ . '/../auth/auth_required.php';
require_once __DIR__ . '/../auth/role_helper.php';
require_once __DIR__ . '/../config/field_projection.php';
require_once __DIR__ . '/notification_service.php';

try {
    if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'GET') {
        jsonResponse(['success'=>false,'message'=>'Method not allowed. Use GET.'],405);
    }
    $auth = requireAuth();
    $tenantId = authTenantId($auth);
    $actorId = authActorId($auth);
    $conn = db();
    requirePermission($conn, $actorId, 'dashboard.view');
    $role = currentUserRole($conn, $actorId);

    // Preserve the count contract consumed by the Angular notification menu.
    $stmt = $conn->prepare("SELECT
        (SELECT COUNT(*) FROM erp_invoices WHERE user_id=? AND invoice_type='FACTURE' AND is_validated=1 AND UPPER(status) NOT IN('PAID','PAYED','PAID_IN_FULL','CANCELLED')) unpaid_count,
        (SELECT COUNT(*) FROM products WHERE user_id=? AND item_type='PRODUCT' AND stock_quantity<reorder_point) low_stock_count,
        (SELECT COUNT(*) FROM clients WHERE user_id=?) client_count,
        (SELECT COUNT(*) FROM products WHERE user_id=?) product_count,
        (SELECT COUNT(*) FROM products WHERE user_id=? AND item_type='PRODUCT' AND selling_price_required=1) pricing_required_count");
    $stmt->bind_param('iiiii', $tenantId, $tenantId, $tenantId, $tenantId, $tenantId);
    $stmt->execute();
    $legacyCounts = projectNotificationCounts($stmt->get_result()->fetch_assoc() ?: [], $role);
    $stmt->close();

    $items = attachNotificationReadState(
        $conn,
        $tenantId,
        $actorId,
        currentOperationalNotifications($conn, $tenantId, $actorId)
    );
    $counts = [...$legacyCounts, 'unread_count'=>0, 'total_count'=>count($items)];
    foreach ($items as $item) {
        if (!$item['isRead']) $counts['unread_count']++;
        $key = strtolower((string)$item['category']) . '_count';
        $counts[$key] = ($counts[$key] ?? 0) + 1;
    }
    jsonResponse(['success'=>true,'counts'=>$counts]);
} catch (Throwable $error) {
    structuredLog('ERROR', 'NOTIFICATION.OVERVIEW_FAILED', [
        'exception'=>get_class($error),
        'message'=>$error->getMessage(),
    ]);
    jsonResponse([
        'success'=>false,
        'message'=>'Could not load notification summary.',
        'error_code'=>'NOTIFICATION_OVERVIEW_FAILED',
    ],500);
}
