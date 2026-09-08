<?php

header('Content-Type: application/json');

require_once __DIR__ . '/../config/response.php';
require_once __DIR__ . '/../config/db.php';
require_once __DIR__ . '/../config/validator.php';
require_once __DIR__ . '/../config/audit.php';
require_once __DIR__ . '/../auth/auth_required.php';
require_once __DIR__ . '/../auth/role_helper.php';

require_once __DIR__ . '/supplier_service.php';

$debugStage = 'request';
try {
    if (($_SERVER['REQUEST_METHOD'] ?? 'GET') !== 'POST') {
        jsonResponse([
            'success' => false,
            'message' => 'Method not allowed. Use POST.'
        ], 405);
        exit;
    }

    $debugStage = 'authentication';
    $authUser = requireAuth();
    $userId = (int)($authUser->id ?? 0);
    if ($userId <= 0) {
        throw new Exception('Unauthorized');
    }

    $debugStage = 'authorization';
    $conn = db();
    requirePermission($conn, $userId, 'suppliers.create');
    ensureSuppliersTable($conn);

    $data = requireJsonBody();
    $payload = validateSupplierPayload($data);
    $reference = nextEntityReference($conn, $userId, 'SUPPLIER');

    $debugStage = 'supplier_insert';
    $stmt = $conn->prepare("
        INSERT INTO suppliers (
            reference,
            type,
            name,
            email,
            phone,
            address,
            fiscal_id,
            user_id
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    ");

    if (!$stmt) {
        throw new Exception('Failed to prepare supplier insert: ' . $conn->error);
    }

    $stmt->bind_param(
        'sssssssi',
        $reference,
        $payload['type'],
        $payload['name'],
        $payload['email'],
        $payload['phone'],
        $payload['address'],
        $payload['fiscalId'],
        $userId
    );
    $stmt->execute();

    if ($stmt->error) {
        throw new Exception('Failed to add supplier: ' . $stmt->error);
    }

    $id = (int)$stmt->insert_id;
    $stmt->close();

    $debugStage = 'supplier_reload';
    $supplier = getSupplierById($conn, $userId, $id);

    try {
        auditLog($conn, $userId, $userId, 'SUPPLIER.CREATED', 'SUPPLIER', $id, null, [
            'reference' => $reference,
            'type' => $payload['type'],
        ]);
    } catch (Throwable $auditError) {
        structuredLog('WARNING', 'SUPPLIER.CREATE_AUDIT_FAILED', [
            'supplier_id' => $id,
            'exception' => get_class($auditError),
        ]);
    }
    structuredLog('INFO', 'SUPPLIER.CREATED', [
        'supplier_id' => $id,
        'reference' => $reference,
    ]);

    jsonResponse([
        'success' => true,
        'id' => $id,
        'supplier' => $supplier,
        'message' => 'Supplier added successfully',
    ]);
} catch (Throwable $e) {
    structuredLog('ERROR', 'SUPPLIER.CREATE_FAILED', [
        'stage' => $debugStage,
        'exception' => get_class($e),
        'message' => $e->getMessage(),
    ]);
    jsonResponse([
        'success' => false,
        'message' => $e->getMessage(),
    ], 400);
}
