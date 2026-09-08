<?php

header('Content-Type: application/json');
require_once __DIR__ . '/../config/response.php';
require_once __DIR__ . '/../config/db.php';
require_once __DIR__ . '/../auth/auth_required.php';
require_once __DIR__ . '/../auth/role_helper.php';
require_once __DIR__ . '/../config/tenant_scope.php';
require_once __DIR__ . '/../taxes/tax_profile_service.php';

$debugStage = 'request';

try {
    if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'GET') jsonResponse(['success'=>false,'message'=>'Method not allowed'],405);
    $debugStage = 'authentication';
    $userId = (int)requireAuth()->id;
    $supplierId = (int)($_GET['supplier_id'] ?? 0);
    $orderId = (int)($_GET['supplier_order_id'] ?? 0);
    if ($supplierId <= 0) jsonResponse(['success'=>false,'message'=>'A supplier is required.'],422);
    $conn = db();
    $debugStage = 'authorization';
    requireAnyPermission($conn, $userId, ['supplierInvoices.view','supplierInvoices.create']);
    requireTenantSupplier($conn, $userId, $supplierId);
    if ($orderId > 0) requireTenantSupplierOrder($conn, $userId, $orderId, $supplierId);
    ensureTaxProfileSchema($conn);

    $debugStage = 'supplier_orders';
    $ordersStmt = $conn->prepare("SELECT so.id,so.order_number,so.order_date,so.status,so.total,
        (SELECT COUNT(*) FROM erp_supplier_receptions sr WHERE sr.supplier_order_id=so.id AND sr.user_id=so.user_id AND sr.stock_applied=1) reception_count
        FROM erp_supplier_orders so WHERE so.user_id=? AND so.supplier_id=? AND so.status IN('SENT','PARTIALLY_RECEIVED','RECEIVED') ORDER BY so.id DESC LIMIT 100");
    $ordersStmt->bind_param('ii', $userId, $supplierId);
    $ordersStmt->execute();
    $orders = array_map(static fn(array $row): array => [
        'id'=>(int)$row['id'], 'orderNumber'=>(string)$row['order_number'], 'orderDate'=>(string)$row['order_date'],
        'status'=>(string)$row['status'], 'total'=>round((float)$row['total'],3), 'receptionCount'=>(int)$row['reception_count'],
    ], $ordersStmt->get_result()->fetch_all(MYSQLI_ASSOC));
    $ordersStmt->close();

    $lines = [];
    if ($orderId > 0) {
        $debugStage = 'matching_lines';
        $stmt = $conn->prepare("SELECT sri.id reception_item_id,sr.id reception_id,sr.invoice_number reception_number,
            sr.received_date,sri.catalog_id product_id,sri.code,sri.name description,sri.unit,
            sri.accepted_qty,sri.price reception_price,sri.tva_rate,
            COALESCE(p.tax_profile_id,(
                SELECT tp.id FROM erp_tax_profiles tp
                WHERE tp.user_id=sr.user_id AND ABS(tp.vat_rate-sri.tva_rate)<=0.0005
                  AND tp.effective_from<=sr.received_date
                  AND (tp.effective_to IS NULL OR tp.effective_to>=sr.received_date)
                ORDER BY tp.effective_from DESC,tp.id DESC LIMIT 1
            )) tax_profile_id,
            COALESCE((SELECT soi.qty FROM erp_supplier_order_items soi WHERE soi.supplier_order_id=sr.supplier_order_id AND (
                (COALESCE(sri.catalog_id,0)>0 AND soi.catalog_id=sri.catalog_id)
                OR (TRIM(COALESCE(sri.code,''))<>'' AND soi.product_code=sri.code)
                OR (TRIM(COALESCE(sri.code,''))='' AND soi.description=sri.name)
            ) ORDER BY soi.id LIMIT 1),sri.ordered_qty) order_qty,
            COALESCE((SELECT soi.price FROM erp_supplier_order_items soi WHERE soi.supplier_order_id=sr.supplier_order_id AND (
                (COALESCE(sri.catalog_id,0)>0 AND soi.catalog_id=sri.catalog_id)
                OR (TRIM(COALESCE(sri.code,''))<>'' AND soi.product_code=sri.code)
                OR (TRIM(COALESCE(sri.code,''))='' AND soi.description=sri.name)
            ) ORDER BY soi.id LIMIT 1),sri.price) order_price,
            COALESCE((SELECT SUM(sii.quantity) FROM erp_supplier_invoice_items sii JOIN erp_supplier_invoices si ON si.id=sii.supplier_invoice_id WHERE sii.supplier_reception_item_id=sri.id AND si.user_id=sr.user_id AND si.status<>'CANCELLED'),0) billed_qty,
            COALESCE((SELECT SUM(srit.quantity) FROM erp_supplier_return_items srit JOIN erp_supplier_returns sret ON sret.id=srit.supplier_return_id WHERE srit.supplier_reception_item_id=sri.id AND sret.user_id=sr.user_id AND sret.status='CONFIRMED'),0) returned_qty
            FROM erp_supplier_receptions sr
            JOIN erp_supplier_reception_items sri ON sri.supplier_reception_id=sr.id
            LEFT JOIN products p ON p.id=sri.catalog_id AND p.user_id=sr.user_id
            WHERE sr.user_id=? AND sr.supplier_id=? AND sr.supplier_order_id=? AND sr.status='REVIEWED' AND sr.stock_applied=1
            ORDER BY sr.received_date,sr.id,sri.id");
        $stmt->bind_param('iii', $userId, $supplierId, $orderId);
        $stmt->execute();
        foreach ($stmt->get_result()->fetch_all(MYSQLI_ASSOC) as $row) {
            $available = max(0, round((float)$row['accepted_qty'] - (float)$row['billed_qty'] - (float)$row['returned_qty'], 3));
            $lines[] = [
                'receptionItemId'=>(int)$row['reception_item_id'], 'receptionId'=>(int)$row['reception_id'],
                'receptionNumber'=>(string)$row['reception_number'], 'receivedDate'=>(string)$row['received_date'],
                'productId'=>(int)($row['product_id'] ?? 0), 'taxProfileId'=>(int)($row['tax_profile_id'] ?? 0),
                'code'=>(string)$row['code'], 'description'=>(string)$row['description'], 'unit'=>(string)$row['unit'],
                'orderedQty'=>round((float)$row['order_qty'],3), 'receivedQty'=>round((float)$row['accepted_qty'],3),
                'billedQty'=>round((float)$row['billed_qty'],3), 'returnedQty'=>round((float)$row['returned_qty'],3),
                'availableQty'=>$available, 'orderPrice'=>round((float)$row['order_price'],3),
                'receptionPrice'=>round((float)$row['reception_price'],3), 'vatRate'=>round((float)$row['tva_rate'],3),
            ];
        }
        $stmt->close();
    }
    $debugStage = 'response';
    jsonResponse(['success'=>true,'orders'=>$orders,'lines'=>$lines]);
} catch (Throwable $error) {
    structuredLog('ERROR', 'SUPPLIER_INVOICE.MATCHING_OPTIONS_FAILED', [
        'stage' => $debugStage,
        'exception' => get_class($error),
        'message' => $error->getMessage(),
        'supplier_id' => $supplierId ?? 0,
        'supplier_order_id' => $orderId ?? 0,
    ]);
    jsonResponse(['success'=>false,'message'=>'Could not load supplier matching options.','error_code'=>'SUPPLIER_MATCH_OPTIONS_FAILED'],500);
}
