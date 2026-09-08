<?php

declare(strict_types=1);

header('Content-Type: application/json');

require_once __DIR__ . '/../config/response.php';
require_once __DIR__ . '/../config/db.php';
require_once __DIR__ . '/../config/validator.php';
require_once __DIR__ . '/../auth/auth_required.php';
require_once __DIR__ . '/../auth/role_helper.php';
require_once __DIR__ . '/reception_confirmation_service.php';

try {
    if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'POST') {
        jsonResponse(['success' => false, 'message' => 'Method not allowed. Use POST.'], 405);
    }
    $principal = requireAuth();
    $tenantId = authTenantId($principal);
    $actorId = authActorId($principal);
    $data = requireJsonBody();
    $receptionId = getRequiredInt($data, 'supplier_reception_id', 'Supplier reception');
    $createExpense = filter_var($data['create_expense'] ?? false, FILTER_VALIDATE_BOOLEAN);

    $conn = db();
    requirePermission($conn, $tenantId, 'supplierReceptions.confirm');
    if ($createExpense) requirePermission($conn, $tenantId, 'expenses.create');
    $result = confirmSupplierReception($conn, $tenantId, $actorId, $receptionId, $createExpense);
    jsonResponse(['success' => true, 'message' => 'Supplier reception confirmed', ...$result]);
} catch (Throwable $error) {
    jsonResponse(['success' => false, 'message' => $error->getMessage()], resourceExceptionStatus($error));
}
