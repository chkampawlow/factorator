<?php

header('Content-Type: application/json');
require_once __DIR__ . '/../config/response.php';
require_once __DIR__ . '/../config/db.php';
require_once __DIR__ . '/../auth/auth_required.php';
require_once __DIR__ . '/../auth/role_helper.php';

try {
    if ($_SERVER['REQUEST_METHOD'] !== 'POST') jsonResponse(['success' => false, 'message' => 'Method not allowed'], 405);
    $userId = (int)requireAuth()->id;
    $data = json_decode(file_get_contents('php://input'), true) ?: [];
    $outboxId = (int)($data['id'] ?? 0);
    $conn = db();
    requirePermission($conn, $userId, 'invoices.send');
    $stmt = $conn->prepare("UPDATE erp_einvoice_outbox SET status='RETRY_PENDING',last_error_code=NULL,last_error_message=NULL WHERE id=? AND user_id=? AND status='REJECTED'");
    $stmt->bind_param('ii', $outboxId, $userId);
    $stmt->execute();
    if ($stmt->affected_rows !== 1) throw new Exception('Only a rejected submission can be queued for retry');
    $stmt->close();
    jsonResponse(['success' => true, 'status' => 'RETRY_PENDING', 'submission_enabled' => false]);
} catch (Throwable $e) {
    jsonResponse(['success' => false, 'message' => $e->getMessage()], 400);
}
