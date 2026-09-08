<?php
header('Content-Type: application/json');

require_once __DIR__ . '/../config/response.php';
require_once __DIR__ . '/../config/db.php';
require_once __DIR__ . '/../config/validator.php';
require_once __DIR__ . '/../config/actor_identity.php';
require_once __DIR__ . '/../config/tenant_scope.php';
require_once __DIR__ . '/../config/idempotency.php';
require_once __DIR__ . '/../config/audit.php';
require_once __DIR__ . '/../auth/auth_required.php';
require_once __DIR__ . '/../auth/role_helper.php';

require_once __DIR__ . '/../products/product_inventory.php';
require_once __DIR__ . '/../bon_livraisons/helpers.php';
require_once __DIR__ . '/document_number.php';
require_once __DIR__ . '/document_date_policy.php';
require_once __DIR__ . '/workflow_rules.php';
require_once __DIR__ . '/workflow_domain.php';
require_once __DIR__ . '/issuance_snapshot_service.php';
require_once __DIR__ . '/../taxes/tax_profile_service.php';


function normalizeInvoiceBundleSourceFlow(array $data, int $salesOrderId, int $deliveryNoteId): string {
    $rawSourceFlow = getOptionalString($data, 'source_flow');
    if ($rawSourceFlow === '') {
        $rawSourceFlow = getOptionalString($data, 'sourceFlow');
    }

    $sourceFlow = strtoupper(trim((string)$rawSourceFlow));
    if ($sourceFlow === '') {
        if ($deliveryNoteId > 0) {
            return 'DELIVERY';
        }
        if ($salesOrderId > 0) {
            return 'ORDER';
        }
        return 'DIRECT';
    }

    validateEnum($sourceFlow, ['DIRECT', 'ORDER', 'DELIVERY'], 'Source flow');
    return $sourceFlow;
}

function applyIssuedBundleStock(
    mysqli $conn,
    int $userId,
    int $invoiceId,
    string $sourceFlow,
    int $deliveryNoteId,
    array $items
): void {
    if ($sourceFlow === 'DELIVERY' && $deliveryNoteId > 0) {
        $deliveryStmt = $conn->prepare('SELECT stock_applied FROM erp_delivery_notes WHERE id=? AND user_id=? LIMIT 1 FOR UPDATE');
        $deliveryStmt->bind_param('ii', $deliveryNoteId, $userId);
        $deliveryStmt->execute();
        $delivery = $deliveryStmt->get_result()->fetch_assoc();
        $deliveryStmt->close();
        if (!$delivery) throw new Exception('Delivery note not found or not allowed');
        if ((int)$delivery['stock_applied'] !== 1) {
            applyDeliveryStockMovement($conn, $deliveryNoteId, $userId);
        }
        return;
    }

    $requiredStock = [];
    foreach ($items as $item) {
        $productId = (int)($item['product_id'] ?? 0);
        if ($productId <= 0 || !productUsesStock($conn, $productId, $userId)) continue;
        $requiredStock[$productId] = ($requiredStock[$productId] ?? 0.0) + abs((float)$item['qty']);
    }
    ksort($requiredStock, SORT_NUMERIC);
    $stockLock = $conn->prepare('SELECT id FROM products WHERE id=? AND user_id=? LIMIT 1 FOR UPDATE');
    foreach ($requiredStock as $productId => $quantity) {
        $productId = (int)$productId;
        $stockLock->bind_param('ii', $productId, $userId);
        $stockLock->execute();
        if (!$stockLock->get_result()->fetch_assoc()) {
            $stockLock->close();
            throw new Exception('Product not found for stock validation');
        }
        if (getProductStockQuantity($conn, (int)$productId, $userId) + 0.0001 < $quantity) {
            $stockLock->close();
            throw new Exception('Not enough stock to issue this invoice');
        }
    }
    $stockLock->close();
    foreach ($items as $item) {
        $productId = (int)($item['product_id'] ?? 0);
        if ($productId <= 0 || !productUsesStock($conn, $productId, $userId)) continue;
        recordProductStockMovement(
            $conn,
            $productId,
            $userId,
            -abs((float)$item['qty']),
            'INVOICE_OUT',
            'INVOICE',
            $invoiceId,
            'Stock output from issued invoice',
            null,
            'DIRECT_SALE',
            null,
            null,
            'INVOICE:' . $invoiceId . ':ITEM:' . (int)$item['item_id']
        );
        syncProductStockQuantity($conn, $productId, $userId);
    }
}

try {
    if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
        jsonResponse([
            "success" => false,
            "message" => "Method not allowed. Use POST."
        ], 405);
        exit;
    }

    $authUser = requireAuth();
    $user_id = authTenantId($authUser);
    $actorId = authActorId($authUser);
    $data = requireJsonBody();

    $client_id = getRequiredInt($data, 'client_id', 'Client');
    $salespersonName = getOptionalString($data, 'salesperson_name');
    $invoice_date = getRequiredString($data, 'invoice_date', 'Invoice date');
    $invoice_due_date = getRequiredString($data, 'invoice_due_date', 'Due date');
    $invoice_type = strtoupper(getOptionalString($data, 'invoice_type') ?: 'FACTURE');
    $status = strtoupper(getOptionalString($data, 'status') ?: 'UNPAID');
    $notes = getOptionalString($data, 'notes');
    $currency = strtoupper(getOptionalString($data, 'currency') ?: 'TND');
    $exchangeRate = decimalInput($data['exchange_rate'] ?? ($currency === 'TND' ? '1' : ''), 'Exchange rate', 8);
    $exchangeRateDate = trim((string)($data['exchange_rate_date'] ?? $invoice_date));
    $operationTaxProfileId = (int)($data['tax_profile_id'] ?? 0);
    $salesOrderId = isset($data['sales_order_id']) ? (int)$data['sales_order_id'] : (isset($data['salesOrderId']) ? (int)$data['salesOrderId'] : 0);
    $deliveryNoteId = isset($data['delivery_note_id']) ? (int)$data['delivery_note_id'] : (isset($data['deliveryNoteId']) ? (int)$data['deliveryNoteId'] : 0);
    $sourceFlow = normalizeInvoiceBundleSourceFlow($data, $salesOrderId, $deliveryNoteId);
    if ($sourceFlow === 'ORDER') {
        throw new Exception('Issue the invoice from a delivered delivery note or use the direct flow');
    }
    if ($sourceFlow === 'DELIVERY' && $deliveryNoteId <= 0) {
        throw new Exception('The delivery flow requires a delivery note');
    }
    if ($sourceFlow === 'DIRECT' && ($salesOrderId > 0 || $deliveryNoteId > 0)) {
        throw new Exception('The direct flow cannot reference an order or delivery note');
    }
    $timbre = isset($data['timbre']) && $data['timbre'] !== ''
        ? validatePositiveNumber($data['timbre'], 'Timbre')
        : 1.0;
    $items = isset($data['items']) && is_array($data['items']) ? $data['items'] : [];
    $pending_products = isset($data['pending_products']) && is_array($data['pending_products']) ? $data['pending_products'] : [];
    $idempotencyKey = requiredIdempotencyKey($data);

    validateDate($invoice_date, 'Invoice date');
    validateMaxLength($salespersonName, 191, 'Salesperson name');
    validateDate($invoice_due_date, 'Due date');
    validateDocumentDates($invoice_date, $invoice_due_date);
    if ($invoice_type !== 'FACTURE') throw new Exception('This endpoint issues FACTURE documents only');
    if ($status !== 'UNPAID') throw new Exception('Issued invoices must start unpaid; record settlement through the payment ledger');
    validateEnum($currency, ['TND', 'EUR', 'USD'], 'Currency');
    validateDate($exchangeRateDate, 'Exchange rate date');
    if (bccomp($exchangeRate, '0', 8) <= 0) throw new Exception('Exchange rate must be greater than zero');
    if ($currency === 'TND' && bccomp($exchangeRate, '1', 8) !== 0) throw new Exception('TND documents must use an exchange rate of 1');

    if (!$items) {
        throw new Exception('Add at least one invoice item before validation');
    }
    if ($pending_products) {
        throw new Exception('Create catalog products before issuing the invoice');
    }

    $conn = db();
    if ($salespersonName === '') {
        $salespersonName = actorCommercialName($conn, $actorId);
    }
    requireInvoiceDocumentPermission($conn, $user_id, $invoice_type, 'create');
    requireInvoiceDocumentPermission($conn, $user_id, $invoice_type, 'validate');
    enforceInvoiceDatePolicy($conn, $user_id, $invoice_date);
    ensureProductInventorySchema($conn);
    ensureTaxProfileSchema($conn);
    $conn->begin_transaction();

    try {
        $requestHash = idempotencyRequestHash($data);
        $replayedId = claimIdempotencyKey($conn, $user_id, 'invoice.bundle.create', $idempotencyKey, $requestHash);
        if ($replayedId !== null) {
            $replayStmt = $conn->prepare('SELECT invoice,invoice_type,status,IFNULL(is_validated,0) is_validated FROM erp_invoices WHERE id=? AND user_id=? LIMIT 1');
            $replayStmt->bind_param('ii', $replayedId, $user_id);
            $replayStmt->execute();
            $replay = $replayStmt->get_result()->fetch_assoc();
            $replayStmt->close();
            if (!$replay
                || strtoupper((string)$replay['invoice_type']) !== 'FACTURE'
                || (int)$replay['is_validated'] !== 1) {
                throw new Exception('The idempotency key does not reference an issued invoice');
            }
            $conn->commit();
            jsonResponse(['success' => true, 'id' => $replayedId, 'invoice' => $replay['invoice'], 'status' => $replay['status'], 'is_validated' => true, 'replayed' => true]);
        }
        $clientStmt = $conn->prepare("
            SELECT id
            FROM clients
            WHERE id = ? AND user_id = ?
            LIMIT 1
        ");
        if (!$clientStmt) {
            throw new Exception("Failed to prepare client lookup: " . $conn->error);
        }
        $clientStmt->bind_param("ii", $client_id, $user_id);
        $clientStmt->execute();
        $clientRow = $clientStmt->get_result()->fetch_assoc();
        $clientStmt->close();

        if (!$clientRow) {
            throw new Exception('Client not found or not allowed');
        }

        if ($salesOrderId > 0) {
            $orderStmt = $conn->prepare("
                SELECT id, client_id, status
                FROM erp_sales_orders
                WHERE id = ? AND user_id = ?
                LIMIT 1
            ");
            if (!$orderStmt) {
                throw new Exception("Failed to prepare sales order lookup: " . $conn->error);
            }
            $orderStmt->bind_param("ii", $salesOrderId, $user_id);
            $orderStmt->execute();
            $orderRow = $orderStmt->get_result()->fetch_assoc();
            $orderStmt->close();

            if (!$orderRow
                || (int)$orderRow['client_id'] !== $client_id
                || in_array(strtoupper((string)$orderRow['status']), ['DRAFT', 'CANCELLED'], true)) {
                throw new Exception('Sales order is not eligible for this invoice');
            }
        }

        if ($deliveryNoteId > 0) {
            $deliveryStmt = $conn->prepare("
                SELECT id, client_id, sales_order_id, status
                FROM erp_delivery_notes
                WHERE id = ? AND user_id = ?
                LIMIT 1
            ");
            if (!$deliveryStmt) {
                throw new Exception("Failed to prepare delivery note lookup: " . $conn->error);
            }
            $deliveryStmt->bind_param("ii", $deliveryNoteId, $user_id);
            $deliveryStmt->execute();
            $deliveryRow = $deliveryStmt->get_result()->fetch_assoc();
            $deliveryStmt->close();

            if (!$deliveryRow || (int)$deliveryRow['client_id'] !== $client_id || (string)$deliveryRow['status'] !== 'DELIVERED') {
                throw new Exception('Invoice creation requires a delivered delivery note for the same client');
            }
            $linkedSalesOrderId = (int)($deliveryRow['sales_order_id'] ?? 0);
            if ($salesOrderId > 0 && $linkedSalesOrderId > 0 && $salesOrderId !== $linkedSalesOrderId) {
                throw new Exception('Delivery note and sales order do not match');
            }
            if ($salesOrderId <= 0 && $linkedSalesOrderId > 0) $salesOrderId = $linkedSalesOrderId;
        }

        $validatedItems = [];
        $sumSubtotal = '0.000'; $sumTva = '0.000'; $sumFodec = '0.000';
        $sumSubtotalTnd = '0.000'; $sumTaxTnd = '0.000'; $sumTotalTnd = '0.000';

        foreach ($items as $index => $item) {
            if (!is_array($item)) {
                throw new Exception("Invalid item at position " . ($index + 1));
            }

            $product_code = trim((string)($item['product_code'] ?? ''));
            $product_id = (int)($item['product_id'] ?? 0);
            requireTenantProduct($conn, $user_id, $product_id);
            $product = trim((string)($item['product'] ?? ''));
            $qty = (float)($item['qty'] ?? 0);
            $price = (float)($item['price'] ?? 0);
            $discount = (float)($item['discount'] ?? 0);

            if ($product === '') {
                throw new Exception("Item name is required for item " . ($index + 1));
            }
            if ($qty <= 0) {
                throw new Exception("Quantity must be greater than 0 for item " . ($index + 1));
            }
            if ($price < 0) {
                throw new Exception("Price cannot be negative for item " . ($index + 1));
            }
            if ($discount < 0 || $discount > 100) {
                throw new Exception("Discount must be between 0 and 100 for item " . ($index + 1));
            }
            validateMaxLength($product_code, 100, 'Item code');
            validateMaxLength($product, 255, 'Item name');

            $profileId=(int)($item['tax_profile_id']??$operationTaxProfileId);
            $profile=resolveTaxProfile($conn,$user_id,$profileId,$product_id,$invoice_date);
            $tax=calculateTaxLine($qty,$price,$discount,$profile,$exchangeRate);

            $validatedItems[] = [
                'product_id' => $product_id,
                'product_code' => $product_code,
                'product' => $product,
                'qty' => $qty,
                'tax_profile_id'=>(int)$profile['id'],'tva_rate'=>$tax['vat_rate'],'tax_regime'=>$tax['tax_regime'],
                'fodec_rate'=>$tax['fodec_rate'],'fodec_amount'=>$tax['fodec_amount'],'legal_basis'=>$tax['legal_basis'],'certificate_reference'=>$tax['certificate_reference'],
                'montant_tva' => $tax['vat'],
                'price' => $price,
                'discount' => $discount,
                'subtotal' => $tax['subtotal'],'subtotal_ttc'=>$tax['total'],
                'subtotal_tnd'=>$tax['subtotal_tnd'],'tax_tnd'=>$tax['tax_tnd'],'total_tnd'=>$tax['total_tnd'],
            ];
            $sumSubtotal=bcadd($sumSubtotal,$tax['subtotal'],3);$sumTva=bcadd($sumTva,$tax['vat'],3);$sumFodec=bcadd($sumFodec,$tax['fodec_amount'],3);
            $sumSubtotalTnd=bcadd($sumSubtotalTnd,$tax['subtotal_tnd'],3);$sumTaxTnd=bcadd($sumTaxTnd,$tax['tax_tnd'],3);$sumTotalTnd=bcadd($sumTotalTnd,$tax['total_tnd'],3);
        }

        if ($deliveryNoteId > 0) validateInvoiceAgainstDeliveredNote($conn,$deliveryNoteId,$user_id,$client_id,$validatedItems,0);

        $base_tva=bcadd($sumSubtotal,$sumFodec,3);$montant_tva=$sumTva;
        $subtotal_ttc=bcadd($base_tva,$montant_tva,3);$total=bcadd($subtotal_ttc,(string)$timbre,3);
        $totalTnd=bcadd($sumTotalTnd,money3(bcmul((string)$timbre,$exchangeRate,8)),3);

        $invoiceNumber = nextDocumentNumber($conn, $user_id, $invoice_type, $invoice_date);
        $custom_code = (string)$client_id;

        $invoiceStmt = $conn->prepare("
            INSERT INTO erp_invoices (
                invoice,
                custom_code,
                salesperson_name,
                sales_order_id,
                delivery_note_id,
                source_flow,
                invoice_date,
                invoice_due_date,
                tax_profile_id,currency,exchange_rate,exchange_rate_date,
                subtotal,
                subtotal_tnd,
                base_tva,
                montant_tva,
                tax_total_tnd,
                subtotal_ttc,
                shipping,
                discount,
                vat,
                timbre,
                total,
                total_tnd,
                notes,
                invoice_type,
                status,
                is_validated,
                type_doc,
                user_id
            ) VALUES (?, ?, NULLIF(?, ''), NULLIF(?, 0), NULLIF(?, 0), ?, ?, ?, NULLIF(?,0), ?, ?, ?, ?, ?, ?, ?, ?, ?, 0, 0, 0, ?, ?, ?, ?, ?, ?, 1, 'F', ?)
        ");
        if (!$invoiceStmt) {
            throw new Exception("Failed to prepare invoice insert: " . $conn->error);
        }
        $invoiceStmt->bind_param(
            "sssiisssisdsdddddddddsssi",
            $invoiceNumber,
            $custom_code,
            $salespersonName,
            $salesOrderId,
            $deliveryNoteId,
            $sourceFlow,
            $invoice_date,
            $invoice_due_date,
            $operationTaxProfileId,$currency,$exchangeRate,$exchangeRateDate,
            $sumSubtotal,
            $sumSubtotalTnd,
            $base_tva,
            $montant_tva,
            $sumTaxTnd,
            $subtotal_ttc,
            $timbre,
            $total,
            $totalTnd,
            $notes,
            $invoice_type,
            $status,
            $user_id
        );
        $invoiceStmt->execute();
        if ($invoiceStmt->error) {
            throw new Exception("Failed to create invoice: " . $invoiceStmt->error);
        }
        $invoiceId = (int)$invoiceStmt->insert_id;
        $invoiceStmt->close();

        $itemStmt = $conn->prepare("
            INSERT INTO erp_invoice_items (
                invoice_id,
                invoice,
                product_code,
                tax_profile_id,
                product,
                qty,
                tva_rate,
                tax_regime,fodec_rate,fodec_amount,legal_basis,certificate_reference,
                montant_tva,
                tax_tnd,
                price,
                discount,
                subtotal,
                subtotal_tnd,
                subtotalTTC,
                total_tnd,
                invoice_date
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ");
        if (!$itemStmt) {
            throw new Exception("Failed to prepare item insert: " . $conn->error);
        }

        $issuedItems = [];
        foreach ($validatedItems as $item) {
            $itemSubtotalTtc = $item['subtotal_ttc'];
            $itemStmt->bind_param(
                "issisddsddssdddddddds",
                $invoiceId,
                $invoiceNumber,
                $item['product_code'],
                $item['tax_profile_id'],
                $item['product'],
                $item['qty'],
                $item['tva_rate'],
                $item['tax_regime'],$item['fodec_rate'],$item['fodec_amount'],$item['legal_basis'],$item['certificate_reference'],
                $item['montant_tva'],
                $item['tax_tnd'],
                $item['price'],
                $item['discount'],
                $item['subtotal'],
                $item['subtotal_tnd'],
                $itemSubtotalTtc,
                $item['total_tnd'],
                $invoice_date
            );
            $itemStmt->execute();
            if ($itemStmt->error) {
                throw new Exception("Failed to create invoice item: " . $itemStmt->error);
            }
            $issuedItems[] = $item + ['item_id' => (int)$itemStmt->insert_id];
        }
        $itemStmt->close();

        applyIssuedBundleStock($conn, $user_id, $invoiceId, $sourceFlow, $deliveryNoteId, $issuedItems);
        $issuanceSnapshot = captureInvoiceIssuanceSnapshot($conn, $user_id, $actorId, $invoiceId);

        auditLog($conn, $user_id, $actorId, 'INVOICE.ISSUED', 'INVOICE', $invoiceId, null, [
            'number' => $invoiceNumber,
            'invoice_type' => $invoice_type,
            'status' => $status,
            'is_validated' => true,
            'client_id' => $client_id,
            'currency' => $currency,
            'total' => $total,
            'total_tnd' => $totalTnd,
            'source_flow' => $sourceFlow,
            'snapshot_sha256' => hash('sha256', invoiceSnapshotJson($issuanceSnapshot)),
        ]);
        completeIdempotencyKey($conn, $user_id, 'invoice.bundle.create', $idempotencyKey, $invoiceId);
        $conn->commit();

        jsonResponse([
            "success" => true,
            "id" => $invoiceId,
            "invoice" => $invoiceNumber,
            "status" => "UNPAID",
            "is_validated" => true,
            "replayed" => false,
            "message" => "Invoice issued successfully"
        ]);
    } catch (Throwable $e) {
        $conn->rollback();
        throw $e;
    }
} catch (Throwable $e) {
    jsonResponse([
        "success" => false,
        "message" => $e->getMessage()
    ], 400);
}
?>
