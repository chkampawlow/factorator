<?php

declare(strict_types=1);

header('Content-Type: application/json');

require_once __DIR__ . '/../config/db.php';
require_once __DIR__ . '/../config/response.php';
require_once __DIR__ . '/../config/upload.php';
require_once __DIR__ . '/../auth/auth_required.php';
require_once __DIR__ . '/../auth/role_helper.php';
require_once __DIR__ . '/reception_service.php';

$storedPath = '';
try {
    if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'POST') {
        jsonResponse(['success' => false, 'message' => 'Method not allowed'], 405);
    }

    $principal = requireAuth();
    $tenantId = authTenantId($principal);
    $receptionId = (int)($_POST['supplier_reception_id'] ?? 0);
    if ($receptionId <= 0) throw new InvalidArgumentException('Supplier reception is required');

    $conn = db();
    requirePermission($conn, $tenantId, 'supplierReceptions.edit');
    ensureSupplierReceptionsSchema($conn);

    $upload = validatedUpload($_FILES['attachment'] ?? [], [
        'application/pdf' => ['pdf'],
        'image/jpeg' => ['jpg', 'jpeg'],
        'image/png' => ['png'],
        'image/webp' => ['webp'],
    ], 10 * 1024 * 1024);

    $directory = ensurePrivateDirectory('supplier-receptions/' . $tenantId);
    $storedPath = $directory . DIRECTORY_SEPARATOR . $upload['stored_name'];
    if (!move_uploaded_file($upload['tmp_name'], $storedPath)) {
        throw new RuntimeException('Could not store the discrepancy attachment');
    }
    chmod($storedPath, 0660);

    $conn->begin_transaction();
    $lock = $conn->prepare('SELECT discrepancy_attachment_path,status,stock_applied FROM erp_supplier_receptions WHERE id=? AND user_id=? LIMIT 1 FOR UPDATE');
    $lock->bind_param('ii', $receptionId, $tenantId);
    $lock->execute();
    $existing = $lock->get_result()->fetch_assoc();
    $lock->close();
    if (!$existing) throw new RuntimeException('Supplier reception not found');
    if ((int)$existing['stock_applied'] === 1 || (string)$existing['status'] !== 'DRAFT') {
        throw new RuntimeException('Confirmed supplier reception attachments are immutable');
    }

    $stmt = $conn->prepare('UPDATE erp_supplier_receptions SET discrepancy_attachment_path=?,discrepancy_attachment_name=?,discrepancy_attachment_mime=? WHERE id=? AND user_id=?');
    $stmt->bind_param('sssii', $storedPath, $upload['display_name'], $upload['mime'], $receptionId, $tenantId);
    $stmt->execute();
    $stmt->close();
    $conn->commit();

    $oldPath = realpath((string)($existing['discrepancy_attachment_path'] ?? ''));
    $allowedDirectory = realpath($directory);
    if ($oldPath !== false && $allowedDirectory !== false && str_starts_with($oldPath, $allowedDirectory . DIRECTORY_SEPARATOR) && $oldPath !== realpath($storedPath)) {
        @unlink($oldPath);
    }
    jsonResponse(['success' => true, 'name' => $upload['display_name']]);
} catch (Throwable $error) {
    if (isset($conn)) {
        try { $conn->rollback(); } catch (Throwable $ignored) {}
    }
    if ($storedPath !== '' && is_file($storedPath)) @unlink($storedPath);
    jsonResponse(['success' => false, 'message' => $error instanceof InvalidArgumentException ? $error->getMessage() : 'Could not upload discrepancy attachment'], resourceExceptionStatus($error));
}
