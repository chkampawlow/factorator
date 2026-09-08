<?php

declare(strict_types=1);

header('Content-Type: application/json');

require_once __DIR__ . '/../config/response.php';
require_once __DIR__ . '/../config/db.php';
require_once __DIR__ . '/../auth/auth_required.php';
require_once __DIR__ . '/../auth/role_helper.php';
require_once __DIR__ . '/supplier_service.php';

try {
    if (($_SERVER['REQUEST_METHOD'] ?? 'GET') !== 'GET') {
        jsonResponse(['success' => false, 'message' => 'Method not allowed. Use GET.'], 405);
    }

    $userId = (int)requireAuth()->id;
    $supplierId = (int)($_GET['id'] ?? 0);
    if ($supplierId <= 0) {
        jsonResponse(['success' => false, 'message' => 'Invalid supplier id.'], 422);
    }

    $conn = db();
    requireAnyPermission($conn, $userId, ['suppliers.view', 'supplierOrders.view', 'supplierReceptions.view']);
    ensureSuppliersTable($conn);
    $stmt = $conn->prepare('SELECT id,reference,type,name,email,phone,address,fiscal_id FROM suppliers WHERE id=? AND user_id=? LIMIT 1');
    $stmt->bind_param('ii', $supplierId, $userId);
    $stmt->execute();
    $row = $stmt->get_result()->fetch_assoc();
    $stmt->close();

    if (!$row) {
        jsonResponse(['success' => false, 'message' => 'Supplier not found.'], 404);
    }
    jsonResponse(['success' => true, 'supplier' => supplierRow($row)]);
} catch (Throwable $e) {
    jsonResponse(['success' => false, 'message' => 'Could not load the supplier.', 'error_code' => 'SUPPLIER_GET_FAILED'], 500);
}
