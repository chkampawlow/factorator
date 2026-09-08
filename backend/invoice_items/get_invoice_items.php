<?php
header('Content-Type: application/json');

require_once __DIR__ . '/../config/response.php';
require_once __DIR__ . '/../config/db.php';
require_once __DIR__ . '/../auth/auth_required.php';
require_once __DIR__ . '/../auth/role_helper.php';


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

    $invoice_id = isset($_GET['invoice_id']) ? (int)$_GET['invoice_id'] : 0;

    if ($invoice_id <= 0) {
        throw new Exception("Invalid invoice_id");
    }

    $conn = db();

    $check = $conn->prepare("
        SELECT id, invoice_type
        FROM erp_invoices
        WHERE id = ? AND user_id = ?
        LIMIT 1
    ");
    $check->bind_param("ii", $invoice_id, $user_id);
    $check->execute();
    $invoiceRow = $check->get_result()->fetch_assoc();
    $check->close();

    if (!$invoiceRow) {
        throw new Exception("Invoice not found or not allowed");
    }
    requireInvoiceDocumentPermission($conn, $user_id, $invoiceRow['invoice_type'] ?? 'FACTURE', 'view');

    $stmt = $conn->prepare("
        SELECT 
            id,
            invoice_id,
            invoice,
            product_id,
            product_code,
            product,
            qty,
            tva_rate,
            montant_tva,
            price,
            discount,
            subtotal,
            subtotalTTC,
            invoice_date
        FROM erp_invoice_items
        WHERE invoice_id = ?
        ORDER BY id DESC
    ");
    $stmt->bind_param("i", $invoice_id);
    $stmt->execute();

    $result = $stmt->get_result();
    $rows = [];

    while ($row = $result->fetch_assoc()) {
        $rows[] = $row;
    }

    $stmt->close();

    jsonResponse([
        "success" => true,
        "data" => $rows
    ]);
} catch (Throwable $e) {
    jsonResponse([
        "success" => false,
        "message" => $e->getMessage()
    ], resourceExceptionStatus($e));
}
?>
