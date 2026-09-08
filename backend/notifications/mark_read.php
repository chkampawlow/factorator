<?php

declare(strict_types=1);

header('Content-Type: application/json; charset=utf-8');
header('Cache-Control: no-store, private');
require_once __DIR__ . '/../config/response.php';
require_once __DIR__ . '/../config/db.php';
require_once __DIR__ . '/../config/audit.php';
require_once __DIR__ . '/../auth/auth_required.php';
require_once __DIR__ . '/../auth/role_helper.php';
require_once __DIR__ . '/notification_service.php';

try {
    if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'POST') jsonResponse(['success'=>false,'message'=>'Method not allowed. Use POST.'],405);
    if ((int)($_SERVER['CONTENT_LENGTH'] ?? 0) > 32768) throw new InvalidArgumentException('Request is too large.');
    $auth = requireAuth();
    $tenantId = authTenantId($auth);
    $actorId = authActorId($auth);
    $conn = db();
    requirePermission($conn, $actorId, 'dashboard.view');
    $body = json_decode((string)file_get_contents('php://input'), true);
    if (!is_array($body)) throw new InvalidArgumentException('Invalid JSON body.');
    $action = strtoupper(trim((string)($body['action'] ?? 'READ')));
    if (!in_array($action, ['READ','UNREAD','READ_ALL'], true)) throw new InvalidArgumentException('Invalid notification action.');
    $current = currentOperationalNotifications($conn, $tenantId, $actorId);
    $allowed = array_fill_keys(array_column($current, 'key'), true);
    $requested = $action === 'READ_ALL' ? array_keys($allowed) : (array)($body['keys'] ?? []);
    if (count($requested) > 300) throw new InvalidArgumentException('Too many notification keys.');
    $keys = array_values(array_filter(array_map('strval', $requested), static fn(string $key): bool => isset($allowed[$key])));
    if (!$keys && $action !== 'READ_ALL') throw new InvalidArgumentException('No current notification was selected.');

    $conn->begin_transaction();
    $updated = setNotificationReadState($conn, $tenantId, $actorId, $keys, $action !== 'UNREAD');
    auditLog($conn, $tenantId, $actorId, 'NOTIFICATION.' . $action, 'NOTIFICATION', null, null, ['count'=>$updated]);
    $conn->commit();
    $withState = attachNotificationReadState($conn, $tenantId, $actorId, $current);
    $unread = count(array_filter($withState, static fn(array $item): bool => !$item['isRead']));
    jsonResponse(['success'=>true,'updated'=>$updated,'unread'=>$unread]);
} catch (NotificationReadStateUnavailable $error) {
    if (isset($conn) && $conn instanceof mysqli) try { $conn->rollback(); } catch (Throwable) {}
    jsonResponse([
        'success'=>false,
        'message'=>'Notification read state is temporarily unavailable.',
        'error_code'=>'NOTIFICATION_READ_STATE_UNAVAILABLE',
    ],503);
} catch (InvalidArgumentException $error) {
    if (isset($conn) && $conn instanceof mysqli) try { $conn->rollback(); } catch (Throwable) {}
    jsonResponse(['success'=>false,'message'=>$error->getMessage(),'code'=>'INVALID_NOTIFICATION_ACTION'],422);
} catch (Throwable $error) {
    if (isset($conn) && $conn instanceof mysqli) try { $conn->rollback(); } catch (Throwable) {}
    structuredLog('ERROR', 'NOTIFICATION.MARK_FAILED', ['exception'=>get_class($error),'message'=>$error->getMessage()]);
    jsonResponse(['success'=>false,'message'=>'Could not update notifications.','error_code'=>'NOTIFICATION_UPDATE_FAILED'],500);
}
