<?php

header('Content-Type: application/json');

require_once __DIR__ . '/../config/response.php';
require_once __DIR__ . '/../config/db.php';
require_once __DIR__ . '/../config/validator.php';
require_once __DIR__ . '/../auth/auth_required.php';
require_once __DIR__ . '/../auth/role_helper.php';




try {
    if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
        jsonResponse([
            'success' => false,
            'message' => 'Method not allowed. Use POST.'
        ], 405);
        exit;
    }

    $authUser = requireAuth();
    $user_id = (int)$authUser->id;

    $data = requireJsonBody();

    $invoiceId = getRequiredInt($data, 'id', 'Invoice ID');

    // Status is REQUIRED for this endpoint
    $status = strtoupper(getRequiredString($data, 'status', 'Status'));
    validateEnum($status, ['UNPAID', 'PAID', 'AVOIR', 'CANCELLED'], 'Status');

    $conn = db();
    requirePermission($conn, $user_id, 'payments.record');

    // Verify invoice belongs to user
    $check = $conn->prepare("
        SELECT id, invoice_type, IFNULL(is_validated, 0) AS is_validated
        FROM erp_invoices
        WHERE id = ? AND user_id = ?
        LIMIT 1
    ");

    if (!$check) {
        throw new Exception('Failed to prepare invoice check: ' . $conn->error);
    }

    $check->bind_param('ii', $invoiceId, $user_id);
    $check->execute();
    $invoice = $check->get_result()->fetch_assoc();
    $check->close();

    if (!$invoice) {
        throw new Exception('Invoice not found or unauthorized');
    }

    if (
        (int)$invoice['is_validated'] !== 1
        || in_array(strtoupper((string)$invoice['invoice_type']), ['DEVIS', 'AVOIR'], true)
    ) {
        throw new Exception('Only validated invoices can change payment status');
    }

    throw new Exception('Invoice payment status is calculated from the payment ledger and cannot be changed manually.');

} catch (Throwable $e) {
    jsonResponse([
        'success' => false,
        'message' => $e->getMessage()
    ], 400);
}
