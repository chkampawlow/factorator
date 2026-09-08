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
    requirePermission($conn, $userId, 'withholding.record');

    $invoiceId = (int)($_POST['invoice_id'] ?? 0);
    $type = strtoupper(trim((string)($_POST['withholding_type'] ?? '')));
    $rate = round((float)($_POST['rate'] ?? 0), 4);
    $base = round((float)($_POST['calculation_base'] ?? 0), 3);
    $number = trim((string)($_POST['certificate_number'] ?? ''));
    $date = trim((string)($_POST['certificate_date'] ?? ''));
    $expectedDate = trim((string)($_POST['expected_certificate_date'] ?? ''));
    $status = strtoupper(trim((string)($_POST['certificate_status'] ?? 'PENDING')));
    $key = requiredIdempotencyKey();

    if ($type === '' || strlen($type) > 40) throw new Exception('Withholding type is required');
    if ($rate < 0 || $rate > 100 || $base <= 0) throw new Exception('Invalid withholding rate or calculation base');
    if (!in_array($status, ['PENDING', 'RECEIVED', 'VALIDATED'], true)) throw new Exception('Invalid certificate status');
    if ($date !== '' && !DateTimeImmutable::createFromFormat('!Y-m-d', $date)) throw new Exception('Invalid certificate date');
    if ($expectedDate !== '' && !DateTimeImmutable::createFromFormat('!Y-m-d', $expectedDate)) throw new Exception('Invalid expected certificate date');
    if (in_array($status, ['RECEIVED', 'VALIDATED'], true) && ($number === '' || $date === '')) throw new Exception('Certificate number and date are required');
    $amount = round($base * $rate / 100, 3);

    $hash = idempotencyRequestHash([
        'invoice_id' => $invoiceId,
        'withholding_type' => $type,
        'rate' => $rate,
        'calculation_base' => $base,
        'certificate_number' => $number,
        'certificate_date' => $date,
        'expected_certificate_date' => $expectedDate,
        'certificate_status' => $status,
    ]);

    $conn->begin_transaction();
    $replayedId = claimIdempotencyKey($conn, $userId, 'invoice.withholding.add', $key, $hash);
    if ($replayedId !== null) {
        $summary = settlementSummary($conn, $invoiceId, $userId);
        $conn->commit();
        jsonResponse(['success' => true, 'id' => $replayedId, 'withheld_amount' => $amount, 'summary' => $summary, 'replayed' => true]);
    }

    requireSettlementInvoice($conn, $invoiceId, $userId, true);
    $before = settlementSummary($conn, $invoiceId, $userId);
    if ($amount > (float)$before['remaining_balance'] + 0.0005) throw new Exception('Withholding exceeds the outstanding balance');

    [$path, $name, $mime] = storeSettlementUpload('attachment', $userId);
    $stmt = $conn->prepare("INSERT INTO erp_invoice_withholdings(invoice_id,user_id,withholding_type,rate,calculation_base,withheld_amount,certificate_number,certificate_date,expected_certificate_date,certificate_status,received_at,validated_at,attachment_path,attachment_name,attachment_mime,recorded_by) VALUES(?,?,?,?,?,?,?,NULLIF(?,''),NULLIF(?,''),?,IF(? IN('RECEIVED','VALIDATED'),NOW(),NULL),IF(?='VALIDATED',NOW(),NULL),?,?,?,?)");
    $stmt->bind_param('iisdddsssssssssi', $invoiceId, $userId, $type, $rate, $base, $amount, $number, $date, $expectedDate, $status, $status, $status, $path, $name, $mime, $actorId);
    $stmt->execute();
    $withholdingId = (int)$stmt->insert_id;
    $stmt->close();

    $summary = syncInvoiceSettlementState($conn, $invoiceId, $userId);
    $stmt = $conn->prepare('UPDATE erp_invoices SET tx_retenue=? WHERE id=? AND user_id=?');
    $stmt->bind_param('dii', $rate, $invoiceId, $userId);
    $stmt->execute();
    $stmt->close();

    auditLog($conn, $userId, $actorId, 'WITHHOLDING.RECORDED', 'INVOICE_WITHHOLDING', $withholdingId,
        ['invoice_id' => $invoiceId, 'settlement' => $before],
        ['invoice_id' => $invoiceId, 'type' => $type, 'rate' => $rate, 'base' => $base,
         'amount' => $amount, 'certificate_status' => $status, 'expected_certificate_date'=>$expectedDate ?: null, 'settlement' => $summary]);
    completeIdempotencyKey($conn, $userId, 'invoice.withholding.add', $key, $withholdingId);
    $conn->commit();
    jsonResponse(['success' => true, 'id' => $withholdingId, 'withheld_amount' => $amount, 'summary' => $summary, 'replayed' => false]);
} catch (Throwable $e) {
    if (isset($conn)) {
        try { $conn->rollback(); } catch (Throwable $ignored) {}
    }
    if (!empty($path) && is_file($path)) unlink($path);
    jsonResponse(['success' => false, 'message' => $e->getMessage()], 400);
}
