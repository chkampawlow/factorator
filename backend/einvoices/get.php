<?php

header('Content-Type: application/json');
require_once __DIR__ . '/../config/response.php';
require_once __DIR__ . '/../config/db.php';
require_once __DIR__ . '/../auth/auth_required.php';
require_once __DIR__ . '/../auth/role_helper.php';

try {
    $userId = (int)requireAuth()->id;
    $invoiceId = (int)($_GET['invoice_id'] ?? 0);
    $conn = db();
    requirePermission($conn, $userId, 'invoices.send');
    $owner = $conn->prepare("SELECT id FROM erp_invoices WHERE id=? AND user_id=? AND UPPER(invoice_type)='FACTURE' LIMIT 1");
    $owner->bind_param('ii', $invoiceId, $userId);
    $owner->execute();
    $owned = (bool)$owner->get_result()->fetch_assoc();
    $owner->close();
    if (!$owned) throw new Exception('Invoice not found or unauthorized');
    $stmt = $conn->prepare('SELECT id,invoice_id,format_version,payload_sha256,status,certificate_thumbprint,provider_identifier,attempt_count,last_attempt_at,last_error_code,last_error_message,created_at,updated_at FROM erp_einvoice_outbox WHERE invoice_id=? AND user_id=?');
    $stmt->bind_param('ii', $invoiceId, $userId);
    $stmt->execute();
    $row = $stmt->get_result()->fetch_assoc();
    $stmt->close();
    jsonResponse(['success' => true, 'data' => $row ?: null, 'submission_enabled' => false]);
} catch (Throwable $e) {
    jsonResponse(['success' => false, 'message' => $e->getMessage()], resourceExceptionStatus($e));
}
