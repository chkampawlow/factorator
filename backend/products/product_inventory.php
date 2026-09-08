<?php

require_once __DIR__ . '/../config/db.php';
require_once __DIR__ . '/../config/audit.php';

function ensureProductInventorySchema(mysqli $conn): void
{
    static $checked = false;
    if ($checked) return;
    // Read-only guard: migrations own schema and bootstrap data, never API requests.
    $conn->query("SELECT id,user_id,category,item_type,stock_quantity,reorder_point,last_purchase_price,average_cost,selling_price_required FROM products LIMIT 0");
    $conn->query("SELECT id,user_id,product_id,movement_type,unit_cost,cogs_value,idempotency_key FROM product_stock_movements LIMIT 0");
    $conn->query("SELECT product_id FROM erp_invoice_items LIMIT 0");
    $checked = true;
}

function recordProductStockMovement(
    mysqli $conn,
    int $productId,
    int $userId,
    float $quantity,
    string $movementType,
    ?string $referenceType = null,
    ?int $referenceId = null,
    ?string $note = null,
    ?float $unitCost = null,
    ?string $reasonCode = null,
    ?string $lotNumber = null,
    ?string $serialNumber = null,
    ?string $idempotencyKey = null
): void {
    if (abs($quantity) < 0.0001) {
        return;
    }

    if ($idempotencyKey !== null && trim($idempotencyKey) !== '') {
        $check = $conn->prepare("SELECT id FROM product_stock_movements WHERE user_id = ? AND idempotency_key = ? LIMIT 1");
        $check->bind_param('is', $userId, $idempotencyKey);
        $check->execute();
        $exists = (bool)$check->get_result()->fetch_assoc();
        $check->close();
        if ($exists) return;
    }

    $lock = $conn->prepare("SELECT average_cost FROM products WHERE id = ? AND user_id = ? LIMIT 1 FOR UPDATE");
    $lock->bind_param('ii', $productId, $userId);
    $lock->execute();
    $product = $lock->get_result()->fetch_assoc();
    $lock->close();
    if (!$product) throw new Exception('Product not found for stock movement');

    $currentQty = getProductStockQuantity($conn, $productId, $userId);
    $currentAverage = max(0, (float)($product['average_cost'] ?? 0));
    $effectiveCost = $unitCost !== null && $unitCost >= 0 ? round($unitCost, 6) : $currentAverage;
    if ($quantity > 0 && $effectiveCost > 0 && ($movementType === 'SUPPLIER_IN' || $movementType === 'INITIAL')) {
        $newQty = $currentQty + $quantity;
        $newAverage = $newQty > 0 ? (($currentQty * $currentAverage) + ($quantity * $effectiveCost)) / $newQty : 0;
        $avg = $conn->prepare("UPDATE products SET average_cost = ?, last_purchase_price = ? WHERE id = ? AND user_id = ?");
        $avg->bind_param('ddii', $newAverage, $effectiveCost, $productId, $userId);
        $avg->execute();
        $avg->close();
    }
    $movementValue = round($quantity * $effectiveCost, 6);
    $cogsValue = $quantity < 0 ? round(abs($quantity) * $currentAverage, 6) : 0.0;

    $stmt = $conn->prepare("
        INSERT INTO product_stock_movements (
            user_id,
            product_id,
            movement_type,
            quantity, unit_cost, movement_value, cogs_value,
            reference_type,
            reference_id,
            reason_code, lot_number, serial_number, idempotency_key,
            note
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ");

    if (!$stmt) {
        throw new Exception('Failed to prepare stock movement insert: ' . $conn->error);
    }

    $stmt->bind_param(
        'iisddddsisssss',
        $userId,
        $productId,
        $movementType,
        $quantity,
        $effectiveCost,
        $movementValue,
        $cogsValue,
        $referenceType,
        $referenceId,
        $reasonCode,
        $lotNumber,
        $serialNumber,
        $idempotencyKey,
        $note
    );
    $stmt->execute();

    $movementId = (int) $stmt->insert_id;

    if ($stmt->error) {
        throw new Exception('Failed to save stock movement: ' . $stmt->error);
    }

    $stmt->close();

    auditLog(
        $conn,
        $userId,
        $userId,
        'STOCK.MOVEMENT_RECORDED',
        'PRODUCT_STOCK_MOVEMENT',
        $movementId,
        ['product_id' => $productId, 'ledger_quantity' => $currentQty],
        [
            'product_id' => $productId,
            'ledger_quantity' => round($currentQty + $quantity, 3),
            'quantity' => round($quantity, 3),
            'movement_type' => $movementType,
            'reference_type' => $referenceType,
            'reference_id' => $referenceId,
            'reason_code' => $reasonCode,
        ]
    );
}

function getProductStockQuantity(mysqli $conn, int $productId, int $userId): float
{
    $stmt = $conn->prepare("
        SELECT ROUND(COALESCE(SUM(quantity), 0), 3) AS stock_quantity
        FROM product_stock_movements
        WHERE product_id = ? AND user_id = ?
    ");

    if (!$stmt) {
        throw new Exception('Failed to prepare stock total query: ' . $conn->error);
    }

    $stmt->bind_param('ii', $productId, $userId);
    $stmt->execute();
    $row = $stmt->get_result()->fetch_assoc();
    $stmt->close();

    return (float) ($row['stock_quantity'] ?? 0);
}

function syncProductStockQuantity(mysqli $conn, int $productId, int $userId): float
{
    $quantity = getProductStockQuantity($conn, $productId, $userId);

    $stmt = $conn->prepare("
        UPDATE products
        SET stock_quantity = ?
        WHERE id = ? AND user_id = ?
    ");

    if (!$stmt) {
        throw new Exception('Failed to prepare stock cache update: ' . $conn->error);
    }

    $stmt->bind_param('dii', $quantity, $productId, $userId);
    $stmt->execute();
    $stmt->close();

    return $quantity;
}

function adjustProductStockTo(
    mysqli $conn,
    int $productId,
    int $userId,
    float $targetQuantity,
    string $movementType = 'ADJUSTMENT',
    ?string $note = null
): float {
    $currentQuantity = getProductStockQuantity($conn, $productId, $userId);
    $delta = round($targetQuantity - $currentQuantity, 3);

    if (abs($delta) >= 0.0001) {
        recordProductStockMovement(
            $conn,
            $productId,
            $userId,
            $delta,
            $movementType,
            'PRODUCT',
            $productId,
            $note ?? 'Stock adjustment'
        );
    }

    return syncProductStockQuantity($conn, $productId, $userId);
}

function resolveProductIdForUser(
    mysqli $conn,
    int $userId,
    int $productId = 0,
    ?string $productCode = null,
    ?string $productName = null
): int {
    if ($productId > 0) {
        $stmt = $conn->prepare("
            SELECT id
            FROM products
            WHERE id = ? AND user_id = ?
            LIMIT 1
        ");
        if (!$stmt) {
            throw new Exception('Failed to prepare product id lookup: ' . $conn->error);
        }
        $stmt->bind_param('ii', $productId, $userId);
        $stmt->execute();
        $row = $stmt->get_result()->fetch_assoc();
        $stmt->close();
        if ($row) {
            return (int)$row['id'];
        }
    }

    $productCode = trim((string)$productCode);
    if ($productCode !== '') {
        $stmt = $conn->prepare("
            SELECT id
            FROM products
            WHERE user_id = ? AND code = ?
            ORDER BY id DESC
            LIMIT 1
        ");
        if (!$stmt) {
            throw new Exception('Failed to prepare product code lookup: ' . $conn->error);
        }
        $stmt->bind_param('is', $userId, $productCode);
        $stmt->execute();
        $row = $stmt->get_result()->fetch_assoc();
        $stmt->close();
        if ($row) {
            return (int)$row['id'];
        }
    }

    $productName = trim((string)$productName);
    if ($productName !== '') {
        $stmt = $conn->prepare("
            SELECT id
            FROM products
            WHERE user_id = ? AND name = ?
            ORDER BY id DESC
            LIMIT 1
        ");
        if (!$stmt) {
            throw new Exception('Failed to prepare product name lookup: ' . $conn->error);
        }
        $stmt->bind_param('is', $userId, $productName);
        $stmt->execute();
        $row = $stmt->get_result()->fetch_assoc();
        $stmt->close();
        if ($row) {
            return (int)$row['id'];
        }
    }

    return 0;
}

function hasStockMovementReference(mysqli $conn, int $userId, string $referenceType, int $referenceId): bool
{
    $stmt = $conn->prepare("
        SELECT id
        FROM product_stock_movements
        WHERE user_id = ? AND reference_type = ? AND reference_id = ?
        LIMIT 1
    ");
    if (!$stmt) {
        throw new Exception('Failed to prepare stock reference lookup: ' . $conn->error);
    }
    $stmt->bind_param('isi', $userId, $referenceType, $referenceId);
    $stmt->execute();
    $row = $stmt->get_result()->fetch_assoc();
    $stmt->close();

    return (bool)$row;
}

function productUsesStock(mysqli $conn, int $productId, int $userId): bool
{
    $stmt = $conn->prepare("
        SELECT item_type
        FROM products
        WHERE id = ? AND user_id = ?
        LIMIT 1
    ");
    if (!$stmt) {
        throw new Exception('Failed to prepare product type lookup: ' . $conn->error);
    }
    $stmt->bind_param('ii', $productId, $userId);
    $stmt->execute();
    $row = $stmt->get_result()->fetch_assoc();
    $stmt->close();

    return strtoupper((string)($row['item_type'] ?? 'PRODUCT')) === 'PRODUCT';
}
