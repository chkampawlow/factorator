<?php

declare(strict_types=1);

require_once __DIR__ . '/../config/db.php';
require_once __DIR__ . '/../config/response.php';
require_once __DIR__ . '/../config/upload.php';
require_once __DIR__ . '/../auth/auth_required.php';
require_once __DIR__ . '/../auth/role_helper.php';

try {
    if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'GET') jsonResponse(['success' => false, 'message' => 'Method not allowed'], 405);
    $principal = requireAuth();
    $tenantId = authTenantId($principal);
    $receptionId = (int)($_GET['id'] ?? 0);
    if ($receptionId <= 0) throw new RuntimeException('Attachment not found');

    $conn = db();
    requirePermission($conn, $tenantId, 'supplierReceptions.view');
    $stmt = $conn->prepare('SELECT discrepancy_attachment_path path,discrepancy_attachment_name name,discrepancy_attachment_mime mime FROM erp_supplier_receptions WHERE id=? AND user_id=? LIMIT 1');
    $stmt->bind_param('ii', $receptionId, $tenantId);
    $stmt->execute();
    $file = $stmt->get_result()->fetch_assoc();
    $stmt->close();

    $realPath = $file && $file['path'] ? realpath((string)$file['path']) : false;
    $allowedDirectory = realpath(privateStorageRoot() . '/supplier-receptions/' . $tenantId);
    if ($realPath === false || $allowedDirectory === false || !str_starts_with($realPath, $allowedDirectory . DIRECTORY_SEPARATOR) || !is_file($realPath)) {
        throw new RuntimeException('Attachment not found');
    }

    $safeName = preg_replace('/[^A-Za-z0-9._ -]/', '_', basename((string)$file['name'])) ?: 'discrepancy-attachment';
    header('Content-Type: ' . (string)$file['mime']);
    header('Content-Disposition: attachment; filename="' . str_replace('"', '', $safeName) . '"');
    header('Content-Length: ' . filesize($realPath));
    readfile($realPath);
} catch (Throwable $error) {
    jsonResponse(['success' => false, 'message' => 'Attachment not found'], 404);
}

