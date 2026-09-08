<?php
header('Content-Type: application/json');
require_once __DIR__ . '/../config/response.php';
require_once __DIR__ . '/../config/db.php';
require_once __DIR__ . '/../auth/auth_required.php';
require_once __DIR__ . '/../auth/role_helper.php';
require_once __DIR__ . '/../config/tenant_scope.php';

require_once __DIR__ . '/../invoices/workflow_schema.php';
require_once __DIR__ . '/../invoices/workflow_rules.php';


try {
    if ($_SERVER['REQUEST_METHOD'] !== 'POST') jsonResponse(['success' => false, 'message' => 'Method not allowed'], 405);
    $userId = (int)requireAuth()->id;
    $data = json_decode(file_get_contents('php://input'), true);
    if (!is_array($data)) throw new Exception('Invalid JSON body');
    $id = (int)($data['id'] ?? 0);
    $clientId = (int)($data['client_id'] ?? 0);
    $orderDate = trim((string)($data['order_date'] ?? date('Y-m-d')));
    $deliveryDate = trim((string)($data['expected_delivery_date'] ?? ''));
    $deliveryAddress = trim((string)($data['delivery_address'] ?? ''));
    $customerReference = trim((string)($data['customer_reference'] ?? ''));
    $sourceDevisId = (int)($data['source_devis_id'] ?? 0);
    $notes = trim((string)($data['notes'] ?? ''));
    $items = $data['items'] ?? [];
    $idempotencyKey=trim((string)($data['idempotency_key']??'')); if(strlen($idempotencyKey)>64)throw new Exception('Invalid idempotency key');
    if ($clientId <= 0) throw new Exception('Client is required');
    if (!is_array($items) || count($items) === 0) throw new Exception('At least one item is required');
    $conn = db();
    requirePermission($conn, $userId, $id > 0 ? 'orders.edit' : 'orders.create');
    ensureInvoiceWorkflowSchema($conn);
    $clientStmt = $conn->prepare('SELECT id FROM clients WHERE id = ? AND user_id = ? LIMIT 1');
    $clientStmt->bind_param('ii', $clientId, $userId);
    $clientStmt->execute();
    $client = $clientStmt->get_result()->fetch_assoc();
    $clientStmt->close();
    if (!$client) throw new Exception('Client not found or unauthorized');
    if ($sourceDevisId > 0) {
        $devisStmt = $conn->prepare("SELECT id, invoice_type FROM erp_invoices WHERE id = ? AND user_id = ? LIMIT 1");
        $devisStmt->bind_param('ii', $sourceDevisId, $userId);
        $devisStmt->execute();
        $devis = $devisStmt->get_result()->fetch_assoc();
        $devisStmt->close();
        if (!$devis || strtoupper((string)($devis['invoice_type'] ?? '')) !== 'DEVIS') {
            throw new Exception('Source devis not found or unauthorized');
        }
    }
    $conn->begin_transaction();
    if($id<=0&&$idempotencyKey!==''){$repeat=$conn->prepare('SELECT id FROM erp_sales_orders WHERE user_id=? AND idempotency_key=? LIMIT 1');$repeat->bind_param('is',$userId,$idempotencyKey);$repeat->execute();$existingRepeat=$repeat->get_result()->fetch_assoc();$repeat->close();if($existingRepeat){$conn->rollback();jsonResponse(['success'=>true,'id'=>(int)$existingRepeat['id'],'replayed'=>true]);}}
    if ($sourceDevisId > 0) validateOrderAgainstAcceptedDevis($conn,$sourceDevisId,$userId,$clientId,$items,$id);
    if ($id > 0) {
        $lock = $conn->prepare("SELECT status, IFNULL(source_devis_id, 0) AS source_devis_id FROM erp_sales_orders WHERE id = ? AND user_id = ? FOR UPDATE");
        $lock->bind_param('ii', $id, $userId); $lock->execute();
        $existing = $lock->get_result()->fetch_assoc(); $lock->close();
        if (!$existing) throw new Exception('Order not found or unauthorized');
        if ($existing['status'] !== 'DRAFT') throw new Exception('Only draft orders can be changed');
        if ($sourceDevisId <= 0) {
            $sourceDevisId = (int)($existing['source_devis_id'] ?? 0);
        }
        $stmt = $conn->prepare("UPDATE erp_sales_orders SET client_id=?, order_date=?, expected_delivery_date=NULLIF(?,''), delivery_address=?, customer_reference=?, source_devis_id=NULLIF(?,0), notes=? WHERE id=? AND user_id=?");
        $stmt->bind_param('issssisii', $clientId, $orderDate, $deliveryDate, $deliveryAddress, $customerReference, $sourceDevisId, $notes, $id, $userId);
        $stmt->execute(); $stmt->close();
        $clear = $conn->prepare('DELETE FROM erp_sales_order_items WHERE sales_order_id = ?');
        $clear->bind_param('i', $id); $clear->execute(); $clear->close();
    } else {
        $temporaryNumber = 'BC-TMP-' . bin2hex(random_bytes(5));
        $stmt = $conn->prepare("INSERT INTO erp_sales_orders (order_number,client_id,order_date,expected_delivery_date,delivery_address,customer_reference,source_devis_id,notes,status,user_id,idempotency_key) VALUES (?,?,?,NULLIF(?,''),?,?,NULLIF(?,0),?,'DRAFT',?,NULLIF(?,''))");
        $stmt->bind_param('sissssisis', $temporaryNumber, $clientId, $orderDate, $deliveryDate, $deliveryAddress, $customerReference, $sourceDevisId, $notes, $userId,$idempotencyKey);
        $stmt->execute(); $id = $stmt->insert_id; $stmt->close();
    }
    $subtotal = 0.0; $vat = 0.0; $total = 0.0;
    $itemStmt = $conn->prepare('INSERT INTO erp_sales_order_items (sales_order_id,product_id,product_code,product,qty,price,discount,tva_rate,subtotal,montant_tva,total) VALUES (?,NULLIF(?,0),?,?,?,?,?,?,?,?,?)');
    foreach ($items as $item) {
        $productId=(int)($item['product_id']??0); $code=trim((string)($item['product_code']??'')); $name=trim((string)($item['product']??''));
        requireTenantProduct($conn, $userId, $productId);
        $qty=(float)($item['qty']??0); $price=(float)($item['price']??0); $discount=(float)($item['discount']??0); $rate=(float)($item['tva_rate']??0);
        if ($name==='' || $qty<=0 || $price<0 || $discount<0 || $discount>100 || $rate<0) throw new Exception('Invalid order item');
        $lineSubtotal=round($qty*$price*(1-$discount/100),3); $lineVat=round($lineSubtotal*$rate/100,3); $lineTotal=round($lineSubtotal+$lineVat,3);
        $itemStmt->bind_param('iissddddddd',$id,$productId,$code,$name,$qty,$price,$discount,$rate,$lineSubtotal,$lineVat,$lineTotal);
        $itemStmt->execute(); $subtotal+=$lineSubtotal; $vat+=$lineVat; $total+=$lineTotal;
    }
    $itemStmt->close();
    $totals = $conn->prepare('UPDATE erp_sales_orders SET subtotal=?,montant_tva=?,total=? WHERE id=? AND user_id=?');
    $totals->bind_param('dddii',$subtotal,$vat,$total,$id,$userId); $totals->execute(); $totals->close();
    if ($sourceDevisId > 0) {
        recalculateDevisTransformationStatus($conn, $sourceDevisId, $userId);
    }
    $conn->commit();
    jsonResponse(['success'=>true,'id'=>$id,'message'=>'Bon de commande saved']);
} catch (Throwable $e) {
    if (isset($conn)) { try { $conn->rollback(); } catch (Throwable $ignored) {} }
    jsonResponse(['success'=>false,'message'=>$e->getMessage()],400);
}
