<?php

declare(strict_types=1);
require_once __DIR__ . '/../config/response.php';
require_once __DIR__ . '/../config/db.php';
require_once __DIR__ . '/../auth/auth_required.php';
require_once __DIR__ . '/../auth/role_helper.php';
require_once __DIR__ . '/revenue_series.php';

try {
    if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'GET') {
        jsonResponse(['success' => false, 'message' => 'Method not allowed.'], 405);
    }
    $auth = requireAuth();
    $tenantId = authTenantId($auth);
    $conn = db();
    requirePermission($conn, authActorId($auth), 'dashboard.view');
    requireAnyPermission($conn, authActorId($auth), ['invoices.view', 'reports.view']);
    $month = new DateTimeImmutable('first day of this month');
    $start = $month->modify('-7 months')->format('Y-m-01');
    $end = $month->modify('+1 month')->format('Y-m-01');
    $stmt = $conn->prepare("SELECT DATE_FORMAT(invoice_date, '%Y-%m') month,
        ROUND(COALESCE(SUM(CASE WHEN invoice_type='AVOIR' THEN -ABS(subtotal_tnd)
            ELSE subtotal_tnd END),0),3) revenue
        FROM erp_invoices WHERE user_id=? AND invoice_date>=? AND invoice_date<?
        AND invoice_type IN ('FACTURE','AVOIR') AND is_validated=1
        AND UPPER(status)<>'CANCELLED'
        GROUP BY DATE_FORMAT(invoice_date, '%Y-%m') ORDER BY month");
    $stmt->bind_param('iss', $tenantId, $start, $end);
    $stmt->execute();
    $rows = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);
    $stmt->close();
    jsonResponse(['success' => true, 'monthly_series' =>
        dashboardMonthlyRevenueSeries($rows, $month->format('Y-m-01'), 8)]);
} catch (Throwable $error) {
    jsonResponse(['success' => false, 'message' => 'Could not load revenue history.'], resourceExceptionStatus($error));
}
