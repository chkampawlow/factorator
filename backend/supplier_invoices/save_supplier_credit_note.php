<?php
header('Content-Type: application/json');

require_once __DIR__ . '/../config/response.php';
require_once __DIR__ . '/../config/db.php';
require_once __DIR__ . '/../config/idempotency.php';
require_once __DIR__ . '/../config/audit.php';
require_once __DIR__ . '/../auth/auth_required.php';
require_once __DIR__ . '/../auth/role_helper.php';
require_once __DIR__ . '/../config/tenant_scope.php';

try {
    if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
        throw new Exception('Method not allowed');
    }

    $userId = (int)requireAuth()->id;
    $data = json_decode(file_get_contents('php://input'), true) ?: [];
    $invoiceId = (int)($data['supplier_invoice_id'] ?? 0);
    $returnId = (int)($data['supplier_return_id'] ?? 0);
    $number = trim((string)($data['credit_number'] ?? ''));
    $date = (string)($data['credit_date'] ?? '');
    $amount = round((float)($data['amount'] ?? 0), 3);
    $key = requiredIdempotencyKey($data);

    if ($invoiceId <= 0 || $number === '' || !preg_match('/^\\d{4}-\\d{2}-\\d{2}$/', $date) || $amount <= 0) {
        throw new Exception('Invoice, credit number, date and amount are required');
    }

    $conn = db();
    requirePermission($conn, $userId, 'supplierInvoices.credit');
    if ($returnId > 0) {
        requireTenantSupplierReturn($conn, $userId, $returnId);
    }
    $conn->begin_transaction();

    $hash = idempotencyRequestHash(['supplier_invoice_id' => $invoiceId, 'supplier_return_id' => $returnId, 'credit_number' => $number, 'credit_date' => $date, 'amount' => $amount, 'notes' => trim((string)($data['notes'] ?? ''))]);
    $replayedId = claimIdempotencyKey($conn, $userId, 'supplier.credit.add', $key, $hash);
    if ($replayedId !== null) {
        $conn->commit();
        jsonResponse(['success' => true, 'credit_note_id' => $replayedId, 'replayed' => true]);
    }

    $query = $conn->prepare("
        SELECT
            status,
            validated_at,
            total_ttc,
            credited_amount,
            COALESCE((
                SELECT SUM(amount)
                FROM erp_supplier_payments
                WHERE supplier_invoice_id = erp_supplier_invoices.id
                  AND voided_at IS NULL
            ), 0) AS payment_total
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
    if ($invoice['validated_at'] === null || strtoupper((string)$invoice['status']) === 'DRAFT') {
        throw new Exception('Credits require a validated supplier invoice');
    }

    $remaining = round((float)$invoice['total_ttc'] - (float)$invoice['credited_amount'] - (float)$invoice['payment_total'], 3);
    if ($amount > $remaining + 0.0005) {
        throw new Exception('Credit exceeds the supplier invoice outstanding balance');
    }

    $notes = trim((string)($data['notes'] ?? ''));
    $nullableReturnId = $returnId > 0 ? $returnId : null;
    $stmt = $conn->prepare("INSERT INTO erp_supplier_credit_notes(user_id,supplier_invoice_id,supplier_return_id,credit_number,credit_date,amount,status,notes,created_by) VALUES(?,?,?,?,?,?,'VALIDATED',?,?)");
    $stmt->bind_param('iiissdsi', $userId, $invoiceId, $nullableReturnId, $number, $date, $amount, $notes, $userId);
    $stmt->execute();
    $creditId = (int)$stmt->insert_id;
    $stmt->close();

    $stmt = $conn->prepare('UPDATE erp_supplier_invoices SET credited_amount=credited_amount+? WHERE id=? AND user_id=?');
    $stmt->bind_param('dii', $amount, $invoiceId, $userId);
    $stmt->execute();
    $stmt->close();

    $remaining = round($remaining - $amount, 3);
    $status = $remaining <= 0.0005 ? 'PAID' : ((float)$invoice['payment_total'] > 0.0005 || (float)$invoice['credited_amount'] + $amount > 0.0005 ? 'PARTIALLY_PAID' : 'VALIDATED');
    $stmt = $conn->prepare('UPDATE erp_supplier_invoices SET status=? WHERE id=? AND user_id=?');
    $stmt->bind_param('sii', $status, $invoiceId, $userId);
    $stmt->execute();
    $stmt->close();

    auditLog($conn, $userId, $userId, 'SUPPLIER_CREDIT.VALIDATED', 'SUPPLIER_CREDIT_NOTE', $creditId,
        ['supplier_invoice_id' => $invoiceId, 'balance' => $remaining + $amount,
         'credited_amount' => (float)$invoice['credited_amount']],
        ['supplier_invoice_id' => $invoiceId, 'supplier_return_id' => $returnId ?: null,
         'credit_number' => $number, 'amount' => $amount, 'remaining_balance' => max(0, $remaining),
         'status' => $status]);
    completeIdempotencyKey($conn, $userId, 'supplier.credit.add', $key, $creditId);
    $conn->commit();
    jsonResponse(['success' => true, 'credit_note_id' => $creditId, 'remaining_balance' => max(0, $remaining), 'status' => $status, 'replayed' => false, 'message' => 'Supplier credit recorded; stock changes require a confirmed supplier return']);
} catch (Throwable $e) {
    if (isset($conn)) {
        try { $conn->rollback(); } catch (Throwable $ignored) {}
    }
    jsonResponse(['success' => false, 'message' => $e->getMessage()], 400);
}
