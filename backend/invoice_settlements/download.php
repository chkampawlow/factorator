<?php

require_once __DIR__ . '/../config/db.php';
require_once __DIR__ . '/../config/upload.php';
require_once __DIR__ . '/../auth/auth_required.php';
require_once __DIR__ . '/../auth/role_helper.php';

try {
    if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'GET') jsonResponse(['success'=>false,'message'=>'Method not allowed'],405);
    $userId = (int)requireAuth()->id;
    $id = (int)($_GET['id'] ?? 0);
    $type = strtoupper(trim((string)($_GET['type'] ?? '')));
    if ($id <= 0 || !in_array($type, ['PAYMENT', 'WITHHOLDING'], true)) throw new Exception('Attachment not found');

    $conn = db();
    requirePermission($conn, $userId, $type === 'PAYMENT' ? 'payments.view' : 'withholding.view');
    $sql = $type === 'PAYMENT'
        ? 'SELECT proof_path path,proof_name name,proof_mime mime FROM erp_invoice_payments WHERE id=? AND user_id=?'
        : 'SELECT attachment_path path,attachment_name name,attachment_mime mime FROM erp_invoice_withholdings WHERE id=? AND user_id=?';
    $stmt = $conn->prepare($sql);
    $stmt->bind_param('ii', $id, $userId);
    $stmt->execute();
    $file = $stmt->get_result()->fetch_assoc();
    $stmt->close();

    $realPath = $file && $file['path'] ? realpath((string)$file['path']) : false;
    $allowedDirectory = realpath(privateStorageRoot() . '/accounting/' . $userId);
    if ($realPath === false || $allowedDirectory === false || !str_starts_with($realPath, $allowedDirectory . DIRECTORY_SEPARATOR) || !is_file($realPath)) {
        throw new Exception('Attachment not found');
    }

    $safeName = preg_replace('/[^A-Za-z0-9._ -]/', '_', basename((string)$file['name'])) ?: 'attachment';
    header('Content-Type: ' . (string)$file['mime']);
    header('Content-Disposition: attachment; filename="' . str_replace('"', '', $safeName) . '"');
    header('Content-Length: ' . filesize($realPath));
    readfile($realPath);
} catch (Throwable $e) {
    jsonResponse(['success'=>false,'message'=>'Attachment not found'],404);
}
