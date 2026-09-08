<?php
header('Content-Type: application/json');

require_once __DIR__ . '/../config/response.php';
require_once __DIR__ . '/../config/db.php';
require_once __DIR__ . '/../config/idempotency.php';
require_once __DIR__ . '/../config/audit.php';
require_once __DIR__ . '/../auth/auth_required.php';
require_once __DIR__ . '/../auth/role_helper.php';
require_once __DIR__ . '/../config/tenant_scope.php';
require_once __DIR__ . '/../products/product_inventory.php';

try {
    if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
        throw new Exception('Method not allowed');
    }

    $userId = (int)requireAuth()->id;
    $data = json_decode(file_get_contents('php://input'), true) ?: [];
    $supplierId = (int)($data['supplier_id'] ?? 0);
    $receptionId = (int)($data['supplier_reception_id'] ?? 0);
    $date = (string)($data['return_date'] ?? '');
    $reason = trim((string)($data['reason'] ?? ''));
    $lines = $data['lines'] ?? [];
    $key = requiredIdempotencyKey($data);

    if ($supplierId <= 0 || $receptionId <= 0 || !preg_match('/^\\d{4}-\\d{2}-\\d{2}$/', $date)
        || $reason === '' || !is_array($lines) || !$lines) {
        throw new Exception('Supplier, reception, date, reason and lines are required');
    }

    $conn = db();
    requirePermission($conn, $userId, 'supplierReturns.confirm');
    requireTenantSupplier($conn, $userId, $supplierId);
    ensureProductInventorySchema($conn);
    $conn->begin_transaction();

    $hash = idempotencyRequestHash(['supplier_id' => $supplierId, 'supplier_reception_id' => $receptionId, 'return_date' => $date, 'reason' => $reason, 'lines' => $lines]);
    $replayedId = claimIdempotencyKey($conn, $userId, 'supplier.return.confirm', $key, $hash);
    if ($replayedId !== null) {
        $conn->commit();
        jsonResponse(['success' => true, 'supplier_return_id' => $replayedId, 'replayed' => true]);
    }

    $stmt = $conn->prepare('SELECT id FROM erp_supplier_receptions WHERE id=? AND supplier_id=? AND user_id=? AND stock_applied=1 FOR UPDATE');
    $stmt->bind_param('iii', $receptionId, $supplierId, $userId);
    $stmt->execute();
    $reception = $stmt->get_result()->fetch_assoc();
    $stmt->close();
    if (!$reception) {
        throw new Exception('A confirmed stock reception is required');
    }

    $normalizedLines = [];
    $seenItems = [];
    $lineCheck = $conn->prepare("
        SELECT
            sri.accepted_qty AS received_quantity,
            sri.catalog_id,
            COALESCE(SUM(CASE WHEN sr.status = 'CONFIRMED' THEN sri2.quantity ELSE 0 END), 0) AS returned_quantity
        FROM erp_supplier_reception_items sri
        JOIN erp_supplier_receptions reception ON reception.id = sri.supplier_reception_id
        LEFT JOIN erp_supplier_return_items sri2 ON sri2.supplier_reception_item_id = sri.id
        LEFT JOIN erp_supplier_returns sr ON sr.id = sri2.supplier_return_id AND sr.user_id = reception.user_id
        WHERE sri.id = ? AND sri.supplier_reception_id = ? AND reception.user_id = ?
        GROUP BY sri.id, sri.accepted_qty, sri.catalog_id
        FOR UPDATE
    ");

    foreach ($lines as $line) {
        $receptionItemId = (int)($line['supplier_reception_item_id'] ?? 0);
        $productId = (int)($line['product_id'] ?? 0);
        $quantity = round((float)($line['quantity'] ?? 0), 3);
        $unitCost = round((float)($line['unit_cost'] ?? 0), 6);
        if ($receptionItemId <= 0 || $productId <= 0 || $quantity <= 0 || $unitCost < 0) {
            throw new Exception('Invalid supplier return line');
        }
        if (isset($seenItems[$receptionItemId])) {
            throw new Exception('A reception line can appear only once in a supplier return');
        }
        $seenItems[$receptionItemId] = true;

        requireTenantProduct($conn, $userId, $productId);
        $lineCheck->bind_param('iii', $receptionItemId, $receptionId, $userId);
        $lineCheck->execute();
        $receivedLine = $lineCheck->get_result()->fetch_assoc();
        if (!$receivedLine || (int)$receivedLine['catalog_id'] !== $productId) {
            throw new Exception('Supplier reception item not found or does not match this reception');
        }
        $available = round((float)$receivedLine['received_quantity'] - (float)$receivedLine['returned_quantity'], 3);
        if ($quantity > $available + 0.0005) {
            throw new Exception('Supplier return quantity exceeds the remaining received quantity');
        }

        $normalizedLines[] = [
            'reception_item_id' => $receptionItemId,
            'product_id' => $productId,
            'quantity' => $quantity,
            'unit_cost' => $unitCost,
            'lot_number' => trim((string)($line['lot_number'] ?? '')) ?: null,
            'serial_number' => trim((string)($line['serial_number'] ?? '')) ?: null,
        ];
    }
    $lineCheck->close();

    $stmt = $conn->prepare("INSERT INTO erp_supplier_returns(user_id,supplier_id,supplier_reception_id,return_date,status,reason,stock_applied,confirmed_at,created_by) VALUES(?,?,?,?,'CONFIRMED',?,1,NOW(),?)");
    $stmt->bind_param('iiissi', $userId, $supplierId, $receptionId, $date, $reason, $userId);
    $stmt->execute();
    $returnId = (int)$stmt->insert_id;
    $stmt->close();

    $insert = $conn->prepare('INSERT INTO erp_supplier_return_items(supplier_return_id,supplier_reception_item_id,product_id,quantity,unit_cost,lot_number,serial_number) VALUES(?,?,?,?,?,?,?)');
    foreach ($normalizedLines as $line) {
        $receptionItemId = $line['reception_item_id'];
        $productId = $line['product_id'];
        $quantity = $line['quantity'];
        $unitCost = $line['unit_cost'];
        $lot = $line['lot_number'];
        $serial = $line['serial_number'];
        $insert->bind_param('iiiddss', $returnId, $receptionItemId, $productId, $quantity, $unitCost, $lot, $serial);
        $insert->execute();

        recordProductStockMovement(
            $conn,
            $productId,
            $userId,
            -$quantity,
            'ADJUSTMENT',
            'SUPPLIER_RETURN',
            $returnId,
            $reason,
            null,
            'SUPPLIER_RETURN',
            $lot,
            $serial,
            'SUPPLIER_RETURN:' . $returnId . ':ITEM:' . $receptionItemId
        );
        syncProductStockQuantity($conn, $productId, $userId);
    }
    $insert->close();

    auditLog($conn, $userId, $userId, 'SUPPLIER_RETURN.CONFIRMED', 'SUPPLIER_RETURN', $returnId,
        null, ['supplier_id' => $supplierId, 'supplier_reception_id' => $receptionId,
        'return_date' => $date, 'reason' => $reason, 'line_count' => count($normalizedLines),
        'stock_applied' => true]);
    completeIdempotencyKey($conn, $userId, 'supplier.return.confirm', $key, $returnId);
    $conn->commit();
    jsonResponse(['success' => true, 'supplier_return_id' => $returnId, 'replayed' => false, 'message' => 'Supplier return confirmed and stock removed once']);
} catch (Throwable $e) {
    if (isset($conn)) {
        try { $conn->rollback(); } catch (Throwable $ignored) {}
    }
    jsonResponse(['success' => false, 'message' => $e->getMessage()], 400);
}
