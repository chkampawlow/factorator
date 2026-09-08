<?php

header('Content-Type: application/json');

require_once __DIR__ . '/../config/response.php';
require_once __DIR__ . '/../config/db.php';
require_once __DIR__ . '/../config/validator.php';
require_once __DIR__ . '/../config/idempotency.php';
require_once __DIR__ . '/../auth/auth_required.php';
require_once __DIR__ . '/../auth/role_helper.php';

require_once __DIR__ . '/product_inventory.php';



try {
    if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
        jsonResponse([
            'success' => false,
            'message' => 'Method not allowed. Use POST.'
        ], 405);
        exit;
    }

    $authUser = requireAuth();
    $userId = (int)$authUser->id;
    $permissionConn = db();
    requirePermission($permissionConn, $userId, 'stock.adjust');
    $data = requireJsonBody();

    $productId = getRequiredInt($data, 'product_id', 'Product ID');
    $action = strtoupper(getRequiredString($data, 'action', 'Stock action'));
    validateEnum($action, ['ADJUSTMENT', 'RETURN'], 'Stock action');

    $quantity = isset($data['quantity']) && $data['quantity'] !== ''
        ? validatePositiveNumber($data['quantity'], 'Quantity')
        : 0.0;
    $note = getOptionalString($data, 'note');
    $mode = $action === 'ADJUSTMENT' ? strtoupper(trim((string)($data['mode'] ?? 'SET'))) : '';
    $key = requiredIdempotencyKey($data);

    $conn = db();
    ensureProductInventorySchema($conn);
    $conn->begin_transaction();

    $hash = idempotencyRequestHash(['product_id' => $productId, 'action' => $action, 'mode' => $mode, 'quantity' => round((float)$quantity, 3), 'note' => $note]);
    $replayedId = claimIdempotencyKey($conn, $userId, 'stock.manual.movement', $key, $hash);
    if ($replayedId !== null) {
        $newQuantity = getProductStockQuantity($conn, $productId, $userId);
        $conn->commit();
        jsonResponse(['success' => true, 'stock_quantity' => $newQuantity, 'replayed' => true]);
    }

    if (!productUsesStock($conn, $productId, $userId)) {
        throw new Exception('This catalog item does not use stock movements.');
    }

    $productStmt = $conn->prepare("SELECT id, name FROM products WHERE id = ? AND user_id = ? LIMIT 1");
    if (!$productStmt) {
        throw new Exception('Failed to prepare product lookup: ' . $conn->error);
    }
    $productStmt->bind_param('ii', $productId, $userId);
    $productStmt->execute();
    $product = $productStmt->get_result()->fetch_assoc();
    $productStmt->close();

    if (!$product) {
        throw new Exception('Product not found or unauthorized');
    }

    if ($action === 'RETURN') {
        if ($quantity <= 0) {
            throw new Exception('Return quantity must be greater than zero');
        }
        recordProductStockMovement(
            $conn,
            $productId,
            $userId,
            round(abs($quantity), 3),
            'RETURN_IN',
            'PRODUCT',
            $productId,
            trim($note) !== '' ? $note : 'Manual product return'
        );
    } else {
        validateEnum($mode, ['SET', 'ADD', 'REMOVE'], 'Adjustment mode');

        if ($mode === 'SET') {
            adjustProductStockTo(
                $conn,
                $productId,
                $userId,
                round((float)$quantity, 3),
                'ADJUSTMENT',
                trim($note) !== '' ? $note : 'Manual stock adjustment'
            );
        } else {
            if ($quantity <= 0) {
                throw new Exception('Adjustment quantity must be greater than zero');
            }
            $signedQuantity = $mode === 'REMOVE' ? -abs($quantity) : abs($quantity);
            $currentStock = getProductStockQuantity($conn, $productId, $userId);
            if ($signedQuantity < 0 && ($currentStock + 0.0001) < abs($signedQuantity)) {
                throw new Exception('Not enough stock for this manual adjustment');
            }
            recordProductStockMovement(
                $conn,
                $productId,
                $userId,
                round($signedQuantity, 3),
                'ADJUSTMENT',
                'PRODUCT',
                $productId,
                trim($note) !== '' ? $note : ($mode === 'ADD' ? 'Manual stock increase' : 'Manual stock decrease')
            );
            syncProductStockQuantity($conn, $productId, $userId);
        }
    }

    $newQuantity = getProductStockQuantity($conn, $productId, $userId);
    completeIdempotencyKey($conn, $userId, 'stock.manual.movement', $key, $productId);
    $conn->commit();

    jsonResponse([
        'success' => true,
        'message' => 'Stock movement recorded successfully',
        'stock_quantity' => $newQuantity,
        'replayed' => false,
    ]);
} catch (Throwable $e) {
    if (isset($conn)) {
        try { $conn->rollback(); } catch (Throwable $ignored) {}
    }

    jsonResponse([
        'success' => false,
        'message' => $e->getMessage()
    ], 400);
}
