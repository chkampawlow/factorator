<?php

declare(strict_types=1);

header('Content-Type: application/json');

require_once __DIR__ . '/../config/response.php';
require_once __DIR__ . '/../config/db.php';
require_once __DIR__ . '/../auth/auth_required.php';
require_once __DIR__ . '/../auth/role_helper.php';
require_once __DIR__ . '/../config/field_projection.php';

try {
    if (($_SERVER['REQUEST_METHOD'] ?? 'GET') !== 'GET') {
        jsonResponse(['success' => false, 'message' => 'Method not allowed. Use GET.'], 405);
    }

    $userId = (int)requireAuth()->id;
    $clientId = (int)($_GET['id'] ?? 0);
    if ($clientId <= 0) {
        jsonResponse(['success' => false, 'message' => 'Invalid client id.'], 422);
    }

    $conn = db();
    requireAnyPermission($conn, $userId, ['clients.view', 'orders.view', 'deliveries.view', 'invoices.view']);
    $stmt = $conn->prepare("SELECT id,reference,CASE WHEN type='person' THEN 'individual' ELSE type END type,name,email,phone,address,fiscalId,cin,payment_terms_days FROM clients WHERE id=? AND user_id=? LIMIT 1");
    $stmt->bind_param('ii', $clientId, $userId);
    $stmt->execute();
    $client = $stmt->get_result()->fetch_assoc();
    $stmt->close();

    if (!$client) {
        jsonResponse(['success' => false, 'message' => 'Client not found.'], 404);
    }
    $client = projectClientFields($client, currentUserRole($conn, $userId));
    jsonResponse(['success' => true, 'client' => $client]);
} catch (Throwable $e) {
    jsonResponse(['success' => false, 'message' => 'Could not load the client.', 'error_code' => 'CLIENT_GET_FAILED'], 500);
}
