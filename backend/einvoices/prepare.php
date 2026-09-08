<?php

header('Content-Type: application/json');
require_once __DIR__ . '/../config/response.php';
require_once __DIR__ . '/../config/db.php';
require_once __DIR__ . '/../auth/auth_required.php';
require_once __DIR__ . '/../auth/role_helper.php';
require_once __DIR__ . '/service.php';

try {
    if ($_SERVER['REQUEST_METHOD'] !== 'POST') jsonResponse(['success' => false, 'message' => 'Method not allowed'], 405);
    $userId = (int)requireAuth()->id;
    $data = json_decode(file_get_contents('php://input'), true) ?: [];
    $invoiceId = (int)($data['invoice_id'] ?? 0);
    $conn = db();
    requirePermission($conn, $userId, 'invoices.send');
    $conn->begin_transaction();
    $invoice = requireEInvoice($conn, $invoiceId, $userId);
    $issuanceSnapshot = $invoice['_issuance_snapshot'] ?? [];
    $snapshotDocument = $issuanceSnapshot['document'] ?? [];
    $items = array_map(static fn(array $item): array => [
        'product_code' => (string)($item['code'] ?? ''),
        'product' => (string)($item['description'] ?? ''),
        'qty' => (string)($item['qty'] ?? '0'),
        'price' => (string)($item['price'] ?? '0'),
        'discount' => (string)($item['discount'] ?? '0'),
        'tva_rate' => (string)($item['tva_rate'] ?? '0'),
        'subtotal' => (string)($item['subtotal'] ?? '0'),
        'montant_tva' => (string)($item['tax_total'] ?? '0'),
        'subtotalTTC' => (string)($item['total'] ?? '0'),
    ], $issuanceSnapshot['items'] ?? []);
    if (!$items) throw new Exception('Electronic invoice requires at least one line');
    $payload = [
        'format' => 'TTN_PREPARATION_V1',
        'document' => [
            'number' => $snapshotDocument['number'],
            'issue_date' => $snapshotDocument['issue_date'],
            'due_date' => $snapshotDocument['due_date'],
            'currency' => $snapshotDocument['currency'],
        ],
        'seller' => [
            'name' => $invoice['organization_name'],
            'fiscal_id' => $invoice['seller_fiscal_id'],
            'address' => $invoice['seller_address'],
        ],
        'buyer' => [
            'name' => $invoice['client_name'],
            'fiscal_id' => $invoice['client_fiscal_id'],
            'cin' => $invoice['client_cin'],
            'address' => $invoice['client_address'],
        ],
        'lines' => $items,
        'totals' => [
            'subtotal' => (float)$snapshotDocument['subtotal'],
            'tax_base' => (float)$snapshotDocument['tax_base'],
            'vat' => (float)$snapshotDocument['tax_total'],
            'total_ttc' => (float)$snapshotDocument['total'],
        ],
    ];
    $json = canonicalEInvoiceJson($payload);
    $hash = hash('sha256', $json);
    $stmt = $conn->prepare("INSERT INTO erp_einvoice_outbox(invoice_id,user_id,format_version,payload_json,payload_sha256,status)VALUES(?,?,'TTN_PREPARATION_V1',?,?,'SIGNATURE_REQUIRED') ON DUPLICATE KEY UPDATE invoice_id=invoice_id");
    $stmt->bind_param('iiss', $invoiceId, $userId, $json, $hash);
    $stmt->execute();
    $outboxId = (int)$stmt->insert_id;
    $stmt->close();
    if ($outboxId === 0) {
        $stmt = $conn->prepare('SELECT id,payload_sha256 FROM erp_einvoice_outbox WHERE invoice_id=? AND user_id=?');
        $stmt->bind_param('ii', $invoiceId, $userId);
        $stmt->execute();
        $existing = $stmt->get_result()->fetch_assoc();
        $stmt->close();
        if (!$existing || !hash_equals((string)$existing['payload_sha256'], $hash)) {
            throw new Exception('An immutable electronic invoice archive already exists with different content');
        }
        $outboxId = (int)$existing['id'];
    }
    $conn->commit();
    jsonResponse([
        'success' => true,
        'id' => $outboxId,
        'payload_sha256' => $hash,
        'status' => 'SIGNATURE_REQUIRED',
        'submission_enabled' => false,
        'message' => 'Structured payload archived. TTN signing credentials are required before submission.',
    ]);
} catch (Throwable $e) {
    if (isset($conn)) {
        try { $conn->rollback(); } catch (Throwable $ignored) {}
    }
    jsonResponse(['success' => false, 'message' => $e->getMessage()], 400);
}
