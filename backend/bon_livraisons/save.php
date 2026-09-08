<?php
header('Content-Type: application/json');
require_once __DIR__ . '/../config/response.php';
require_once __DIR__ . '/../config/db.php';
require_once __DIR__ . '/../auth/auth_required.php';
require_once __DIR__ . '/../auth/role_helper.php';
require_once __DIR__ . '/../config/tenant_scope.php';

require_once __DIR__ . '/helpers.php';
require_once __DIR__ . '/../invoices/workflow_rules.php';


try {
    if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
        jsonResponse(['success' => false, 'message' => 'Method not allowed'], 405);
    }

    $userId = (int)requireAuth()->id;
    $data = json_decode(file_get_contents('php://input'), true);
    if (!is_array($data)) throw new Exception('Invalid JSON body');

    $id = (int)($data['id'] ?? 0);
    $clientId = (int)($data['client_id'] ?? 0);
    $salesOrderId = (int)($data['sales_order_id'] ?? 0);
    $documentType = strtoupper(trim((string)($data['document_type'] ?? 'DELIVERY')));
    $deliveryDate = trim((string)($data['delivery_date'] ?? date('Y-m-d')));
    $expectedDeliveryDate = trim((string)($data['expected_delivery_date'] ?? ''));
    $deliveryAddress = trim((string)($data['delivery_address'] ?? ''));
    $vehicleRegistration = trim((string)($data['vehicle_registration'] ?? ''));
    $customerReference = trim((string)($data['customer_reference'] ?? ''));
    $movementReason = trim((string)($data['movement_reason'] ?? ''));
    $notes = trim((string)($data['notes'] ?? ''));
    $items = $data['items'] ?? [];
    $idempotencyKey=trim((string)($data['idempotency_key']??'')); if(strlen($idempotencyKey)>64)throw new Exception('Invalid idempotency key');

    if ($clientId <= 0) throw new Exception('Client is required');
    if (!is_array($items) || count($items) === 0) throw new Exception('At least one item is required');
    if (!in_array($documentType, ['DELIVERY', 'EXIT'], true)) throw new Exception('Invalid document type');
    if ($documentType === 'EXIT' && $vehicleRegistration === '') throw new Exception('Vehicle registration is required for bon de sortie');
    if ($documentType === 'EXIT' && $movementReason === '') throw new Exception('Movement reason is required for bon de sortie');

    $conn = db();
    requirePermission($conn, $userId, $id > 0 ? 'deliveries.edit' : 'deliveries.create');
    ensureDeliverySchema($conn);
    $clientStmt = $conn->prepare('SELECT id FROM clients WHERE id = ? AND user_id = ? LIMIT 1');
    $clientStmt->bind_param('ii', $clientId, $userId);
    $clientStmt->execute();
    $client = $clientStmt->get_result()->fetch_assoc();
    $clientStmt->close();
    if (!$client) throw new Exception('Client not found or unauthorized');

    if ($salesOrderId > 0) {
        $orderStmt = $conn->prepare('SELECT id, client_id, status FROM erp_sales_orders WHERE id = ? AND user_id = ? LIMIT 1');
        $orderStmt->bind_param('ii', $salesOrderId, $userId);
        $orderStmt->execute();
        $order = $orderStmt->get_result()->fetch_assoc();
        $orderStmt->close();
        if (!$order) throw new Exception('Sales order not found or unauthorized');
        if ((int)$order['client_id'] !== $clientId) throw new Exception('Delivery note client must match the linked sales order');
        if (!in_array((string)$order['status'], ['CONFIRMED', 'PARTIALLY_DELIVERED'], true)) {
            throw new Exception('Only confirmed sales orders can be linked to delivery notes');
        }
    }

    $conn->begin_transaction();
    if($id<=0&&$idempotencyKey!==''){$repeat=$conn->prepare('SELECT id FROM erp_delivery_notes WHERE user_id=? AND idempotency_key=? LIMIT 1');$repeat->bind_param('is',$userId,$idempotencyKey);$repeat->execute();$existingRepeat=$repeat->get_result()->fetch_assoc();$repeat->close();if($existingRepeat){$conn->rollback();jsonResponse(['success'=>true,'id'=>(int)$existingRepeat['id'],'replayed'=>true]);}}
    if ($salesOrderId > 0) validateDeliveryAgainstOrder($conn,$salesOrderId,$userId,$clientId,$items,$id);

    if ($id > 0) {
        $lock = $conn->prepare("SELECT status FROM erp_delivery_notes WHERE id = ? AND user_id = ? FOR UPDATE");
        $lock->bind_param('ii', $id, $userId);
        $lock->execute();
        $existing = $lock->get_result()->fetch_assoc();
        $lock->close();
        if (!$existing) throw new Exception('Delivery note not found or unauthorized');
        if ($existing['status'] !== 'DRAFT') throw new Exception('Only draft delivery notes can be changed');

        $stmt = $conn->prepare("UPDATE erp_delivery_notes
            SET client_id = ?, sales_order_id = NULLIF(?, 0), document_type = ?, delivery_date = ?, expected_delivery_date = NULLIF(?, ''), delivery_address = ?, vehicle_registration = ?, customer_reference = ?, movement_reason = ?, notes = ?, stock_applied = 0
            WHERE id = ? AND user_id = ?");
        $stmt->bind_param('iissssssssii', $clientId, $salesOrderId, $documentType, $deliveryDate, $expectedDeliveryDate, $deliveryAddress, $vehicleRegistration, $customerReference, $movementReason, $notes, $id, $userId);
        $stmt->execute();
        $stmt->close();

        $clear = $conn->prepare('DELETE FROM erp_delivery_note_items WHERE delivery_note_id = ?');
        $clear->bind_param('i', $id);
        $clear->execute();
        $clear->close();
    } else {
        $temporaryNumber = 'BL-TMP-' . bin2hex(random_bytes(5));
        $stmt = $conn->prepare("INSERT INTO erp_delivery_notes
            (delivery_number, document_type, client_id, sales_order_id, delivery_date, expected_delivery_date, delivery_address, vehicle_registration, customer_reference, movement_reason, notes, status, user_id,idempotency_key)
            VALUES (?, ?, ?, NULLIF(?, 0), ?, NULLIF(?, ''), ?, ?, ?, ?, ?, 'DRAFT', ?,NULLIF(?,''))");
        $stmt->bind_param('ssiisssssssis', $temporaryNumber, $documentType, $clientId, $salesOrderId, $deliveryDate, $expectedDeliveryDate, $deliveryAddress, $vehicleRegistration, $customerReference, $movementReason, $notes, $userId,$idempotencyKey);
        $stmt->execute();
        $id = $stmt->insert_id;
        $stmt->close();

    }

    $itemCount = 0;
    $itemStmt = $conn->prepare('
        INSERT INTO erp_delivery_note_items (
            delivery_note_id,
            product_id,
            product_code,
            product,
            qty,
            price,
            discount,
            tva_rate,
            subtotal,
            montant_tva,
            total,
            unit
        ) VALUES (?, NULLIF(?, 0), ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ');
    foreach ($items as $item) {
        $productId = (int)($item['product_id'] ?? 0);
        requireTenantProduct($conn, $userId, $productId);
        $code = trim((string)($item['product_code'] ?? ''));
        $name = trim((string)($item['product'] ?? ''));
        $qty = (float)($item['qty'] ?? 0);
        $price = (float)($item['price'] ?? 0);
        $discount = (float)($item['discount'] ?? 0);
        $tvaRate = (float)($item['tva_rate'] ?? 0);
        $unit = trim((string)($item['unit'] ?? ''));
        if ($name === '' || $qty <= 0) throw new Exception('Invalid delivery item');
        if ($price < 0 || $discount < 0 || $discount > 100 || $tvaRate < 0) throw new Exception('Invalid delivery item values');

        $subtotal = round($qty * $price * (1 - ($discount / 100)), 3);
        $montantTva = round($subtotal * ($tvaRate / 100), 3);
        $total = round($subtotal + $montantTva, 3);

        $itemStmt->bind_param(
            'iissddddddds',
            $id,
            $productId,
            $code,
            $name,
            $qty,
            $price,
            $discount,
            $tvaRate,
            $subtotal,
            $montantTva,
            $total,
            $unit
        );
        $itemStmt->execute();
        $itemCount++;
    }
    $itemStmt->close();

    $countStmt = $conn->prepare('UPDATE erp_delivery_notes SET item_count = ? WHERE id = ? AND user_id = ?');
    $countStmt->bind_param('iii', $itemCount, $id, $userId);
    $countStmt->execute();
    $countStmt->close();

    if ($salesOrderId > 0) {
        recalculateSalesOrderDeliveryStatus($conn, $salesOrderId, $userId);
    }

    $conn->commit();

    jsonResponse(['success' => true, 'id' => $id, 'message' => 'Delivery note saved']);
} catch (Throwable $e) {
    if (isset($conn)) {
        try {
            $conn->rollback();
        } catch (Throwable $ignored) {
        }
    }
    jsonResponse(['success' => false, 'message' => $e->getMessage()], 400);
}
