<?php
header('Content-Type: application/json');

require_once __DIR__ . '/../config/response.php';
require_once __DIR__ . '/../config/db.php';
require_once __DIR__ . '/../auth/auth_required.php';
require_once __DIR__ . '/../auth/role_helper.php';
require_once __DIR__ . '/../config/field_projection.php';

require_once __DIR__ . '/workflow_schema.php';


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
    if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
        jsonResponse([
            "success" => false,
            "message" => "Method not allowed. Use GET."
        ], 405);
        exit;
    }

    $authUser = requireAuth();
    $user_id = (int)$authUser->id;

    $invoice_id = isset($_GET['id']) ? (int)$_GET['id'] : 0;
    $currency = isset($_GET['currency']) ? trim((string)$_GET['currency']) : 'TND';

    if ($invoice_id <= 0) {
        throw new Exception("Invalid invoice id");
    }

    $conn = db();requireAnyInvoiceDocumentView($conn, $user_id);
    ensureInvoiceWorkflowSchema($conn);

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
    $userFodecRate = $userFodec === 1 ? fodecRateForCurrency($currency) : 0.0;

    $fillTotals = $conn->prepare("
        UPDATE erp_invoices ei
        LEFT JOIN (
            SELECT
                invoice_id,
                COALESCE(SUM(subtotal), 0) AS ht,
                COALESCE(SUM(subtotal * IFNULL(tva_rate, 0) / 100), 0) AS tva_before_fodec
            FROM erp_invoice_items
            GROUP BY invoice_id
        ) items ON items.invoice_id = ei.id
        SET
            ei.subtotal = ROUND(COALESCE(items.ht, 0), 3),
            ei.base_tva = CASE
                WHEN ? > 0
                THEN ROUND(COALESCE(items.ht, 0) * (1 + ? / 100), 3)
                ELSE ROUND(COALESCE(items.ht, 0), 3)
            END,
            ei.montant_tva = ROUND(COALESCE(items.tva_before_fodec, 0) * (1 + ? / 100), 3),
            ei.subtotal_ttc = ROUND(
                (COALESCE(items.ht, 0) + COALESCE(items.tva_before_fodec, 0)) *
                (1 + ? / 100),
                3
            ),
            ei.total = ROUND(
                (
                    (COALESCE(items.ht, 0) + COALESCE(items.tva_before_fodec, 0)) *
                    (1 + ? / 100)
                ) + (
                    CASE
                        WHEN UPPER(IFNULL(ei.invoice_type, 'FACTURE')) = 'AVOIR'
                        THEN -IFNULL(ei.timbre, 0)
                        ELSE IFNULL(ei.timbre, 0)
                    END
                ),
                3
            )
        WHERE ei.id = ? AND ei.user_id = ? AND IFNULL(ei.is_validated, 0) = 0 AND 1 = 0
        LIMIT 1
    ");
    if (!$fillTotals) {
        throw new Exception("Failed to prepare invoice totals update: " . $conn->error);
    }
    $fillTotals->bind_param(
        "dddddii",
        $userFodecRate,
        $userFodecRate,
        $userFodecRate,
        $userFodecRate,
        $userFodecRate,
        $invoice_id,
        $user_id
    );
    $fillTotals->execute();
    if ($fillTotals->errno) {
        throw new Exception("Failed to fill invoice totals: " . $fillTotals->error);
    }
    $fillTotals->close();

    $stmt = $conn->prepare("
        SELECT
            ei.id,
            ei.invoice,
            COALESCE(NULLIF(ei.custom_email, ''), c.email, '') AS custom_email,
            ei.custom_code,
            ei.sales_order_id,
            ei.delivery_note_id,
            ei.source_invoice_id,
            IFNULL(ei.source_flow, 'DIRECT') AS source_flow,
            COALESCE(c.name, '') AS client_name,
            COALESCE(c.name, '') AS custom_name,
            COALESCE(c.name, '') AS customer_name,
            COALESCE(c.email, '') AS client_email,
            COALESCE(c.address, '') AS client_address,
            COALESCE(c.phone, '') AS client_phone,
            COALESCE(c.fiscalId, '') AS client_fiscal_id,
            COALESCE(c.cin, '') AS client_cin,
            COALESCE(CASE WHEN c.type='person' THEN 'individual' ELSE c.type END, '') AS client_type,
            ei.invoice_date,
            ei.salesperson_name,
            ei.invoice_due_date,
            ei.subtotal,
            IFNULL((SELECT MAX(fodec_rate) FROM erp_invoice_items WHERE invoice_id=ei.id),0) AS fodec_rate,
            IF(EXISTS(SELECT 1 FROM erp_invoice_items WHERE invoice_id=ei.id AND fodec_rate>0),1,0) AS fodec,
            IF(EXISTS(SELECT 1 FROM erp_invoice_items WHERE invoice_id=ei.id AND fodec_rate>0),1,0) AS is_fodec,
            ei.base_tva,
            ei.montant_tva,
            ei.subtotal_ttc,
            IFNULL(ei.timbre, 0) AS timbre,
            IFNULL(ei.payment_method, '') AS payment_method,
            ei.total,
            ei.currency,ei.exchange_rate,ei.exchange_rate_date,ei.subtotal_tnd,ei.tax_total_tnd,ei.total_tnd,
            ei.notes,
            ei.invoice_type,
            ei.status,
            IFNULL(ei.transformation_status, 'NOT_TRANSFORMED') AS transformation_status,
            IFNULL(ei.is_validated, 0) AS is_validated,
            ei.type_doc,
            ei.user_id
        FROM erp_invoices ei
        LEFT JOIN clients c
            ON c.id = CAST(ei.custom_code AS UNSIGNED)
           AND c.user_id = ei.user_id
        WHERE ei.id = ? AND ei.user_id = ?
        LIMIT 1
    ");
    $stmt->bind_param("ii", $invoice_id, $user_id);
    $stmt->execute();

    $result = $stmt->get_result();
    $row = $result->fetch_assoc();
    $stmt->close();

    if (!$row) {
        throw new Exception("Invoice not found or not allowed");
    }
    requireInvoiceDocumentPermission($conn, $user_id, $row['invoice_type'] ?? 'FACTURE', 'view');
    $row = projectInvoiceFields($row, currentUserRole($conn, $user_id));

    jsonResponse([
        "success" => true,
        "invoice" => $row
    ]);
} catch (Throwable $e) {
    jsonResponse([
        "success" => false,
        "message" => $e->getMessage()
    ], resourceExceptionStatus($e));
}
?>
