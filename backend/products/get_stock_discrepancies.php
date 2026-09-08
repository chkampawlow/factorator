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

    $baseSql = "FROM products p
        LEFT JOIN (
            SELECT user_id, product_id, ROUND(COALESCE(SUM(quantity),0),3) ledger_quantity,
                   COUNT(*) movement_count, MAX(created_at) last_movement_at
            FROM product_stock_movements
            GROUP BY user_id, product_id
        ) ledger ON ledger.user_id=p.user_id AND ledger.product_id=p.id
        WHERE p.user_id=?
          AND ABS(p.stock_quantity - CASE WHEN p.item_type='PRODUCT'
              THEN COALESCE(ledger.ledger_quantity,0) ELSE 0 END) >= 0.0005";

    $count = $conn->prepare("SELECT COUNT(*) total $baseSql");
    $count->bind_param('i', $userId);
    $count->execute();
    $total = (int) $count->get_result()->fetch_assoc()['total'];
    $count->close();

    $stmt = $conn->prepare("SELECT p.id, p.code, p.name, p.item_type,
            p.stock_quantity stored_quantity,
            CASE WHEN p.item_type='PRODUCT' THEN COALESCE(ledger.ledger_quantity,0) ELSE 0 END ledger_quantity,
            ROUND(p.stock_quantity - CASE WHEN p.item_type='PRODUCT'
                THEN COALESCE(ledger.ledger_quantity,0) ELSE 0 END,3) variance,
            COALESCE(ledger.movement_count,0) movement_count,
            ledger.last_movement_at
        $baseSql
        ORDER BY ABS(p.stock_quantity - CASE WHEN p.item_type='PRODUCT'
            THEN COALESCE(ledger.ledger_quantity,0) ELSE 0 END) DESC, p.id
        LIMIT ? OFFSET ?");
    $stmt->bind_param('iii', $userId, $pageSize, $offset);
    $stmt->execute();
    $rows = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);
    $stmt->close();

    paginatedResponse($rows, $page, $pageSize, $total, [
        'status' => $total === 0 ? 'RECONCILED' : 'DISCREPANCIES_FOUND',
        'tolerance' => '0.0005',
        'ledger_is_authoritative' => true,
    ]);
} catch (Throwable $e) {
    jsonResponse(['success' => false, 'message' => 'Could not load stock discrepancies.'], 500);
}
