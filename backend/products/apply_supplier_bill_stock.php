<?php

declare(strict_types=1);

/*
 * Backward-compatible alias for older clients. Stock posting is no longer a
 * standalone operation: it invokes the same atomic reception confirmation
 * transaction used by the current Angular application.
 */

header('Content-Type: application/json');

require_once __DIR__ . '/../config/response.php';
require_once __DIR__ . '/../config/db.php';
require_once __DIR__ . '/../config/validator.php';
require_once __DIR__ . '/../auth/auth_required.php';
require_once __DIR__ . '/../auth/role_helper.php';
require_once __DIR__ . '/../supplier_receptions/reception_confirmation_service.php';

try {
    if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'POST') {
        jsonResponse(['success' => false, 'message' => 'Method not allowed. Use POST.'], 405);
    }
    $principal = requireAuth();
    $tenantId = authTenantId($principal);
    $actorId = authActorId($principal);
    $data = requireJsonBody();
    $receptionId = getRequiredInt($data, 'supplier_bill_id', 'Supplier reception');
    $conn = db();
    requirePermission($conn, $tenantId, 'supplierReceptions.confirm');
    $result = confirmSupplierReception($conn, $tenantId, $actorId, $receptionId, false);
    jsonResponse([
        'success' => true,
        'message' => 'Supplier reception confirmed and stock applied',
        'already_applied' => (bool)$result['already_confirmed'],
        ...$result,
    ]);
} catch (Throwable $error) {
    jsonResponse(['success' => false, 'message' => $error->getMessage()], resourceExceptionStatus($error));
}
