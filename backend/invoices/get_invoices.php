<?php
header('Content-Type: application/json');

require_once __DIR__ . '/../config/response.php';
require_once __DIR__ . '/../config/db.php';
require_once __DIR__ . '/../auth/auth_required.php';
require_once __DIR__ . '/../auth/role_helper.php';
require_once __DIR__ . '/../config/field_projection.php';

function invoiceColumn(mysqli $conn, string $column, string $fallback): string
{
    $escaped = $conn->real_escape_string($column);
    $result = $conn->query("SHOW COLUMNS FROM erp_invoices LIKE '{$escaped}'");
    $exists = $result->num_rows > 0;
    $result->close();
    return $exists ? "ei.`{$column}`" : $fallback;
}

function invoiceItemColumnExists(mysqli $conn, string $column): bool
{
    $escaped = $conn->real_escape_string($column);
    $result = $conn->query("SHOW COLUMNS FROM erp_invoice_items LIKE '{$escaped}'");
    $exists = $result->num_rows > 0;
    $result->close();
    return $exists;
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

    $conn = db();$visibleDocumentTypes=requireAnyInvoiceDocumentView($conn,$user_id);

    // Listing invoices must remain read-only. Optional expressions keep this
    // endpoint usable while a deployment is applying newer accounting schema.
    $salesOrder = invoiceColumn($conn, 'sales_order_id', 'NULL');
    $deliveryNote = invoiceColumn($conn, 'delivery_note_id', 'NULL');
    $sourceFlow = invoiceColumn($conn, 'source_flow', "'DIRECT'");
    $salesperson = invoiceColumn($conn, 'salesperson_name', "''");
    $currency = invoiceColumn($conn, 'currency', "'TND'");
    $exchangeRate = invoiceColumn($conn, 'exchange_rate', '1');
    $exchangeRateDate = invoiceColumn($conn, 'exchange_rate_date', 'NULL');
    $subtotalTnd = invoiceColumn($conn, 'subtotal_tnd', 'ei.subtotal');
    $taxTotalTnd = invoiceColumn($conn, 'tax_total_tnd', 'ei.montant_tva');
    $totalTnd = invoiceColumn($conn, 'total_tnd', 'ei.total');
    $transformationStatus = invoiceColumn($conn, 'transformation_status', "'NOT_TRANSFORMED'");
    $isValidated = invoiceColumn($conn, 'is_validated', "IF(UPPER(IFNULL(ei.status,''))='DRAFT',0,1)");
    $fodecRate = invoiceItemColumnExists($conn, 'fodec_rate')
        ? 'IFNULL((SELECT MAX(fodec_rate) FROM erp_invoice_items WHERE invoice_id=ei.id),0)'
        : '0';

    $stmt = $conn->prepare("
        SELECT 
            ei.id,
            ei.invoice,
            COALESCE(NULLIF(ei.custom_email, ''), c.email, '') AS custom_email,
            ei.custom_code,
            {$salesOrder} AS sales_order_id,
            {$deliveryNote} AS delivery_note_id,
            {$sourceFlow} AS source_flow,
            COALESCE(c.name, '') AS client_name,
            COALESCE(c.name, '') AS custom_name,
            COALESCE(c.name, '') AS customer_name,
            COALESCE(c.email, '') AS client_email,
            ei.invoice_date,
            {$salesperson} AS salesperson_name,
            ei.invoice_due_date,
            ei.subtotal,
            {$fodecRate} AS fodec_rate,
            IF({$fodecRate}>0,1,0) AS fodec,
            IF({$fodecRate}>0,1,0) AS is_fodec,
            ei.base_tva,
            ei.montant_tva,
            ei.subtotal_ttc,
            ei.shipping,
            ei.discount,
            ei.vat,
            ei.total,
            {$currency} AS currency,
            {$exchangeRate} AS exchange_rate,
            {$exchangeRateDate} AS exchange_rate_date,
            {$subtotalTnd} AS subtotal_tnd,
            {$taxTotalTnd} AS tax_total_tnd,
            {$totalTnd} AS total_tnd,
            ei.notes,
            ei.invoice_type,
            ei.status AS stored_status,
            ei.status AS status,
            {$transformationStatus} AS transformation_status,
            {$isValidated} AS is_validated,
            ei.payment_method,
            ei.timbre,
            ei.date_ajout
        FROM erp_invoices ei
        INNER JOIN users u
            ON u.id = ei.user_id
        LEFT JOIN clients c
            ON c.id = CAST(ei.custom_code AS UNSIGNED)
           AND c.user_id = ei.user_id
        WHERE ei.user_id = ? AND UPPER(ei.invoice_type) IN (" . implode(',', array_fill(0, count($visibleDocumentTypes), '?')) . ")
        ORDER BY ei.id DESC
    ");

    $readTypes='i'.str_repeat('s',count($visibleDocumentTypes));
    $readArgs=[$user_id,...$visibleDocumentTypes];
    $stmt->bind_param($readTypes,...$readArgs);
    $stmt->execute();

    $result = $stmt->get_result();
    $rows = [];

    while ($row = $result->fetch_assoc()) {
        $rows[] = $row;
    }

    $stmt->close();
    $role = currentUserRole($conn, $user_id);
    $rows = projectRows($rows, static fn(array $row): array => projectInvoiceFields($row, $role));

    jsonResponse([
        "success" => true,
        "data" => $rows
    ]);
} catch (Throwable $e) {
    structuredLog('ERROR', 'INVOICES.LIST_FAILED', [
        'message' => $e->getMessage(),
        'stage' => 'get_invoices',
    ]);
    jsonResponse([
        "success" => false,
        "message" => "Could not load invoices.",
        "error_code" => "INVOICE_LIST_FAILED"
    ], 500);
}
?>
