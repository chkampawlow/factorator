<?php

declare(strict_types=1);

require_once __DIR__ . '/../config/audit.php';
require_once __DIR__ . '/../expense_notes/expense_service.php';
require_once __DIR__ . '/../products/product_inventory.php';
require_once __DIR__ . '/../taxes/tax_profile_service.php';
require_once __DIR__ . '/reception_service.php';

function supplierReceptionConfirmationKey(array $line, bool $orderLine = false): string
{
    $catalogId = (int)($line[$orderLine ? 'catalog_id' : 'catalogId'] ?? 0);
    if ($catalogId > 0) return 'catalog:' . $catalogId;

    $code = mb_strtolower(trim((string)($line[$orderLine ? 'product_code' : 'code'] ?? '')));
    $type = normalizeSupplierReceptionItemType((string)($line[$orderLine ? 'item_type' : 'itemType'] ?? 'PRODUCT'));
    if ($code !== '') return 'code:' . $code . '|type:' . $type;

    $name = mb_strtolower(trim((string)($line[$orderLine ? 'description' : 'name'] ?? '')));
    $unit = mb_strtolower(trim((string)($line['unit'] ?? 'piece')));
    $price = number_format((float)($line['price'] ?? 0), 3, '.', '');
    $vat = number_format((float)($line[$orderLine ? 'tva_rate' : 'tvaRate'] ?? 0), 3, '.', '');
    return "manual:$name|type:$type|unit:$unit|price:$price|vat:$vat";
}

function supplierReceptionConfirmationLineMatchesOrderRow(array $line, array $orderRow): bool
{
    $lineType = normalizeSupplierReceptionItemType((string)($line['itemType'] ?? 'PRODUCT'));
    $orderType = normalizeSupplierReceptionItemType((string)($orderRow['item_type'] ?? 'PRODUCT'));
    if ($lineType !== $orderType) return false;

    $lineCatalogId = (int)($line['catalogId'] ?? 0);
    $orderCatalogId = (int)($orderRow['catalog_id'] ?? 0);
    if ($lineCatalogId > 0 && $orderCatalogId > 0) return $lineCatalogId === $orderCatalogId;

    $lineCode = mb_strtolower(trim((string)($line['code'] ?? '')));
    $orderCode = mb_strtolower(trim((string)($orderRow['product_code'] ?? '')));
    if ($lineCode !== '' && $orderCode !== '') return $lineCode === $orderCode;

    $lineName = mb_strtolower(trim((string)($line['name'] ?? '')));
    $orderName = mb_strtolower(trim((string)($orderRow['description'] ?? '')));
    if ($lineName === '' || $lineName !== $orderName) return false;

    $lineUnit = mb_strtolower(trim((string)($line['unit'] ?? 'piece')));
    $orderUnit = mb_strtolower(trim((string)($orderRow['unit'] ?? 'piece')));
    return $lineUnit === $orderUnit
        && abs((float)($line['price'] ?? 0) - (float)($orderRow['price'] ?? 0)) < 0.0005
        && abs((float)($line['tvaRate'] ?? 0) - (float)($orderRow['tva_rate'] ?? 0)) < 0.0005;
}

function supplierReceptionConfirmationResolveOrderKey(array $line, array $orderedByKey, array $orderRowsByKey): string
{
    $directKey = supplierReceptionConfirmationKey($line);
    if (array_key_exists($directKey, $orderedByKey)) return $directKey;

    foreach ($orderRowsByKey as $orderKey => $orderRows) {
        foreach ($orderRows as $orderRow) {
            if (supplierReceptionConfirmationLineMatchesOrderRow($line, $orderRow)) return $orderKey;
        }
    }

    return $directKey;
}

function assertSupplierReceptionConfirmationQuantities(
    mysqli $conn,
    int $tenantId,
    int $supplierOrderId,
    int $receptionId,
    array $lines,
    bool $allowOverdelivery
): void {
    $orderItems = $conn->prepare('SELECT catalog_id,product_code,description,item_type,qty,price,tva_rate,unit FROM erp_supplier_order_items WHERE supplier_order_id=? ORDER BY id FOR UPDATE');
    $orderItems->bind_param('i', $supplierOrderId);
    $orderItems->execute();
    $orderedByKey = [];
    $orderRowsByKey = [];
    $totalOrderedQty = 0.0;
    foreach ($orderItems->get_result()->fetch_all(MYSQLI_ASSOC) as $row) {
        $key = supplierReceptionConfirmationKey($row, true);
        $orderedByKey[$key] = round((float)($orderedByKey[$key] ?? 0) + (float)$row['qty'], 3);
        $orderRowsByKey[$key][] = $row;
        $totalOrderedQty = round($totalOrderedQty + (float)$row['qty'], 3);
    }
    $orderItems->close();
    if (!$orderedByKey) throw new RuntimeException('Source supplier order has no valid lines to receive');

    $appliedItems = $conn->prepare("SELECT sri.catalog_id,sri.code,sri.name,sri.item_type,sri.qty,sri.accepted_qty,sri.price,sri.tva_rate,sri.unit
        FROM erp_supplier_reception_items sri
        JOIN erp_supplier_receptions sr ON sr.id=sri.supplier_reception_id
        WHERE sr.user_id=? AND sr.supplier_order_id=? AND sr.id<>? AND sr.stock_applied=1
        FOR UPDATE");
    $appliedItems->bind_param('iii', $tenantId, $supplierOrderId, $receptionId);
    $appliedItems->execute();
    $receivedByKey = [];
    $totalAlreadyReceivedQty = 0.0;
    foreach ($appliedItems->get_result()->fetch_all(MYSQLI_ASSOC) as $row) {
        $existingLine = [
            'catalogId' => $row['catalog_id'], 'code' => $row['code'], 'name' => $row['name'],
            'itemType' => $row['item_type'], 'qty' => $row['qty'], 'acceptedQty' => $row['accepted_qty'], 'price' => $row['price'],
            'tvaRate' => $row['tva_rate'], 'unit' => $row['unit'],
        ];
        $key = supplierReceptionConfirmationResolveOrderKey($existingLine, $orderedByKey, $orderRowsByKey);
        $receivedByKey[$key] = round((float)($receivedByKey[$key] ?? 0) + (float)($row['accepted_qty'] ?? $row['qty']), 3);
        $totalAlreadyReceivedQty = round($totalAlreadyReceivedQty + (float)($row['accepted_qty'] ?? $row['qty']), 3);
    }
    $appliedItems->close();

    $currentByKey = [];
    $totalCurrentQty = 0.0;
    foreach ($lines as $line) {
        $key = supplierReceptionConfirmationResolveOrderKey($line, $orderedByKey, $orderRowsByKey);
        if (!array_key_exists($key, $orderedByKey)) {
            throw new RuntimeException('A reception line does not exist on the source supplier order');
        }
        $currentByKey[$key] = round((float)($currentByKey[$key] ?? 0) + (float)($line['acceptedQty'] ?? $line['qty']), 3);
        $totalCurrentQty = round($totalCurrentQty + (float)($line['acceptedQty'] ?? $line['qty']), 3);
    }
    if (!$allowOverdelivery && $totalAlreadyReceivedQty + $totalCurrentQty > $totalOrderedQty + 0.0005) {
        throw new RuntimeException(
            'Reception confirmation would exceed the remaining purchase-order quantity '
            . '(ordered: ' . number_format($totalOrderedQty, 3, '.', '')
            . ', already received: ' . number_format($totalAlreadyReceivedQty, 3, '.', '')
            . ', this reception: ' . number_format($totalCurrentQty, 3, '.', '') . ')'
        );
    }
    foreach ($currentByKey as $key => $quantity) {
        $ordered = (float)$orderedByKey[$key];
        $alreadyReceived = (float)($receivedByKey[$key] ?? 0);
        if (!$allowOverdelivery && $alreadyReceived + $quantity > $ordered + 0.0005) {
            throw new RuntimeException('Reception confirmation would exceed an ordered quantity');
        }
    }
}

function createProductFromConfirmedReceptionLine(mysqli $conn, int $tenantId, array $line): int
{
    $name = trim((string)($line['name'] ?? ''));
    $sellingPrice = round((float)($line['sellingPrice'] ?? 0), 3);
    if ($name === '') throw new RuntimeException('A supplier product line is missing its name');
    $sellingPriceRequired = $sellingPrice <= 0 ? 1 : 0;

    $code = trim((string)($line['code'] ?? ''));
    $purchasePrice = round((float)($line['price'] ?? 0), 3);
    $vatRate = round((float)($line['tvaRate'] ?? 0), 3);
    $unit = trim((string)($line['unit'] ?? 'piece')) ?: 'piece';
    $stmt = $conn->prepare("INSERT INTO products(user_id,code,name,item_type,price,selling_price_required,last_purchase_price,tva_rate,unit,stock_quantity) VALUES(?,?,?,'PRODUCT',?,?,?,?,?,0)");
    $stmt->bind_param('issdidds', $tenantId, $code, $name, $sellingPrice, $sellingPriceRequired, $purchasePrice, $vatRate, $unit);
    $stmt->execute();
    $id = (int)$stmt->insert_id;
    $stmt->close();
    $barcode = 'EF-P-' . str_pad((string)$id, 8, '0', STR_PAD_LEFT);
    $barcodeStmt = $conn->prepare('UPDATE products SET barcode=? WHERE id=? AND user_id=? AND (barcode IS NULL OR barcode=\'\')');
    $barcodeStmt->bind_param('sii', $barcode, $id, $tenantId);
    $barcodeStmt->execute();
    $barcodeStmt->close();
    return $id;
}

function updateProductFromConfirmedReceptionLine(mysqli $conn, int $tenantId, int $productId, array $line): void
{
    $purchasePrice = round((float)($line['price'] ?? 0), 3);
    $sellingPrice = round((float)($line['sellingPrice'] ?? 0), 3);
    $stmt = $conn->prepare('UPDATE products SET last_purchase_price=?,price=CASE WHEN ?>0 THEN ? ELSE price END,selling_price_required=CASE WHEN ?>0 THEN 0 ELSE selling_price_required END WHERE id=? AND user_id=? LIMIT 1');
    $stmt->bind_param('ddddii', $purchasePrice, $sellingPrice, $sellingPrice, $sellingPrice, $productId, $tenantId);
    $stmt->execute();
    $stmt->close();
}

function createReceptionExpense(mysqli $conn, int $tenantId, array $reception, array $lines): int
{
    ensureExpenseNotesSchema($conn);
    $existing = $conn->prepare("SELECT id FROM expense_notes WHERE user_id=? AND source_document_type='SUPPLIER_RECEPTION' AND source_document_id=? LIMIT 1 FOR UPDATE");
    $receptionId = (int)$reception['id'];
    $existing->bind_param('ii', $tenantId, $receptionId);
    $existing->execute();
    $existingId = (int)($existing->get_result()->fetch_assoc()['id'] ?? 0);
    $existing->close();
    if ($existingId > 0) return $existingId;

    $hasProduct = false;
    $hasService = false;
    foreach ($lines as $line) {
        if (normalizeSupplierReceptionItemType((string)$line['itemType']) === 'SERVICE') $hasService = true;
        else $hasProduct = true;
    }
    $category = $hasProduct && !$hasService ? 'Equipment' : ($hasService && !$hasProduct ? 'Professional services' : 'Other');
    $invoiceNumber = trim((string)($reception['invoice_number'] ?? ''));
    $supplierName = trim((string)($reception['supplier_name'] ?? ''));
    $titleReference = $invoiceNumber !== '' ? $invoiceNumber : 'Reception #' . $receptionId;
    $title = 'Supplier invoice ' . $titleReference . ($supplierName !== '' ? ' · ' . $supplierName : '');
    $description = implode("\n", array_filter([
        $supplierName !== '' ? 'Supplier: ' . $supplierName : '',
        $invoiceNumber !== '' ? 'Invoice number: ' . $invoiceNumber : '',
        trim((string)($reception['order_number'] ?? '')) !== '' ? 'Source order: ' . $reception['order_number'] : '',
        trim((string)($reception['notes'] ?? '')),
    ]));
    $amount = round((float)($reception['total_ttc'] ?? 0), 3);
    $date = (string)$reception['invoice_date'];
    $supplierId = (int)$reception['supplier_id'];
    $sourceNumber = 'RECEPTION-' . $receptionId;
    $status = 'PENDING';
    $stmt = $conn->prepare("INSERT INTO expense_notes(user_id,supplier_id,title,category,amount,expense_date,description,receipt_path,source_document_type,source_document_id,source_document_number,status) VALUES(?,?,?,?,?,?,?,?,'SUPPLIER_RECEPTION',?,?,?)");
    $stmt->bind_param('iissdsssiss', $tenantId, $supplierId, $title, $category, $amount, $date, $description, $invoiceNumber, $receptionId, $sourceNumber, $status);
    $stmt->execute();
    $expenseId = (int)$stmt->insert_id;
    $stmt->close();
    return $expenseId;
}

function confirmSupplierReception(
    mysqli $conn,
    int $tenantId,
    int $actorId,
    int $receptionId,
    bool $createExpense,
    bool $manageTransaction = true
): array
{
    $debugStage = 'schema_validation';
    $supplierOrderId = 0;
    ensureProductInventorySchema($conn);
    ensureSupplierReceptionsSchema($conn);
    if ($manageTransaction) $conn->begin_transaction();
    try {
        $debugStage = 'reception_lock';
        $stmt = $conn->prepare("SELECT sr.*,s.name supplier_name,so.order_number,so.status order_status
            FROM erp_supplier_receptions sr
            JOIN suppliers s ON s.id=sr.supplier_id AND s.user_id=sr.user_id
            LEFT JOIN erp_supplier_orders so ON so.id=sr.supplier_order_id AND so.user_id=sr.user_id
            WHERE sr.id=? AND sr.user_id=? LIMIT 1 FOR UPDATE");
        $stmt->bind_param('ii', $receptionId, $tenantId);
        $stmt->execute();
        $reception = $stmt->get_result()->fetch_assoc();
        $stmt->close();
        if (!$reception) throw new RuntimeException('Supplier reception not found');

        if ((int)$reception['stock_applied'] === 1) {
            if ($manageTransaction) $conn->commit();
            structuredLog('INFO', 'SUPPLIER_RECEPTION.CONFIRM_REPLAYED', [
                'supplier_reception_id' => $receptionId,
                'confirmation_hash' => (string)($reception['confirmation_hash'] ?? ''),
            ]);
            return [
                'id' => $receptionId,
                'already_confirmed' => true,
                'created_expense_id' => (int)($reception['created_expense_id'] ?? 0),
                'confirmation_hash' => (string)($reception['confirmation_hash'] ?? ''),
                'applied_lines' => 0,
                'created_products' => 0,
                'pricing_required_products' => 0,
            ];
        }
        if (!in_array(strtoupper((string)$reception['status']), ['DRAFT', 'REVIEWED'], true)) {
            throw new RuntimeException('Supplier reception cannot be confirmed in its current state');
        }
        if (hasStockMovementReference($conn, $tenantId, 'SUPPLIER_BILL', $receptionId)) {
            throw new RuntimeException('Reception stock movements exist without confirmation metadata');
        }

        $debugStage = 'line_validation';
        $lineStmt = $conn->prepare('SELECT * FROM erp_supplier_reception_items WHERE supplier_reception_id=? ORDER BY id FOR UPDATE');
        $lineStmt->bind_param('i', $receptionId);
        $lineStmt->execute();
        $storedLines = $lineStmt->get_result()->fetch_all(MYSQLI_ASSOC);
        $lineStmt->close();
        $lines = array_map('supplierReceptionLineRow', $storedLines);
        if (!$lines) throw new RuntimeException('Supplier reception has no persisted lines');

        $supplierOrderId = (int)($reception['supplier_order_id'] ?? 0);
        $debugStage = 'source_order_validation';
        $exceptionType = normalizeSupplierReceptionExceptionType((string)($reception['exception_type'] ?? 'NONE'));
        $exceptionReason = trim((string)($reception['exception_reason'] ?? ''));
        if ($exceptionType !== 'NONE' && $exceptionReason === '') {
            throw new RuntimeException('An exception reason is required before confirmation');
        }
        if ($supplierOrderId <= 0 && $exceptionType !== 'NO_ORDER') {
            throw new RuntimeException('A reception without a purchase order requires a documented NO_ORDER exception');
        }
        if ($supplierOrderId > 0 && $exceptionType === 'NO_ORDER') {
            throw new RuntimeException('NO_ORDER cannot be used with a linked purchase order');
        }
        if ($supplierOrderId > 0) {
            if (!in_array((string)($reception['order_status'] ?? ''), ['SENT', 'PARTIALLY_RECEIVED'], true)) {
                throw new RuntimeException('The source supplier order is not open for reception');
            }
            assertSupplierReceptionConfirmationQuantities($conn, $tenantId, $supplierOrderId, $receptionId, $lines, $exceptionType === 'OVERDELIVERY');
        }

        $debugStage = 'stock_application';
        $appliedLines = 0;
        $createdProducts = 0;
        $pricingRequiredProducts = 0;
        $confirmedLines = [];
        foreach ($lines as $index => $line) {
            if (normalizeSupplierReceptionItemType((string)$line['itemType']) === 'SERVICE') {
                $confirmedLines[] = $line;
                continue;
            }
            $quantity = round((float)($line['acceptedQty'] ?? $line['stockImpact'] ?? $line['qty']), 3);
            if ($quantity <= 0) {
                $confirmedLines[] = $line;
                continue;
            }
            $productId = (int)($line['catalogId'] ?? 0);
            if ($productId > 0) {
                $productId = resolveProductIdForUser($conn, $tenantId, $productId, null, null);
                updateProductFromConfirmedReceptionLine($conn, $tenantId, $productId, $line);
            } else {
                $productId = createProductFromConfirmedReceptionLine($conn, $tenantId, $line);
                $createdProducts++;
                if (round((float)($line['sellingPrice'] ?? 0), 3) <= 0) $pricingRequiredProducts++;
                $itemId = (int)$storedLines[$index]['id'];
                $catalogStmt = $conn->prepare('UPDATE erp_supplier_reception_items SET catalog_id=? WHERE id=? AND supplier_reception_id=?');
                $catalogStmt->bind_param('iii', $productId, $itemId, $receptionId);
                $catalogStmt->execute();
                $catalogStmt->close();
                if ($supplierOrderId > 0) {
                    $orderCatalogStmt = $conn->prepare("UPDATE erp_supplier_order_items
                        SET catalog_id=?
                        WHERE supplier_order_id=? AND COALESCE(catalog_id,0)=0
                          AND ((?<>'' AND product_code=?) OR (?='' AND description=?))");
                    $lineCode = trim((string)($line['code'] ?? ''));
                    $lineName = trim((string)($line['name'] ?? ''));
                    $orderCatalogStmt->bind_param('iissss', $productId, $supplierOrderId, $lineCode, $lineCode, $lineCode, $lineName);
                    $orderCatalogStmt->execute();
                    $orderCatalogStmt->close();
                }
                $line['catalogId'] = $productId;
            }
            ensureProductTaxProfileForVatRate(
                $conn,
                $tenantId,
                $productId,
                (float)($line['tvaRate'] ?? 0),
                (string)($reception['received_date'] ?? date('Y-m-d')),
            );
            if ($quantity > 0 && productUsesStock($conn, $productId, $tenantId)) {
                recordProductStockMovement($conn, $productId, $tenantId, $quantity, 'SUPPLIER_IN', 'SUPPLIER_BILL', $receptionId,
                    'Stock-in from goods reception on ' . $reception['received_date'], round((float)$line['price'], 6),
                    'PURCHASE_RECEIPT', null, null, 'SUPPLIER_RECEPTION:' . $receptionId . ':PRODUCT:' . $productId);
                syncProductStockQuantity($conn, $productId, $tenantId);
                $appliedLines++;
            }
            $confirmedLines[] = $line;
        }

        $debugStage = 'expense_creation';
        $expenseId = (int)($reception['created_expense_id'] ?? 0);
        if ($createExpense && $expenseId <= 0 && (float)$reception['total_ttc'] > 0) {
            $expenseId = createReceptionExpense($conn, $tenantId, $reception, $confirmedLines);
        }

        $debugStage = 'confirmation_snapshot';
        $snapshot = [
            'reception_id' => $receptionId, 'supplier_id' => (int)$reception['supplier_id'],
            'supplier_order_id' => $supplierOrderId, 'invoice_number' => (string)$reception['invoice_number'],
            'invoice_date' => (string)$reception['invoice_date'], 'received_date' => (string)$reception['received_date'],
            'supplier_delivery_note_number' => (string)($reception['supplier_delivery_note_number'] ?? ''),
            'supplier_delivery_note_date' => (string)($reception['supplier_delivery_note_date'] ?? ''),
            'exception_type' => $exceptionType, 'exception_reason' => $exceptionReason,
            'discrepancy_attachment_name' => (string)($reception['discrepancy_attachment_name'] ?? ''),
            'total_ht' => number_format((float)$reception['total_ht'], 3, '.', ''),
            'total_vat' => number_format((float)$reception['total_vat'], 3, '.', ''),
            'total_ttc' => number_format((float)$reception['total_ttc'], 3, '.', ''),
            'lines' => $confirmedLines,
        ];
        $confirmationHash = hash('sha256', (string)json_encode($snapshot, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES | JSON_PRESERVE_ZERO_FRACTION));
        $mark = $conn->prepare("UPDATE erp_supplier_receptions SET status='REVIEWED',stock_applied=1,stock_applied_at=NOW(),confirmed_at=NOW(),confirmed_by=?,confirmation_hash=?,created_expense_id=NULLIF(?,0),expense_created_at=CASE WHEN ?>0 THEN COALESCE(expense_created_at,NOW()) ELSE expense_created_at END WHERE id=? AND user_id=? AND stock_applied=0");
        $mark->bind_param('isiiii', $actorId, $confirmationHash, $expenseId, $expenseId, $receptionId, $tenantId);
        $mark->execute();
        if ($mark->affected_rows !== 1) throw new RuntimeException('Supplier reception was confirmed concurrently');
        $mark->close();

        $debugStage = 'source_order_progress';
        $orderStatus = '';
        if ($supplierOrderId > 0) {
            $progress = $conn->prepare("SELECT COALESCE((SELECT SUM(qty) FROM erp_supplier_order_items WHERE supplier_order_id=so.id),0) ordered_qty,COALESCE((SELECT SUM(sri.accepted_qty) FROM erp_supplier_receptions sr JOIN erp_supplier_reception_items sri ON sri.supplier_reception_id=sr.id WHERE sr.supplier_order_id=so.id AND sr.user_id=so.user_id AND sr.stock_applied=1),0) received_qty FROM erp_supplier_orders so WHERE so.id=? AND so.user_id=? FOR UPDATE");
            $progress->bind_param('ii', $supplierOrderId, $tenantId);
            $progress->execute();
            $totals = $progress->get_result()->fetch_assoc();
            $progress->close();
            $orderStatus = (float)$totals['received_qty'] + 0.0005 >= (float)$totals['ordered_qty'] ? 'RECEIVED' : 'PARTIALLY_RECEIVED';
            $orderUpdate = $conn->prepare("UPDATE erp_supplier_orders SET status=? WHERE id=? AND user_id=? AND status IN('SENT','PARTIALLY_RECEIVED')");
            $orderUpdate->bind_param('sii', $orderStatus, $supplierOrderId, $tenantId);
            $orderUpdate->execute();
            if ($orderUpdate->error) throw new RuntimeException('Could not update the source supplier order');
            $orderUpdate->close();
        }

        $debugStage = 'audit';
        $discrepancies = array_values(array_filter($confirmedLines, static fn(array $line): bool =>
            (float)($line['damagedQty'] ?? 0) > 0 || (float)($line['rejectedQty'] ?? 0) > 0
        ));
        auditLog($conn, $tenantId, $actorId, 'SUPPLIER_RECEPTION.CONFIRMED', 'SUPPLIER_RECEPTION', $receptionId,
            ['status' => $reception['status'], 'stock_applied' => false],
            ['status' => 'REVIEWED', 'stock_applied' => true, 'confirmation_hash' => $confirmationHash,
             'applied_lines' => $appliedLines, 'created_products' => $createdProducts,
             'pricing_required_products' => $pricingRequiredProducts,
             'created_expense_id' => $expenseId ?: null, 'supplier_order_status' => $orderStatus ?: null,
             'exception_type' => $exceptionType, 'exception_reason' => $exceptionReason,
             'supplier_delivery_note_number' => (string)($reception['supplier_delivery_note_number'] ?? ''),
             'discrepancy_attachment_name' => (string)($reception['discrepancy_attachment_name'] ?? ''),
             'discrepancies' => $discrepancies]);
        $debugStage = 'commit';
        if ($manageTransaction) $conn->commit();
        structuredLog('INFO', 'SUPPLIER_RECEPTION.CONFIRMED', [
            'supplier_reception_id' => $receptionId,
            'supplier_order_id' => $supplierOrderId,
            'supplier_order_status' => $orderStatus,
            'applied_lines' => $appliedLines,
            'created_products' => $createdProducts,
            'pricing_required_products' => $pricingRequiredProducts,
            'created_expense_id' => $expenseId,
        ]);
        return [
            'id' => $receptionId, 'already_confirmed' => false, 'applied_lines' => $appliedLines,
            'created_products' => $createdProducts, 'created_expense_id' => $expenseId,
            'pricing_required_products' => $pricingRequiredProducts,
            'supplier_order_status' => $orderStatus, 'confirmation_hash' => $confirmationHash,
        ];
    } catch (Throwable $error) {
        if ($manageTransaction) {
            try { $conn->rollback(); } catch (Throwable $ignored) {}
        }
        structuredLog('ERROR', 'SUPPLIER_RECEPTION.CONFIRM_FAILED', [
            'stage' => $debugStage,
            'supplier_reception_id' => $receptionId,
            'supplier_order_id' => $supplierOrderId,
            'exception' => get_class($error),
            'message' => $error->getMessage(),
        ]);
        throw $error;
    }
}
