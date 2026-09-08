<?php

declare(strict_types=1);

header('Content-Type: application/json; charset=utf-8');
header('Cache-Control: no-store, private');
require_once __DIR__ . '/../config/response.php';
require_once __DIR__ . '/../config/db.php';
require_once __DIR__ . '/../config/pagination.php';
require_once __DIR__ . '/../auth/auth_required.php';
require_once __DIR__ . '/../auth/role_helper.php';
require_once __DIR__ . '/notification_service.php';

try {
    if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'GET') jsonResponse(['success'=>false,'message'=>'Method not allowed. Use GET.'],405);
    $auth = requireAuth();
    $tenantId = authTenantId($auth);
    $actorId = authActorId($auth);
    $conn = db();
    requirePermission($conn, $actorId, 'dashboard.view');
    [$page, $pageSize, $offset] = paginationInput($_GET);
    $search = mb_strtolower(trim((string)($_GET['search'] ?? '')));
    $category = strtoupper(trim((string)($_GET['category'] ?? '')));
    $readFilter = strtoupper(trim((string)($_GET['read'] ?? '')));

    $all = attachNotificationReadState($conn, $tenantId, $actorId, currentOperationalNotifications($conn, $tenantId, $actorId));
    $unreadCount = count(array_filter($all, static fn(array $item): bool => !$item['isRead']));
    $categoryCounts = [];
    foreach ($all as $item) $categoryCounts[$item['category']] = ($categoryCounts[$item['category']] ?? 0) + 1;
    $filtered = array_values(array_filter($all, static function (array $item) use ($search, $category, $readFilter): bool {
        if ($category !== '' && $item['category'] !== $category) return false;
        if ($readFilter === 'READ' && !$item['isRead']) return false;
        if ($readFilter === 'UNREAD' && $item['isRead']) return false;
        if ($search !== '' && !str_contains(mb_strtolower($item['title'] . ' ' . $item['body'] . ' ' . $item['entityNumber']), $search)) return false;
        return true;
    }));
    $total = count($filtered);
    paginatedResponse(array_slice($filtered, $offset, $pageSize), $page, $pageSize, $total, [
        'unread' => $unreadCount,
        'all' => count($all),
        'categories' => $categoryCounts,
    ]);
} catch (Throwable $error) {
    structuredLog('ERROR', 'NOTIFICATION.LIST_FAILED', ['exception'=>get_class($error),'message'=>$error->getMessage()]);
    jsonResponse(['success'=>false,'message'=>'Could not load notifications.','error_code'=>'NOTIFICATION_LIST_FAILED'],500);
}
