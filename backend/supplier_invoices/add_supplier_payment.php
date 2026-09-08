<?php
header('Content-Type: application/json');

require_once __DIR__ . '/../config/response.php';
require_once __DIR__ . '/../config/db.php';
require_once __DIR__ . '/../config/idempotency.php';
require_once __DIR__ . '/../config/audit.php';
require_once __DIR__ . '/../auth/auth_required.php';
require_once __DIR__ . '/../auth/role_helper.php';
require_once __DIR__ . '/../invoice_settlements/service.php';

try {
    if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
        throw new Exception('Method not allowed');
    }

    $userId = (int)requireAuth()->id;
    $data = json_decode(file_get_contents('php://input'), true) ?: [];
    $invoiceId = (int)($data['supplier_invoice_id'] ?? 0);
    $amount = round((float)($data['amount'] ?? 0), 3);
    $date = (string)($data['payment_date'] ?? '');
    $method = strtoupper(trim((string)($data['method'] ?? '')));
    $account = trim((string)($data['account'] ?? ''));
    $rateInput = trim((string)($data['exchange_rate'] ?? ''));
    $key = requiredIdempotencyKey($data);

    if ($invoiceId <= 0 || $amount <= 0 || !preg_match('/^\\d{4}-\\d{2}-\\d{2}$/', $date)
        || !in_array($method, ['CASH', 'CHEQUE', 'BANK_TRANSFER', 'CARD', 'DRAFT', 'OTHER'], true)
        || $account === '') {
        throw new Exception('A valid invoice, amount, date, method and account are required');
    }

    $conn = db();
    requirePermission($conn, $userId, 'supplierPayments.record');
    $conn->begin_transaction();

    $query = $conn->prepare("
        SELECT
            status,
            validated_at,
            currency,
            exchange_rate invoice_exchange_rate,
            total_ttc - credited_amount - COALESCE((
                SELECT SUM(amount)
                FROM erp_supplier_payments
                WHERE supplier_invoice_id = erp_supplier_invoices.id
                  AND voided_at IS NULL
            ), 0) AS balance
        FROM erp_supplier_invoices
        WHERE id = ? AND user_id = ?
        FOR UPDATE
    ");
    $query->bind_param('ii', $invoiceId, $userId);
    $query->execute();
    $invoice = $query->get_result()->fetch_assoc();
    $query->close();

    if (!$invoice) {
        throw new Exception('Supplier invoice not found or unauthorized');
    }
    $exchange = settlementExchangeValues($invoice, $amount, $rateInput, $date);
    $reference = trim((string)($data['reference_number'] ?? ''));
    $hash = idempotencyRequestHash(['supplier_invoice_id' => $invoiceId, 'amount' => $amount, 'payment_date' => $date, 'method' => $method, 'account' => $account, 'reference_number' => $reference, 'exchange_rate' => $exchange['exchange_rate'], 'exchange_rate_date' => $exchange['exchange_rate_date']]);
    $replayedId = claimIdempotencyKey($conn, $userId, 'supplier.payment.add', $key, $hash);
    if ($replayedId !== null) {
        $conn->commit();
        jsonResponse(['success' => true, 'payment_id' => $replayedId, 'replayed' => true]);
    }

    if ($invoice['validated_at'] === null || !in_array(strtoupper((string)$invoice['status']), ['VALIDATED', 'PARTIALLY_PAID'], true)) {
        throw new Exception('Payments require an unpaid validated supplier invoice');
    }
    $balance = round((float)$invoice['balance'], 3);
    if ($balance <= 0.0005) {
        throw new Exception('Supplier invoice has no outstanding balance');
    }
    if ($amount > $balance + 0.0005) {
        throw new Exception('Payment exceeds the supplier invoice outstanding balance');
    }

    $proof = trim((string)($data['proof_path'] ?? ''));
    $stmt = $conn->prepare('INSERT INTO erp_supplier_payments(user_id,supplier_invoice_id,amount,exchange_rate,exchange_rate_date,amount_tnd,payment_date,method,account,reference_number,proof_path,recorded_by) VALUES(?,?,?,?,?,?,?,?,?,?,?,?)');
    $stmt->bind_param('iiddsdsssssi', $userId, $invoiceId, $amount, $exchange['exchange_rate'], $exchange['exchange_rate_date'], $exchange['amount_tnd'], $date, $method, $account, $reference, $proof, $userId);
    $stmt->execute();
    $paymentId = (int)$stmt->insert_id;
    $stmt->close();

    $remaining = round($balance - $amount, 3);
    $status = $remaining <= 0.0005 ? 'PAID' : 'PARTIALLY_PAID';
    $stmt = $conn->prepare('UPDATE erp_supplier_invoices SET status=? WHERE id=? AND user_id=?');
    $stmt->bind_param('sii', $status, $invoiceId, $userId);
    $stmt->execute();
    $stmt->close();

    auditLog($conn, $userId, $userId, 'SUPPLIER_PAYMENT.POSTED', 'SUPPLIER_PAYMENT', $paymentId,
        ['supplier_invoice_id' => $invoiceId, 'balance' => $balance],
        ['supplier_invoice_id' => $invoiceId, 'amount' => $amount, 'method' => $method,
         'currency' => $exchange['currency'], 'exchange_rate' => $exchange['exchange_rate'],
         'amount_tnd' => $exchange['amount_tnd'], 'reference_number' => $reference,
         'remaining_balance' => max(0, $remaining), 'status' => $status]);
    completeIdempotencyKey($conn, $userId, 'supplier.payment.add', $key, $paymentId);
    $conn->commit();
    jsonResponse(['success' => true, 'payment_id' => $paymentId, 'remaining_balance' => max(0, $remaining), 'status' => $status, 'currency' => $exchange['currency'], 'exchange_rate' => $exchange['exchange_rate'], 'amount_tnd' => $exchange['amount_tnd'], 'replayed' => false]);
} catch (Throwable $e) {
    if (isset($conn)) {
        try { $conn->rollback(); } catch (Throwable $ignored) {}
    }
    jsonResponse(['success' => false, 'message' => $e->getMessage()], 400);
}
