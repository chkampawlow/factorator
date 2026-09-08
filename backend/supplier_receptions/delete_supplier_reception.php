<?php

header('Content-Type: application/json');

require_once __DIR__ . '/../config/response.php';
require_once __DIR__ . '/../config/db.php';
require_once __DIR__ . '/../config/upload.php';
require_once __DIR__ . '/../auth/auth_required.php';
require_once __DIR__ . '/../auth/role_helper.php';

require_once __DIR__ . '/reception_service.php';



try {
    if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
        jsonResponse(['success' => false, 'message' => 'Method not allowed'], 405);
    }

    $userId = (int)requireAuth()->id;
    $data = requireJsonBody();
    $id = getRequiredInt($data, 'id', 'Supplier reception');

    $conn = db();
    requirePermission($conn, $userId, 'supplierReceptions.delete');
    ensureSupplierReceptionsSchema($conn);

    $stmt = $conn->prepare("
        SELECT stock_applied, discrepancy_attachment_path
        FROM erp_supplier_receptions
        WHERE id = ? AND user_id = ?
        LIMIT 1
    ");
    if (!$stmt) {
        throw new Exception('Failed to prepare supplier reception delete lookup: ' . $conn->error);
    }
    $stmt->bind_param('ii', $id, $userId);
    $stmt->execute();
    $row = $stmt->get_result()->fetch_assoc();
    $stmt->close();

    if (!$row) {
        throw new Exception('Supplier reception not found or unauthorized');
    }
    if ((int)($row['stock_applied'] ?? 0) === 1) {
        throw new Exception('This supplier reception is already applied to stock and cannot be deleted');
    }

    $delete = $conn->prepare('DELETE FROM erp_supplier_receptions WHERE id = ? AND user_id = ?');
    if (!$delete) {
        throw new Exception('Failed to prepare supplier reception deletion: ' . $conn->error);
    }
    $delete->bind_param('ii', $id, $userId);
    $delete->execute();
    $delete->close();

    $attachmentPath = realpath((string)($row['discrepancy_attachment_path'] ?? ''));
    $allowedDirectory = realpath(privateStorageRoot() . '/supplier-receptions/' . $userId);
    if ($attachmentPath !== false && $allowedDirectory !== false && str_starts_with($attachmentPath, $allowedDirectory . DIRECTORY_SEPARATOR)) {
        @unlink($attachmentPath);
    }

    jsonResponse(['success' => true, 'message' => 'Supplier reception deleted']);
} catch (Throwable $e) {
    jsonResponse(['success' => false, 'message' => $e->getMessage()], 400);
}
