<?php
header('Content-Type: application/json');

require_once __DIR__ . '/../config/response.php';
require_once __DIR__ . '/../config/db.php';
require_once __DIR__ . '/../config/audit.php';
require_once __DIR__ . '/../auth/auth_required.php';
require_once __DIR__ . '/../auth/role_helper.php';

require_once __DIR__ . '/../products/product_inventory.php';
require_once __DIR__ . '/../bon_livraisons/helpers.php';
require_once __DIR__ . '/workflow_schema.php';
require_once __DIR__ . '/document_number.php';
require_once __DIR__ . '/document_date_policy.php';
require_once __DIR__ . '/workflow_rules.php';
require_once __DIR__ . '/workflow_domain.php';
require_once __DIR__ . '/issuance_snapshot_service.php';
require_once __DIR__ . '/../invoice_settlements/service.php';


function normalizeInvoiceSourceFlowForUpdate(array $data, int $salesOrderId, int $deliveryNoteId): ?string {
    $hasSourceFlow = array_key_exists('source_flow', $data) || array_key_exists('sourceFlow', $data);
    if (!$hasSourceFlow) {
        if ($deliveryNoteId > 0) {
            return 'DELIVERY';
        }
        if ($salesOrderId > 0) {
            return 'ORDER';
        }
        return null;
    }

    $rawSourceFlow = array_key_exists('source_flow', $data)
        ? trim((string)$data['source_flow'])
        : trim((string)$data['sourceFlow']);

    $sourceFlow = strtoupper($rawSourceFlow);
    if ($sourceFlow === '') {
        if ($deliveryNoteId > 0) {
            return 'DELIVERY';
        }
        if ($salesOrderId > 0) {
            return 'ORDER';
        }
        return 'DIRECT';
    }

    if (!in_array($sourceFlow, ['DIRECT', 'ORDER', 'DELIVERY'], true)) {
        throw new Exception('Invalid source_flow');
    }

    return $sourceFlow;
}

function applyInvoiceStockMovements(mysqli $conn, int $invoiceId, int $userId): void
{
    ensureProductInventorySchema($conn);

    if (hasStockMovementReference($conn, $userId, 'INVOICE', $invoiceId)) {
        return;
    }

    $invoiceStmt = $conn->prepare("
        SELECT
            id,
            invoice,
            invoice_type,
            IFNULL(source_flow, 'DIRECT') AS source_flow,
            IFNULL(delivery_note_id, 0) AS delivery_note_id,
            IFNULL(is_validated, 0) AS is_validated,
            IFNULL(return_to_stock, 0) AS return_to_stock
        FROM erp_invoices
        WHERE id = ? AND user_id = ?
        LIMIT 1
    ");
    if (!$invoiceStmt) {
        throw new Exception('Failed to prepare invoice stock lookup: ' . $conn->error);
    }
    $invoiceStmt->bind_param('ii', $invoiceId, $userId);
    $invoiceStmt->execute();
    $invoice = $invoiceStmt->get_result()->fetch_assoc();
    $invoiceStmt->close();

    if (!$invoice || (int)$invoice['is_validated'] !== 1) {
        return;
    }

    $invoiceType = strtoupper((string)($invoice['invoice_type'] ?? 'FACTURE'));
    if ($invoiceType === 'DEVIS') {
        return;
    }
    if ($invoiceType === 'AVOIR' && (int)($invoice['return_to_stock'] ?? 0) !== 1) {
        return;
    }

    $sourceFlow = strtoupper((string)($invoice['source_flow'] ?? 'DIRECT'));
    $deliveryNoteId = (int)($invoice['delivery_note_id'] ?? 0);
    if ($sourceFlow === 'DELIVERY' && $deliveryNoteId > 0) {
        $deliveryStmt = $conn->prepare("
            SELECT id, IFNULL(stock_applied, 0) AS stock_applied
            FROM erp_delivery_notes
            WHERE id = ? AND user_id = ?
            LIMIT 1
        ");
        if (!$deliveryStmt) {
            throw new Exception('Failed to prepare linked delivery lookup: ' . $conn->error);
        }
        $deliveryStmt->bind_param('ii', $deliveryNoteId, $userId);
        $deliveryStmt->execute();
        $delivery = $deliveryStmt->get_result()->fetch_assoc();
        $deliveryStmt->close();

        if ($delivery && (int)$delivery['stock_applied'] !== 1) {
            applyDeliveryStockMovement($conn, $deliveryNoteId, $userId);
        }
        return;
    }

    $itemsStmt = $conn->prepare("
        SELECT id, product_id, product_code, product, qty
        FROM erp_invoice_items
        WHERE invoice_id = ?
        ORDER BY id
    ");
    if (!$itemsStmt) {
        throw new Exception('Failed to prepare invoice stock items: ' . $conn->error);
    }
    $itemsStmt->bind_param('i', $invoiceId);
    $itemsStmt->execute();
    $items = $itemsStmt->get_result()->fetch_all(MYSQLI_ASSOC);
    $itemsStmt->close();

    foreach ($items as $item) {
        $productId = resolveProductIdForUser(
            $conn,
            $userId,
            (int)($item['product_id'] ?? 0),
            (string)($item['product_code'] ?? ''),
            (string)($item['product'] ?? '')
        );

        if ($productId <= 0) {
            throw new Exception('Missing product link for invoice item "' . (string)($item['product'] ?? 'Unknown product') . '"');
        }
        if (!productUsesStock($conn, $productId, $userId)) {
            continue;
        }

        $qty = abs((float)($item['qty'] ?? 0));
        if ($qty <= 0) {
            continue;
        }

        $quantity = $invoiceType === 'AVOIR' ? $qty : -$qty;
        $movementType = $invoiceType === 'AVOIR' ? 'RETURN_IN' : 'INVOICE_OUT';
        $note = $invoiceType === 'AVOIR'
            ? 'Stock returned from avoir'
            : 'Stock output from validated invoice';

        recordProductStockMovement(
            $conn,
            $productId,
            $userId,
            $quantity,
            $movementType,
            'INVOICE',
            $invoiceId,
            $note,
            null,
            $invoiceType === 'AVOIR' ? 'CUSTOMER_GOODS_RETURN' : 'DIRECT_SALE',
            null,
            null,
            'INVOICE:' . $invoiceId . ':ITEM:' . (int)$item['id']
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
    $user_id = (int)$authUser->id;

    $data = json_decode(file_get_contents("php://input"), true);

    if (!is_array($data)) {
        throw new Exception("Invalid JSON body");
    }

    ensureProductInventorySchema(db());

    $invoice_id = isset($data['id']) ? (int)$data['id'] : 0;

    if ($invoice_id <= 0) {
        throw new Exception("Invalid invoice id");
    }

    $fields = [];
    $types = '';
    $values = [];
    $salesOrderId = array_key_exists('sales_order_id', $data) || array_key_exists('salesOrderId', $data)
        ? (int)(array_key_exists('sales_order_id', $data) ? $data['sales_order_id'] : $data['salesOrderId'])
        : 0;
    $deliveryNoteId = array_key_exists('delivery_note_id', $data) || array_key_exists('deliveryNoteId', $data)
        ? (int)(array_key_exists('delivery_note_id', $data) ? $data['delivery_note_id'] : $data['deliveryNoteId'])
        : 0;

    if (array_key_exists('invoice_date', $data)) {
        $fields[] = 'invoice_date = ?';
        $types .= 's';
        $values[] = trim((string)$data['invoice_date']);
    }

    if (array_key_exists('invoice_due_date', $data)) {
        $fields[] = 'invoice_due_date = ?';
        $types .= 's';
        $values[] = trim((string)$data['invoice_due_date']);
    }

    if (array_key_exists('notes', $data)) {
        $fields[] = 'notes = ?';
        $types .= 's';
        $values[] = trim((string)$data['notes']);
    }

    if (array_key_exists('salesperson_name', $data)) {
        $salespersonName = trim((string)$data['salesperson_name']);
        if (mb_strlen($salespersonName) > 191) throw new Exception('Salesperson name is too long');
        $fields[] = "salesperson_name = NULLIF(?, '')";
        $types .= 's';
        $values[] = $salespersonName;
    }

    $status = null;
    if (array_key_exists('status', $data)) {
        $status = trim((string)$data['status']);
        if ($status === '') $status = 'UNPAID';
        $status = strtoupper($status);
        $fields[] = 'status = ?';
        $types .= 's';
        $values[] = $status;
    }

    if (array_key_exists('is_validated', $data)) {
        $isValidated = filter_var($data['is_validated'], FILTER_VALIDATE_BOOLEAN, FILTER_NULL_ON_FAILURE);
        if ($isValidated === null) {
            throw new Exception('Invalid is_validated value');
        }
        $fields[] = 'is_validated = ?';
        $types .= 'i';
        $values[] = $isValidated ? 1 : 0;
    }

    if (array_key_exists('invoice_type', $data)) {
        $invoiceType = strtoupper(trim((string)$data['invoice_type']));
        if ($invoiceType === '') $invoiceType = 'FACTURE';
        if (!in_array($invoiceType, ['FACTURE', 'DRAFT', 'DEVIS', 'AVOIR'], true)) {
            throw new Exception('Invalid invoice_type');
        }
        $fields[] = 'invoice_type = ?';
        $types .= 's';
        $values[] = $invoiceType;
    }

    if (array_key_exists('return_to_stock', $data) || array_key_exists('returnToStock', $data)) {
        $rawReturn = array_key_exists('return_to_stock', $data) ? $data['return_to_stock'] : $data['returnToStock'];
        $returnToStock = filter_var($rawReturn, FILTER_VALIDATE_BOOLEAN, FILTER_NULL_ON_FAILURE);
        if ($returnToStock === null) throw new Exception('Invalid return_to_stock value');
        $fields[] = 'return_to_stock = ?';
        $types .= 'i';
        $values[] = $returnToStock ? 1 : 0;
    }

    if (array_key_exists('transformation_status', $data)) {
        $transformationStatus = strtoupper(trim((string)$data['transformation_status']));
        if (!in_array($transformationStatus, workflowTransformationStatuses(), true)) {
            throw new Exception('Invalid transformation_status');
        }
        $fields[] = 'transformation_status = ?';
        $types .= 's';
        $values[] = $transformationStatus;
    }

    // payment_method: accept snake_case or camelCase
    if (array_key_exists('payment_method', $data) || array_key_exists('paymentMethod', $data)) {
        $pmRaw = array_key_exists('payment_method', $data) ? $data['payment_method'] : $data['paymentMethod'];

        if ($pmRaw === null || trim((string)$pmRaw) === '') {
            // Explicitly clear payment method
            $fields[] = 'payment_method = NULL';
        } else {
            $payment_method = strtoupper(trim((string)$pmRaw));

            // Map common French labels to enum values
            $map = [
                'ESPECES'  => 'CASH',
                'ESPÈCES'  => 'CASH',
                'CASH'     => 'CASH',
                'CARTE'    => 'CARD',
                'CARD'     => 'CARD',
                'VIREMENT' => 'TRANSFER',
                'TRANSFER' => 'TRANSFER',
                'CHEQUE'   => 'CHECK',
                'CHÈQUE'   => 'CHECK',
                'CHECK'    => 'CHECK',
            ];

            if (isset($map[$payment_method])) {
                $payment_method = $map[$payment_method];
            }

            $allowed_payment_methods = ['CASH', 'CARD', 'TRANSFER', 'CHECK'];
            if (!in_array($payment_method, $allowed_payment_methods, true)) {
                throw new Exception('Invalid payment_method');
            }

            $fields[] = 'payment_method = ?';
            $types .= 's';
            $values[] = $payment_method;
        }
    }

    foreach (['subtotal','base_tva','baseTva','montant_tva','subtotal_ttc','total','subtotal_tnd','tax_total_tnd','total_tnd'] as $authoritativeField) {
        if (array_key_exists($authoritativeField, $data)) throw new Exception('Document totals are calculated by the backend and cannot be supplied by the client');
    }

    if (array_key_exists('timbre', $data)) {
        $fields[] = 'timbre = ?';
        $types .= 'd';
        $values[] = (float)$data['timbre'];
    }

    if (array_key_exists('sales_order_id', $data) || array_key_exists('salesOrderId', $data)) {
        $fields[] = 'sales_order_id = NULLIF(?, 0)';
        $types .= 'i';
        $values[] = $salesOrderId;
    }

    if (array_key_exists('delivery_note_id', $data) || array_key_exists('deliveryNoteId', $data)) {
        $fields[] = 'delivery_note_id = NULLIF(?, 0)';
        $types .= 'i';
        $values[] = $deliveryNoteId;
    }

    $sourceFlow = normalizeInvoiceSourceFlowForUpdate($data, $salesOrderId, $deliveryNoteId);
    if ($sourceFlow !== null) {
        $fields[] = 'source_flow = ?';
        $types .= 's';
        $values[] = $sourceFlow;
    }

    if (!$fields) {
        throw new Exception("No invoice fields to update");
    }

    $conn = db();
    ensureInvoiceWorkflowSchema($conn);
    ensureProductInventorySchema($conn);
    $conn->begin_transaction();

    $checkInvoice = $conn->prepare('SELECT id, invoice, invoice_date, invoice_due_date, invoice_type, status, total, IFNULL(is_validated, 0) AS is_validated, IFNULL(source_invoice_id, 0) AS source_invoice_id FROM erp_invoices WHERE id = ? AND user_id = ? LIMIT 1 FOR UPDATE');
    if (!$checkInvoice) {
        throw new Exception('Failed to prepare invoice check: ' . $conn->error);
    }
    $checkInvoice->bind_param('ii', $invoice_id, $user_id);
    $checkInvoice->execute();
    $invoiceRow = $checkInvoice->get_result()->fetch_assoc();
    $checkInvoice->close();

    if (!$invoiceRow) {
        throw new Exception('Invoice not found or unauthorized');
    }

    $invoiceType = strtoupper((string)($invoiceRow['invoice_type'] ?? 'FACTURE'));
    requireInvoiceDocumentPermission($conn, $user_id, $invoiceType, 'edit');

    if ($status !== null) {
        $effectiveInvoiceType = array_key_exists('invoice_type', $data)
            ? strtoupper(trim((string)$data['invoice_type']))
            : $invoiceType;
        $allowedStatuses = $effectiveInvoiceType === 'DEVIS' ? workflowDevisStatuses() : workflowInvoiceDraftStatuses();
        if (!in_array($status, $allowedStatuses, true)) {
            throw new Exception('Invalid status');
        }
        if ($effectiveInvoiceType === 'DEVIS'
            && (int)$invoiceRow['is_validated'] === 0
            && strtoupper((string)$invoiceRow['status']) === 'DRAFT'
            && !in_array($status, ['DRAFT', 'SENT'], true)) {
            throw new Exception('A draft quotation must be sent before it can be accepted or rejected');
        }
    }

    $validatedDevisStatusOnly = $invoiceType === 'DEVIS'
        && (int)$invoiceRow['is_validated'] === 1
        && array_key_exists('status', $data)
        && count(array_diff(array_keys($data), ['id', 'status'])) === 0;
    if ((int)$invoiceRow['is_validated'] === 1 && !$validatedDevisStatusOnly) {
        throw new Exception('Issued documents are immutable; create a replacement draft or credit note instead');
    }
    if ($validatedDevisStatusOnly) {
        $currentDevisStatus = strtoupper((string)$invoiceRow['status']);
        $nextDevisStatus = strtoupper(trim((string)$data['status']));
        $allowedDevisTransitions = ['SENT' => ['ACCEPTED', 'REJECTED']];
        if (!in_array($nextDevisStatus, $allowedDevisTransitions[$currentDevisStatus] ?? [], true)) {
            throw new Exception('Invalid quotation status transition');
        }
    }

    if ($salesOrderId > 0) {
        $orderStmt = $conn->prepare("
            SELECT id
            FROM erp_sales_orders
            WHERE id = ? AND user_id = ?
            LIMIT 1
        ");
        if (!$orderStmt) {
            throw new Exception('Failed to prepare sales order lookup: ' . $conn->error);
        }
        $orderStmt->bind_param('ii', $salesOrderId, $user_id);
        $orderStmt->execute();
        $orderRow = $orderStmt->get_result()->fetch_assoc();
        $orderStmt->close();

        if (!$orderRow) {
            throw new Exception('Sales order not found or unauthorized');
        }
    }

    if ($deliveryNoteId > 0) {
        $deliveryStmt = $conn->prepare("
            SELECT id
            FROM erp_delivery_notes
            WHERE id = ? AND user_id = ?
            LIMIT 1
        ");
        if (!$deliveryStmt) {
            throw new Exception('Failed to prepare delivery note lookup: ' . $conn->error);
        }
        $deliveryStmt->bind_param('ii', $deliveryNoteId, $user_id);
        $deliveryStmt->execute();
        $deliveryRow = $deliveryStmt->get_result()->fetch_assoc();
        $deliveryStmt->close();

        if (!$deliveryRow) {
            throw new Exception('Delivery note not found or unauthorized');
        }
    }

    $requestedValidation = array_key_exists('is_validated', $data)
        && filter_var($data['is_validated'], FILTER_VALIDATE_BOOLEAN) === true;
    $requestedStatus = array_key_exists('status', $data) ? strtoupper(trim((string)$data['status'])) : null;
    $implicitDraftValidation = strtoupper((string)($invoiceRow['invoice_type'] ?? 'FACTURE')) === 'DRAFT'
        && $requestedStatus !== null
        && in_array($requestedStatus, ['UNPAID', 'PAID', 'CANCELLED'], true);
    $devisIssuance = strtoupper((string)($invoiceRow['invoice_type'] ?? '')) === 'DEVIS'
        && strtoupper((string)($invoiceRow['status'] ?? 'DRAFT')) === 'DRAFT'
        && $requestedStatus === 'SENT';

    if (array_key_exists('invoice_type', $data)) {
        $requestedInvoiceType = strtoupper(trim((string)$data['invoice_type']));
        if ($requestedInvoiceType === '') $requestedInvoiceType = 'FACTURE';
        $currentInvoiceType = strtoupper((string)$invoiceRow['invoice_type']);
        $allowedDraftPromotion = $currentInvoiceType === 'DRAFT'
            && $requestedInvoiceType === 'FACTURE'
            && ($requestedValidation || $implicitDraftValidation);
        if ($requestedInvoiceType !== $currentInvoiceType && !$allowedDraftPromotion) {
            throw new Exception('Document type cannot be changed directly. Create the target document through its workflow.');
        }
    }

    if ($requestedValidation || $implicitDraftValidation || $validatedDevisStatusOnly) {
        requireInvoiceDocumentPermission($conn, $user_id, $invoiceType, 'validate');
    }
    if ($devisIssuance) {
        requireInvoiceDocumentPermission($conn, $user_id, $invoiceType, 'send');
    }
    if ($invoiceType === 'AVOIR' && ($requestedValidation || $implicitDraftValidation)) {
        requirePermission($conn, $user_id, 'invoices.credit');
    }

    $effectiveInvoiceDate = array_key_exists('invoice_date', $data)
        ? trim((string)$data['invoice_date'])
        : trim((string)$invoiceRow['invoice_date']);
    $effectiveDueDate = array_key_exists('invoice_due_date', $data)
        ? trim((string)$data['invoice_due_date'])
        : trim((string)$invoiceRow['invoice_due_date']);
    validateDocumentDates($effectiveInvoiceDate, $effectiveDueDate);
    if (strtoupper((string)$invoiceRow['invoice_type']) !== 'DEVIS') {
        enforceInvoiceDatePolicy($conn, $user_id, $effectiveInvoiceDate);
    }

    $assignedInvoiceNumber = (string)$invoiceRow['invoice'];

    if ($devisIssuance) {
        $fields[] = 'is_validated = ?';
        $types .= 'i';
        $values[] = 1;
    }

    if ($implicitDraftValidation) {
        $fields[] = 'invoice_type = ?';
        $types .= 's';
        $values[] = 'FACTURE';

        $fields[] = 'is_validated = ?';
        $types .= 'i';
        $values[] = 1;
    }

    if ($requestedValidation) {
        $documentType = strtoupper((string)$invoiceRow['invoice_type']);
        if ($documentType === 'DEVIS') {
            throw new Exception('Devis cannot be validated with this action');
        }
        if ($documentType === 'FACTURE' && (!isset($status) || $status !== 'UNPAID')) {
            throw new Exception('A validated invoice must start as UNPAID');
        }
        if ($documentType === 'AVOIR' && (!isset($status) || $status !== 'DRAFT')) {
            throw new Exception('A validated avoir must stay as DRAFT');
        }
        if ($documentType === 'AVOIR') {
            $sourceInvoiceId = (int)$invoiceRow['source_invoice_id'];
            if ($sourceInvoiceId <= 0) {
                throw new Exception('A credit note must reference its source invoice');
            }
            $sourceSummary = settlementSummary($conn, $sourceInvoiceId, $user_id);
            $creditAmount = abs((float)$invoiceRow['total']);
            if ($creditAmount <= 0.0005) {
                throw new Exception('A credit note amount must be greater than zero');
            }
            if ($creditAmount > max(0.0, (float)$sourceSummary['remaining_balance']) + 0.0005) {
                throw new Exception('Credit note exceeds the source invoice outstanding balance');
            }
        }
    }

    if ($requestedValidation || $implicitDraftValidation || $devisIssuance) {
        $numberType = strtoupper((string)$invoiceRow['invoice_type']) === 'DRAFT'
            ? 'FACTURE'
            : strtoupper((string)$invoiceRow['invoice_type']);
        $assignedInvoiceNumber = nextDocumentNumber($conn, $user_id, $numberType, $effectiveInvoiceDate);
        $fields[] = 'invoice = ?';
        $types .= 's';
        $values[] = $assignedInvoiceNumber;
    }

    if (($requestedValidation || $implicitDraftValidation) && $deliveryNoteId > 0) {
        $itemsCheck=$conn->prepare('SELECT product_id,product_code,product,qty FROM erp_invoice_items WHERE invoice_id=?');$itemsCheck->bind_param('i',$invoice_id);$itemsCheck->execute();$validationItems=$itemsCheck->get_result()->fetch_all(MYSQLI_ASSOC);$itemsCheck->close();
        $clientForValidation=(int)($data['client_id']??0); if($clientForValidation<=0){$clientForValidation=(int)$conn->query('SELECT CAST(custom_code AS UNSIGNED) client_id FROM erp_invoices WHERE id='.(int)$invoice_id)->fetch_assoc()['client_id'];}
        validateInvoiceAgainstDeliveredNote($conn,$deliveryNoteId,$user_id,$clientForValidation,$validationItems,$invoice_id);
    }

    $sql = "
        UPDATE erp_invoices
        SET " . implode(', ', $fields) . "
        WHERE id = ? AND user_id = ?
        LIMIT 1
    ";

    $types .= 'ii';
    $values[] = $invoice_id;
    $values[] = $user_id;

    $stmt = $conn->prepare($sql);

    $params = [];
    foreach ($values as $key => $value) {
        $params[$key] = &$values[$key];
    }

    $stmt->bind_param($types, ...$params);
    $stmt->execute();

    if ($stmt->errno) {
        throw new Exception('Invoice update failed: ' . $stmt->error);
    }

    // If no rows changed, it can be either: (a) invoice not found/unauthorized, or (b) same values.
    if ($stmt->affected_rows === 0) {
        $chk = $conn->prepare('SELECT id FROM erp_invoices WHERE id = ? AND user_id = ? LIMIT 1');
        if (!$chk) {
            throw new Exception('Failed to verify invoice ownership: ' . $conn->error);
        }
        $chk->bind_param('ii', $invoice_id, $user_id);
        $chk->execute();
        $exists = $chk->get_result()->fetch_assoc();
        $chk->close();

        if (!$exists) {
            throw new Exception('Invoice not found or unauthorized');
        }
        // Otherwise: invoice exists, but values were identical (no actual change)
    }

    $stmt->close();

    if ($requestedValidation || $implicitDraftValidation || $devisIssuance) {
        $itemNumberStmt = $conn->prepare('UPDATE erp_invoice_items SET invoice = ?, invoice_date = ? WHERE invoice_id = ?');
        if (!$itemNumberStmt) {
            throw new Exception('Failed to synchronize invoice item numbering: ' . $conn->error);
        }
        $itemNumberStmt->bind_param('ssi', $assignedInvoiceNumber, $effectiveInvoiceDate, $invoice_id);
        $itemNumberStmt->execute();
        $itemNumberStmt->close();
        if ($requestedValidation || $implicitDraftValidation) {
            applyInvoiceStockMovements($conn, $invoice_id, $user_id);
            if (strtoupper((string)$invoiceRow['invoice_type']) === 'AVOIR' && (int)$invoiceRow['source_invoice_id'] > 0) {
                syncInvoiceSettlementState($conn, (int)$invoiceRow['source_invoice_id'], $user_id);
            }
        }
        captureInvoiceIssuanceSnapshot($conn, $user_id, $user_id, $invoice_id);
    }

    $auditAction = ($requestedValidation || $implicitDraftValidation || $devisIssuance)
        ? 'INVOICE.VALIDATED'
        : (($requestedStatus === 'CANCELLED') ? 'INVOICE.CANCELLED' : 'INVOICE.UPDATED');
    auditLog($conn, $user_id, $user_id, $auditAction, 'INVOICE', $invoice_id,
        $invoiceRow, ['invoice'=>$assignedInvoiceNumber,'changes'=>$data]);

    $conn->commit();

    jsonResponse([
        "success" => true,
        "id" => $invoice_id,
        "invoice" => $assignedInvoiceNumber,
        "message" => "Invoice updated successfully"
    ]);
} catch (Throwable $e) {
    if (isset($conn)) {
        try {
            $conn->rollback();
        } catch (Throwable $ignored) {
        }
    }
    jsonResponse([
        "success" => false,
        "message" => $e->getMessage()
    ], 400);
}
?>
