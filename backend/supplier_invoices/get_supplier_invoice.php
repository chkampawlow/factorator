<?php

header('Content-Type: application/json');
require_once __DIR__ . '/../config/response.php';
require_once __DIR__ . '/../config/db.php';
require_once __DIR__ . '/../auth/auth_required.php';
require_once __DIR__ . '/../auth/role_helper.php';
require_once __DIR__ . '/invoice_service.php';

try {
    if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'GET') jsonResponse(['success'=>false,'message'=>'Method not allowed'],405);
    $userId = (int)requireAuth()->id;
    $invoiceId = (int)($_GET['id'] ?? 0);
    if ($invoiceId <= 0) jsonResponse(['success'=>false,'message'=>'A supplier invoice id is required.'],422);
    $conn = db();
    requirePermission($conn, $userId, 'supplierInvoices.view');
    $query = $conn->prepare(supplierInvoiceHeaderSelect() . ' WHERE si.user_id=? AND si.id=? LIMIT 1');
    $query->bind_param('ii', $userId, $invoiceId);
    $query->execute();
    $rawInvoice = $query->get_result()->fetch_assoc();
    $query->close();
    if (!$rawInvoice) jsonResponse(['success'=>false,'message'=>'Supplier invoice not found.'],404);
    $invoice = supplierInvoiceListRow($rawInvoice);
    $invoice['notes'] = (string)($rawInvoice['notes'] ?? '');
    $invoice['stampDuty'] = round((float)($rawInvoice['stamp_duty'] ?? 0),3);
    $invoice['exchangeRateDate'] = (string)($rawInvoice['exchange_rate_date'] ?? '');

    $items = $conn->prepare("SELECT sii.id,sii.supplier_reception_item_id,sii.product_id,sii.description,sii.quantity,sii.unit_price,sii.vat_rate,sii.total_ht,sii.total_vat,sii.total_ttc,
        sri.supplier_reception_id,sri.accepted_qty,sri.price reception_price,sr.invoice_number reception_number,sr.received_date,
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
        COALESCE((SELECT SUM(ri.quantity) FROM erp_supplier_return_items ri JOIN erp_supplier_returns r ON r.id=ri.supplier_return_id WHERE ri.supplier_reception_item_id=sri.id AND r.status='CONFIRMED' AND r.user_id=?),0) returned_qty,
        COALESCE((SELECT SUM(all_items.quantity) FROM erp_supplier_invoice_items all_items JOIN erp_supplier_invoices all_invoices ON all_invoices.id=all_items.supplier_invoice_id WHERE all_items.supplier_reception_item_id=sri.id AND all_invoices.user_id=? AND all_invoices.status<>'CANCELLED'),0) total_billed_qty
        FROM erp_supplier_invoice_items sii
        LEFT JOIN erp_supplier_reception_items sri ON sri.id=sii.supplier_reception_item_id
        LEFT JOIN erp_supplier_receptions sr ON sr.id=sri.supplier_reception_id AND sr.user_id=?
        WHERE sii.supplier_invoice_id=? ORDER BY sii.id");
    $items->bind_param('iiii', $userId, $userId, $userId, $invoiceId);
    $items->execute();
    $lineRows = [];
    foreach ($items->get_result()->fetch_all(MYSQLI_ASSOC) as $row) {
        $receivedQty = round((float)($row['accepted_qty'] ?? 0),3);
        $invoiceQty = round((float)$row['quantity'],3);
        $orderPrice = round((float)($row['order_price'] ?? $row['reception_price'] ?? 0),3);
        $invoicePrice = round((float)$row['unit_price'],3);
        $matched = !empty($row['supplier_reception_item_id']);
        $totalBilledQty = round((float)($row['total_billed_qty'] ?? $invoiceQty),3);
        $lineMatchStatus = !$matched ? 'UNMATCHED' : (abs($invoicePrice-$orderPrice)>0.0005||$totalBilledQty>$receivedQty+0.0005 ? 'VARIANCE' : ($totalBilledQty<$receivedQty-0.0005 ? 'PARTIAL' : 'MATCHED'));
        $lineRows[] = [
            'id'=>(int)$row['id'], 'receptionItemId'=>(int)($row['supplier_reception_item_id'] ?? 0),
            'receptionId'=>(int)($row['supplier_reception_id'] ?? 0), 'receptionNumber'=>(string)($row['reception_number'] ?? ''),
            'receivedDate'=>(string)($row['received_date'] ?? ''), 'productId'=>(int)($row['product_id'] ?? 0),
            'description'=>(string)$row['description'], 'orderedQty'=>round((float)($row['order_qty'] ?? 0),3),
            'receivedQty'=>$receivedQty, 'invoiceQty'=>$invoiceQty, 'returnedQty'=>round((float)$row['returned_qty'],3),
            'orderPrice'=>$orderPrice, 'receptionPrice'=>round((float)($row['reception_price'] ?? 0),3), 'invoicePrice'=>$invoicePrice,
            'totalBilledQty'=>$totalBilledQty, 'quantityVariance'=>round($totalBilledQty-$receivedQty,3), 'priceVariance'=>round($invoicePrice-$orderPrice,3),
            'vatRate'=>round((float)$row['vat_rate'],3), 'totalHt'=>round((float)$row['total_ht'],3),
            'totalVat'=>round((float)$row['total_vat'],3), 'totalTtc'=>round((float)$row['total_ttc'],3),
            'matchStatus'=>$lineMatchStatus,
        ];
    }
    $items->close();

    $paymentsStmt = $conn->prepare('SELECT id,amount,exchange_rate,exchange_rate_date,amount_tnd,payment_date,method,account,reference_number,created_at FROM erp_supplier_payments WHERE user_id=? AND supplier_invoice_id=? AND voided_at IS NULL ORDER BY payment_date,id');
    $paymentsStmt->bind_param('ii',$userId,$invoiceId);$paymentsStmt->execute();$payments=$paymentsStmt->get_result()->fetch_all(MYSQLI_ASSOC);$paymentsStmt->close();
    $creditsStmt = $conn->prepare("SELECT id,supplier_return_id,credit_number,credit_date,amount,status,notes,created_at FROM erp_supplier_credit_notes WHERE user_id=? AND supplier_invoice_id=? AND status<>'CANCELLED' ORDER BY credit_date,id");
    $creditsStmt->bind_param('ii',$userId,$invoiceId);$creditsStmt->execute();$credits=$creditsStmt->get_result()->fetch_all(MYSQLI_ASSOC);$creditsStmt->close();
    $receptionIds = array_values(array_unique(array_filter(array_map(static fn(array $line): int => (int)$line['receptionId'],$lineRows))));
    $returns=[];
    if($receptionIds){$idSql=implode(',',$receptionIds);$returnsResult=$conn->query("SELECT r.id,r.supplier_reception_id,r.return_date,r.reason,r.status,r.confirmed_at,ROUND(SUM(ri.quantity),3) quantity FROM erp_supplier_returns r JOIN erp_supplier_return_items ri ON ri.supplier_return_id=r.id WHERE r.user_id=".(int)$userId." AND r.supplier_reception_id IN($idSql) GROUP BY r.id ORDER BY r.id DESC");$returns=$returnsResult->fetch_all(MYSQLI_ASSOC);$returnsResult->close();}
    jsonResponse(['success'=>true,'invoice'=>$invoice,'items'=>$lineRows,'payments'=>$payments,'credits'=>$credits,'returns'=>$returns]);
} catch (Throwable $error) {
    jsonResponse(['success'=>false,'message'=>'Could not load supplier invoice.','error_code'=>'SUPPLIER_INVOICE_GET_FAILED'],500);
}
