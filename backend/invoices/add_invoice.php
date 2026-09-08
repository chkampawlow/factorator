<?php
header('Content-Type: application/json');

require_once __DIR__ . '/../config/response.php';
require_once __DIR__ . '/../config/db.php';
require_once __DIR__ . '/../auth/auth_required.php';
require_once __DIR__ . '/../auth/role_helper.php';

require_once __DIR__ . '/workflow_schema.php';
require_once __DIR__ . '/document_number.php';
require_once __DIR__ . '/document_date_policy.php';
require_once __DIR__ . '/workflow_rules.php';
require_once __DIR__ . '/workflow_domain.php';
require_once __DIR__ . '/../taxes/tax_profile_service.php';
require_once __DIR__ . '/../config/actor_identity.php';


function normalizeInvoiceSourceFlow(array $data, int $salesOrderId, int $deliveryNoteId): string {
    $rawSourceFlow = isset($data['source_flow']) ? trim((string)$data['source_flow']) : '';
    if ($rawSourceFlow === '' && isset($data['sourceFlow'])) {
        $rawSourceFlow = trim((string)$data['sourceFlow']);
    }

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

function fodecRateForCurrency($currency) {
    $rates = [
        'TND' => 1.000,
        'EUR' => 1.000,
        'USD' => 1.000,
    ];

    $code = strtoupper(trim((string)$currency));
    return $rates[$code] ?? $rates['TND'];
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

    $client_id        = isset($data['client_id']) ? (int)$data['client_id'] : 0;
    $salespersonName  = trim((string)($data['salesperson_name'] ?? ''));
    $invoice_date     = isset($data['invoice_date']) ? trim((string)$data['invoice_date']) : '';
    $invoice_due_date = isset($data['invoice_due_date']) ? trim((string)$data['invoice_due_date']) : '';
    $status           = isset($data['status']) ? strtoupper(trim((string)$data['status'])) : 'UNPAID';
    $subtotal         = isset($data['subtotal']) ? (float)$data['subtotal'] : 0;
    $base_tva         = isset($data['base_tva']) ? (float)$data['base_tva'] : $subtotal;
    $montant_tva      = isset($data['montant_tva']) ? (float)$data['montant_tva'] : 0;
    $subtotal_ttc     = isset($data['subtotal_ttc']) ? (float)$data['subtotal_ttc'] : ($base_tva + $montant_tva);
    $timbre           = isset($data['timbre']) ? (float)$data['timbre'] : 1.0;
    $total            = isset($data['total']) ? (float)$data['total'] : 0;
    $currency         = isset($data['currency']) ? trim((string)$data['currency']) : 'TND';
    $exchangeRate     = decimalInput($data['exchange_rate'] ?? (strtoupper($currency)==='TND'?'1':''), 'Exchange rate', 8);
    $exchangeRateDate = trim((string)($data['exchange_rate_date'] ?? $invoice_date));
    $invoice_type     = isset($data['invoice_type']) ? trim((string)$data['invoice_type']) : 'FACTURE';
    $sales_order_id   = isset($data['sales_order_id']) ? (int)$data['sales_order_id'] : (isset($data['salesOrderId']) ? (int)$data['salesOrderId'] : 0);
    $delivery_note_id = isset($data['delivery_note_id']) ? (int)$data['delivery_note_id'] : (isset($data['deliveryNoteId']) ? (int)$data['deliveryNoteId'] : 0);
    $source_invoice_id = isset($data['source_invoice_id']) ? (int)$data['source_invoice_id'] : 0;
    $idempotencyKey=trim((string)($data['idempotency_key']??'')); if(strlen($idempotencyKey)>64)throw new Exception('Invalid idempotency key');
    $invoice_type = strtoupper($invoice_type);
    if (!in_array($invoice_type, ['FACTURE', 'DRAFT', 'DEVIS', 'AVOIR'], true)) {
        throw new Exception('Invalid invoice_type');
    }
    if ($status === 'OPEN') {
        $status = 'UNPAID';
    }
    if ($status === '') {
        $status = $invoice_type === 'DRAFT' ? 'DRAFT' : 'UNPAID';
    }
    $allowedStatuses = $invoice_type === 'DEVIS' ? workflowDevisStatuses() : workflowInvoiceDraftStatuses();
    if (!in_array($status, $allowedStatuses, true)) {
        throw new Exception('Invalid status');
    }
    if ($invoice_type === 'FACTURE' && $status === 'DRAFT') {
        // Flutter creates invoice headers in draft mode, then validates later.
        $invoice_type = 'DRAFT';
    }
    $source_flow = normalizeInvoiceSourceFlow($data, $sales_order_id, $delivery_note_id);
    $notes            = isset($data['notes']) ? trim((string)$data['notes']) : '';
    if (mb_strlen($salespersonName) > 191) throw new Exception('Salesperson name is too long');

    if ($client_id <= 0) {
        throw new Exception("Invalid client_id");
    }

    if ($invoice_date === '') {
        throw new Exception("invoice_date is required");
    }

    if ($invoice_due_date === '') {
        throw new Exception("invoice_due_date is required");
    }

    validateDocumentDates($invoice_date, $invoice_due_date);
    $currency=strtoupper($currency);if(!in_array($currency,['TND','EUR','USD'],true)||!preg_match('/^\d{4}-\d{2}-\d{2}$/',$exchangeRateDate)||bccomp($exchangeRate,'0',8)<=0||($currency==='TND'&&bccomp($exchangeRate,'1',8)!==0))throw new Exception('Invalid currency or exchange rate');

    $conn = db();
    requireInvoiceDocumentPermission($conn, $user_id, $invoice_type, 'create');
    if ($salespersonName === '') {
        $salespersonName = actorCommercialName($conn, authActorId($authUser));
    }
    if ($invoice_type === 'AVOIR') {
        requirePermission($conn, $user_id, 'invoices.credit');
    }
    $conn->begin_transaction();
    if($idempotencyKey!==''){$repeat=$conn->prepare('SELECT id,invoice FROM erp_invoices WHERE user_id=? AND idempotency_key=? LIMIT 1');$repeat->bind_param('is',$user_id,$idempotencyKey);$repeat->execute();$existingRepeat=$repeat->get_result()->fetch_assoc();$repeat->close();if($existingRepeat){$conn->rollback();jsonResponse(['success'=>true,'id'=>(int)$existingRepeat['id'],'invoice'=>$existingRepeat['invoice'],'replayed'=>true]);}}
    if ($invoice_type !== 'DEVIS') {
        enforceInvoiceDatePolicy($conn, $user_id, $invoice_date);
    }
    ensureInvoiceWorkflowSchema($conn);
    ensureTaxProfileSchema($conn);
    $transformationStatus = isset($data['transformation_status']) ? strtoupper(trim((string)$data['transformation_status'])) : 'NOT_TRANSFORMED';
    if (!in_array($transformationStatus, workflowTransformationStatuses(), true)) {
        throw new Exception('Invalid transformation_status');
    }

    $userFodec = 0;
    $userStmt = $conn->prepare("
        SELECT IFNULL(fodec, 0) AS fodec
        FROM users
        WHERE id = ?
        LIMIT 1
    ");
    if (!$userStmt) {
        throw new Exception("Failed to prepare user FODEC lookup: " . $conn->error);
    }
    $userStmt->bind_param("i", $user_id);
    $userStmt->execute();
    $userRow = $userStmt->get_result()->fetch_assoc();
    $userStmt->close();
    if ($userRow) {
        $userFodec = ((int)$userRow['fodec']) === 1 ? 1 : 0;
    }

    // Header creation carries no authoritative financial totals. Items are priced by tax profile and recomputed later.
    $userFodec=0;$fodecRate=0.0;$subtotal=0.0;$base_tva=0.0;$montant_tva=0.0;$subtotal_ttc=0.0;$total=$timbre;

    $checkClient = $conn->prepare("
        SELECT id, name
        FROM clients
        WHERE id = ? AND user_id = ?
        LIMIT 1
    ");
    $checkClient->bind_param("ii", $client_id, $user_id);
    $checkClient->execute();
    $clientRow = $checkClient->get_result()->fetch_assoc();
    $checkClient->close();

    if (!$clientRow) {
        throw new Exception("Client not found or not allowed");
    }

    if ($sales_order_id > 0) {
        $orderStmt = $conn->prepare("
            SELECT id, client_id, status
            FROM erp_sales_orders
            WHERE id = ? AND user_id = ?
            LIMIT 1
        ");
        if (!$orderStmt) {
            throw new Exception("Failed to prepare sales order lookup: " . $conn->error);
        }
        $orderStmt->bind_param("ii", $sales_order_id, $user_id);
        $orderStmt->execute();
        $orderRow = $orderStmt->get_result()->fetch_assoc();
        $orderStmt->close();

        if (!$orderRow) {
            throw new Exception("Sales order not found or not allowed");
        }
    }

    if ($delivery_note_id > 0) {
        $deliveryStmt = $conn->prepare("
            SELECT id, client_id, status
            FROM erp_delivery_notes
            WHERE id = ? AND user_id = ?
            LIMIT 1
        ");
        if (!$deliveryStmt) {
            throw new Exception("Failed to prepare delivery note lookup: " . $conn->error);
        }
        $deliveryStmt->bind_param("ii", $delivery_note_id, $user_id);
        $deliveryStmt->execute();
        $deliveryRow = $deliveryStmt->get_result()->fetch_assoc();
        $deliveryStmt->close();

        if (!$deliveryRow || (int)$deliveryRow['client_id'] !== $client_id || (string)$deliveryRow['status'] !== 'DELIVERED') {
            throw new Exception("Invoice creation requires a delivered delivery note for the same client");
        }
    }

    if ($source_invoice_id > 0) {
        $sourceStmt = $conn->prepare("SELECT id,custom_code,invoice_type,IFNULL(is_validated,0) is_validated FROM erp_invoices WHERE id=? AND user_id=? LIMIT 1");
        $sourceStmt->bind_param('ii',$source_invoice_id,$user_id); $sourceStmt->execute(); $sourceRow=$sourceStmt->get_result()->fetch_assoc(); $sourceStmt->close();
        if(!$sourceRow || strtoupper((string)$sourceRow['invoice_type'])!=='FACTURE' || (int)$sourceRow['is_validated']!==1 || (int)$sourceRow['custom_code']!==$client_id) {
            throw new Exception('Avoir source invoice is invalid or belongs to another client');
        }
    }

    $invoiceNumber = 'DRAFT-' . strtoupper(bin2hex(random_bytes(8)));
    $custom_code = (string)$client_id;

    $sql = "
        INSERT INTO erp_invoices (
            invoice,
            custom_code,
            salesperson_name,
            sales_order_id,
            delivery_note_id,
            source_invoice_id,
            source_flow,
            invoice_date,
            invoice_due_date,
            subtotal,
            base_tva,
            montant_tva,
            subtotal_ttc,
            shipping,
            discount,
            vat,
            timbre,
            total,
            notes,
            invoice_type,
            status,
            transformation_status,
            is_validated,
            type_doc,
            user_id
            ,idempotency_key
        ) VALUES (?, ?, NULLIF(?, ''), NULLIF(?, 0), NULLIF(?, 0), NULLIF(?, 0), ?, ?, ?, ?, ?, ?, ?, 0, 0, 0, ?, ?, ?, ?, ?, ?, 0, 'F', ?,NULLIF(?,''))
    ";

    $stmt = $conn->prepare($sql);

    $stmt->bind_param(
        "sssiiisssddddddssssis",
        $invoiceNumber,
        $custom_code,
        $salespersonName,
        $sales_order_id,
        $delivery_note_id,
        $source_invoice_id,
        $source_flow,
        $invoice_date,
        $invoice_due_date,
        $subtotal,
        $base_tva,
        $montant_tva,
        $subtotal_ttc,
        $timbre,
        $total,
        $notes,
        $invoice_type,
        $status,
        $transformationStatus,
        $user_id
        ,$idempotencyKey
    );

    $stmt->execute();
    $invoiceId = $stmt->insert_id;
    $stmt->close();
    $currencyStmt=$conn->prepare('UPDATE erp_invoices SET currency=?,exchange_rate=?,exchange_rate_date=?,subtotal_tnd=0,tax_total_tnd=0,total_tnd=? WHERE id=? AND user_id=?');
    $timbreTnd=money3(bcmul((string)$timbre,$exchangeRate,8));$currencyStmt->bind_param('sdsdii',$currency,$exchangeRate,$exchangeRateDate,$timbreTnd,$invoiceId,$user_id);$currencyStmt->execute();$currencyStmt->close();
    $conn->commit();

    jsonResponse([
        "success" => true,
        "id" => $invoiceId,
        "invoice" => $invoiceNumber,
        "client_id" => $client_id,
        "sales_order_id" => $sales_order_id > 0 ? $sales_order_id : null,
        "delivery_note_id" => $delivery_note_id > 0 ? $delivery_note_id : null,
        "source_flow" => $source_flow,
        "fodec" => $userFodec,
        "fodec_rate" => $fodecRate,
        "base_tva" => $base_tva,
        "timbre" => $timbre,
        "user_id" => $user_id,
        "message" => "Invoice created successfully"
    ]);
} catch (Throwable $e) {
    if(isset($conn)){try{$conn->rollback();}catch(Throwable $ignored){}}
    jsonResponse([
        "success" => false,
        "message" => $e->getMessage()
    ], 400);
}
?>
