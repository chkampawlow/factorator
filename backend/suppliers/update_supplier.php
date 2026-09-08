<?php

header('Content-Type: application/json');

require_once __DIR__ . '/../config/response.php';
require_once __DIR__ . '/../config/db.php';
require_once __DIR__ . '/../config/validator.php';
require_once __DIR__ . '/../auth/auth_required.php';
require_once __DIR__ . '/../auth/role_helper.php';

require_once __DIR__ . '/supplier_service.php';



try {
    if (($_SERVER['REQUEST_METHOD'] ?? 'GET') !== 'POST') {
        jsonResponse([
            'success' => false,
            'message' => 'Method not allowed. Use POST.'
        ], 405);
        exit;
    }

    $authUser = requireAuth();
    $userId = (int)($authUser->id ?? 0);
    if ($userId <= 0) {
        throw new Exception('Unauthorized');
    }

    $conn = db();
    requirePermission($conn, $userId, 'suppliers.edit');
    ensureSuppliersTable($conn);

    $data = requireJsonBody();
    $id = getRequiredInt($data, 'id', 'Supplier ID');
    $payload = validateSupplierPayload($data);

    $existing = getSupplierById($conn, $userId, $id);
    if (!$existing) {
        jsonResponse([
            'success' => false,
            'message' => 'Supplier not found or unauthorized',
        ], 404);
        exit;
    }

    $stmt = $conn->prepare("
        UPDATE suppliers
        SET
            type = ?,
            name = ?,
            email = ?,
            phone = ?,
            address = ?,
            fiscal_id = ?
        WHERE id = ? AND user_id = ?
    ");

    if (!$stmt) {
        throw new Exception('Failed to prepare supplier update: ' . $conn->error);
    }

    $stmt->bind_param(
        'ssssssii',
        $payload['type'],
        $payload['name'],
        $payload['email'],
        $payload['phone'],
        $payload['address'],
        $payload['fiscalId'],
        $id,
        $userId
    );
    $stmt->execute();

    if ($stmt->error) {
        throw new Exception('Failed to update supplier: ' . $stmt->error);
    }

    $stmt->close();

    jsonResponse([
        'success' => true,
        'supplier' => getSupplierById($conn, $userId, $id),
        'message' => 'Supplier updated successfully',
    ]);
} catch (Throwable $e) {
    jsonResponse([
        'success' => false,
        'message' => $e->getMessage(),
    ], 400);
}
