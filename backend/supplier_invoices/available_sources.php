<?php

declare(strict_types=1);

header('Content-Type: application/json; charset=utf-8');

require_once __DIR__ . '/../config/response.php';
require_once __DIR__ . '/../config/db.php';
require_once __DIR__ . '/../auth/auth_required.php';
require_once __DIR__ . '/../auth/role_helper.php';

try {
    if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'GET') {
        jsonResponse(['success' => false, 'message' => 'Method not allowed'], 405);
    }

    $userId = (int) requireAuth()->id;
    $conn = db();
    requireAnyPermission($conn, $userId, ['supplierInvoices.view', 'supplierInvoices.create']);

    $statement = $conn->prepare("SELECT
            sr.supplier_id AS supplierId,
            s.name AS supplierName,
            sr.supplier_order_id AS orderId,
            so.order_number AS orderNumber,
            COUNT(sri.id) AS lineCount,
            ROUND(SUM(GREATEST(sri.accepted_qty - COALESCE(billed.billed_qty, 0), 0)), 3) AS availableQty,
            ROUND(SUM(GREATEST(sri.accepted_qty - COALESCE(billed.billed_qty, 0), 0) * sri.price), 3) AS projectedHt,
            MAX(sr.received_date) AS latestReceptionDate
        FROM erp_supplier_receptions sr
        INNER JOIN suppliers s ON s.id = sr.supplier_id AND s.user_id = sr.user_id
        INNER JOIN erp_supplier_orders so ON so.id = sr.supplier_order_id AND so.user_id = sr.user_id
        INNER JOIN erp_supplier_reception_items sri ON sri.supplier_reception_id = sr.id
        LEFT JOIN (
            SELECT sii.supplier_reception_item_id, SUM(sii.quantity) AS billed_qty
            FROM erp_supplier_invoice_items sii
            INNER JOIN erp_supplier_invoices si ON si.id = sii.supplier_invoice_id
            WHERE si.user_id = ? AND si.status <> 'CANCELLED'
            GROUP BY sii.supplier_reception_item_id
        ) billed ON billed.supplier_reception_item_id = sri.id
        WHERE sr.user_id = ?
          AND sr.status = 'REVIEWED'
          AND sr.stock_applied = 1
          AND sr.supplier_order_id IS NOT NULL
        GROUP BY sr.supplier_id, s.name, sr.supplier_order_id, so.order_number
        HAVING SUM(GREATEST(sri.accepted_qty - COALESCE(billed.billed_qty, 0), 0)) > 0.0005
        ORDER BY latestReceptionDate DESC, orderId DESC
        LIMIT 20");
    $statement->bind_param('ii', $userId, $userId);
    $statement->execute();
    $sources = array_map(static fn(array $row): array => [
        'supplierId' => (int) $row['supplierId'],
        'supplierName' => (string) $row['supplierName'],
        'orderId' => (int) $row['orderId'],
        'orderNumber' => (string) $row['orderNumber'],
        'lineCount' => (int) $row['lineCount'],
        'availableQty' => round((float) $row['availableQty'], 3),
        'projectedHt' => round((float) $row['projectedHt'], 3),
        'latestReceptionDate' => (string) $row['latestReceptionDate'],
    ], $statement->get_result()->fetch_all(MYSQLI_ASSOC));
    $statement->close();

    jsonResponse(['success' => true, 'sources' => $sources]);
} catch (Throwable $error) {
    jsonResponse(['success' => false, 'message' => 'Could not load supplier invoice sources.'], 500);
}
