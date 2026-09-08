<?php
header('Content-Type: application/json');

require_once __DIR__ . '/../config/response.php';
require_once __DIR__ . '/../config/db.php';
require_once __DIR__ . '/../config/idempotency.php';
require_once __DIR__ . '/../config/audit.php';
require_once __DIR__ . '/../auth/auth_required.php';
require_once __DIR__ . '/../auth/role_helper.php';
require_once __DIR__ . '/service.php';

try {
    if ($_SERVER['REQUEST_METHOD'] !== 'POST') jsonResponse(['success' => false, 'message' => 'Method not allowed'], 405);
    $auth = requireAuth();
    $userId = authTenantId($auth);
    $actorId = authActorId($auth);
    $conn = db();
    requirePermission($conn, $userId, 'payments.record');

    $invoiceId = (int)($_POST['invoice_id'] ?? 0);
    $amount = round((float)($_POST['amount'] ?? 0), 3);
    $date = trim((string)($_POST['payment_date'] ?? ''));
    $method = strtoupper(trim((string)($_POST['method'] ?? '')));
    $account = trim((string)($_POST['account_name'] ?? ''));
    $reference = trim((string)($_POST['reference_number'] ?? ''));
    $rateInput = trim((string)($_POST['exchange_rate'] ?? ''));
    $key = requiredIdempotencyKey();

    if ($amount <= 0) throw new Exception('Payment amount must be greater than zero');
    if (!DateTimeImmutable::createFromFormat('!Y-m-d', $date)) throw new Exception('Invalid payment date');
    if (!in_array($method, ['CASH', 'CHEQUE', 'BANK_TRANSFER', 'CARD', 'DRAFT', 'OTHER'], true)) throw new Exception('Invalid payment method');
    if (in_array($method, ['CHEQUE', 'BANK_TRANSFER', 'CARD', 'DRAFT'], true) && $reference === '') throw new Exception('A payment reference is required for this method');

    $conn->begin_transaction();
    $invoice = requireSettlementInvoice($conn, $invoiceId, $userId, true);
    $exchange = settlementExchangeValues($invoice, $amount, $rateInput, $date);

    $hash = idempotencyRequestHash([
        'invoice_id' => $invoiceId,
        'amount' => $amount,
        'payment_date' => $date,
        'method' => $method,
        'account_name' => $account,
        'reference_number' => $reference,
        'exchange_rate' => $exchange['exchange_rate'],
        'exchange_rate_date' => $exchange['exchange_rate_date'],
    ]);

    $replayedId = claimIdempotencyKey($conn, $userId, 'invoice.payment.add', $key, $hash);
    if ($replayedId !== null) {
        $summary = settlementSummary($conn, $invoiceId, $userId);
        $conn->commit();
        jsonResponse(['success' => true, 'id' => $replayedId, 'summary' => $summary, 'replayed' => true]);
    }

    $before = settlementSummary($conn, $invoiceId, $userId);
    if ($amount > (float)$before['remaining_balance'] + 0.0005) throw new Exception('Payment exceeds the outstanding balance');

    [$path, $name, $mime] = storeSettlementUpload('proof', $userId);
    $stmt = $conn->prepare('INSERT INTO erp_invoice_payments(invoice_id,user_id,amount,exchange_rate,exchange_rate_date,amount_tnd,payment_date,method,account_name,reference_number,proof_path,proof_name,proof_mime,recorded_by) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?)');
    $stmt->bind_param('iiddsdsssssssi', $invoiceId, $userId, $amount, $exchange['exchange_rate'], $exchange['exchange_rate_date'], $exchange['amount_tnd'], $date, $method, $account, $reference, $path, $name, $mime, $actorId);
    $stmt->execute();
    $paymentId = (int)$stmt->insert_id;
    $stmt->close();

    $summary = syncInvoiceSettlementState($conn, $invoiceId, $userId);
    auditLog($conn, $userId, $actorId, 'PAYMENT.POSTED', 'INVOICE_PAYMENT', $paymentId,
        ['invoice_id' => $invoiceId, 'settlement' => $before],
        ['invoice_id' => $invoiceId, 'amount' => $amount, 'method' => $method,
         'currency' => $exchange['currency'], 'exchange_rate' => $exchange['exchange_rate'],
         'amount_tnd' => $exchange['amount_tnd'], 'reference_number' => $reference, 'settlement' => $summary]);
    completeIdempotencyKey($conn, $userId, 'invoice.payment.add', $key, $paymentId);
    $conn->commit();
    jsonResponse(['success' => true, 'id' => $paymentId, 'summary' => $summary, 'currency' => $exchange['currency'], 'exchange_rate' => $exchange['exchange_rate'], 'amount_tnd' => $exchange['amount_tnd'], 'replayed' => false]);
} catch (Throwable $e) {
    if (isset($conn)) {
        try { $conn->rollback(); } catch (Throwable $ignored) {}
    }
    if (!empty($path) && is_file($path)) unlink($path);
    jsonResponse(['success' => false, 'message' => $e->getMessage()], 400);
}
