<?php

header('Content-Type: application/json');
require_once __DIR__ . '/../config/response.php';
require_once __DIR__ . '/../config/db.php';
require_once __DIR__ . '/../config/audit.php';
require_once __DIR__ . '/../auth/auth_required.php';
require_once __DIR__ . '/../auth/role_helper.php';
require_once __DIR__ . '/tax_profile_service.php';

try {
    if ($_SERVER['REQUEST_METHOD'] !== 'POST') throw new Exception('Method not allowed');
    $userId = (int) requireAuth()->id;
    $data = json_decode(file_get_contents('php://input'), true) ?: [];
    $productId = (int) ($data['product_id'] ?? 0);
    $profileId = (int) ($data['tax_profile_id'] ?? 0);
    if ($productId <= 0 || $profileId <= 0) throw new Exception('Product and tax profile are required');

    $conn = db();
    requireAnyPermission($conn, $userId, ['products.edit', 'services.edit', 'reports.view']);
    ensureTaxProfileSchema($conn);
    $conn->begin_transaction();
    $stmt = $conn->prepare('SELECT id FROM erp_tax_profiles WHERE id=? AND user_id=?');
    $stmt->bind_param('ii', $profileId, $userId);
    $stmt->execute();
    $valid = (bool) $stmt->get_result()->fetch_assoc();
    $stmt->close();
    if (!$valid) throw new Exception('Tax profile not found');

    $stmt = $conn->prepare('SELECT tax_profile_id FROM products WHERE id=? AND user_id=? FOR UPDATE');
    $stmt->bind_param('ii', $productId, $userId);
    $stmt->execute();
    $product = $stmt->get_result()->fetch_assoc();
    $stmt->close();
    if (!$product) throw new Exception('Product not found');

    $stmt = $conn->prepare('UPDATE products SET tax_profile_id=? WHERE id=? AND user_id=?');
    $stmt->bind_param('iii', $profileId, $productId, $userId);
    $stmt->execute();
    $stmt->close();
    auditLog($conn, $userId, $userId, 'TAX_PROFILE.ASSIGNED', 'PRODUCT', $productId,
        ['tax_profile_id'=>$product['tax_profile_id']], ['tax_profile_id'=>$profileId]);
    $conn->commit();
    jsonResponse(['success'=>true]);
} catch (Throwable $e) {
    if (isset($conn)) { try { $conn->rollback(); } catch (Throwable $ignored) {} }
    jsonResponse(['success'=>false,'message'=>$e->getMessage()],400);
}
