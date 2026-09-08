<?php
header('Content-Type: application/json');

require_once __DIR__ . '/../config/response.php';
require_once __DIR__ . '/../config/db.php';
require_once __DIR__ . '/../auth/auth_required.php';
require_once __DIR__ . '/../auth/role_helper.php';




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

    $invoice_id = isset($data['id']) ? (int)$data['id'] : 0;

    if ($invoice_id <= 0) {
        throw new Exception("Invalid invoice id");
    }

    $conn = db();
    $conn->begin_transaction();

    $check = $conn->prepare("
        SELECT id, invoice, invoice_type, IFNULL(is_validated, 0) AS is_validated
        FROM erp_invoices
        WHERE id = ? AND user_id = ?
        LIMIT 1
        FOR UPDATE
    ");
    $check->bind_param("ii", $invoice_id, $user_id);
    $check->execute();
    $invoiceRow = $check->get_result()->fetch_assoc();
    $check->close();

    if (!$invoiceRow) {
        throw new Exception("Invoice not found or not allowed");
    }

    $invoiceType = strtoupper(trim((string)($invoiceRow['invoice_type'] ?? 'FACTURE')));
    requireInvoiceDocumentPermission($conn, $user_id, $invoiceType, 'delete');
    if ((int)$invoiceRow['is_validated'] === 1) {
        throw new Exception("Issued documents cannot be deleted; create a credit note or replacement document instead");
    }

    // Delete invoice items first if they depend on invoice_id
    $deleteItems = $conn->prepare("
        DELETE FROM erp_invoice_items
        WHERE invoice_id = ?
    ");
    $deleteItems->bind_param("i", $invoice_id);
    $deleteItems->execute();
    $deleteItems->close();

    // Delete invoice
    $deleteInvoice = $conn->prepare("
        DELETE FROM erp_invoices
        WHERE id = ? AND user_id = ? AND IFNULL(is_validated, 0) = 0
    ");
    $deleteInvoice->bind_param("ii", $invoice_id, $user_id);
    $deleteInvoice->execute();
    $affected = $deleteInvoice->affected_rows;
    $deleteInvoice->close();

    if ($affected <= 0) {
        throw new Exception("Failed to delete invoice");
    }

    $conn->commit();

    jsonResponse([
        "success" => true,
        "id" => $invoice_id,
        "invoice" => $invoiceRow['invoice'],
        "message" => "Invoice deleted successfully"
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
    ], resourceExceptionStatus($e));
}
?>
