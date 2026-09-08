<?php

header('Content-Type: application/json');
require_once __DIR__ . '/../config/response.php';
require_once __DIR__ . '/../config/db.php';
require_once __DIR__ . '/../auth/auth_required.php';
require_once __DIR__ . '/../auth/role_helper.php';
require_once __DIR__ . '/../config/field_projection.php';

try {
    $userId = (int)requireAuth()->id;
    $conn = db();
    requireAnyPermission($conn, $userId, [
        'clients.view', 'orders.view', 'deliveries.view', 'invoices.view',
        'invoices.view', 'invoices.create', 'invoices.edit',
        'devis.view', 'devis.create', 'devis.edit',
        'avoirs.view', 'avoirs.create', 'avoirs.edit',
    ]);
    $search = trim((string)($_GET['search'] ?? ''));
    $limit = min(50, max(1, (int)($_GET['limit'] ?? 50)));
    $like = '%' . $search . '%';
    $stmt = $conn->prepare("SELECT id,reference,CASE WHEN type='person' THEN 'individual' ELSE type END type,name,email,phone,address,fiscalId,cin,payment_terms_days FROM clients WHERE user_id=? AND (?='' OR CONCAT_WS(' ',reference,name,email,phone,fiscalId,cin) LIKE ?) ORDER BY name,id LIMIT ?");
    $stmt->bind_param('issi', $userId, $search, $like, $limit);
    $stmt->execute();
    $rows = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);
    $stmt->close();
    $role = currentUserRole($conn, $userId);
    $rows = projectRows($rows, static fn(array $row): array => projectClientFields($row, $role));
    jsonResponse(['success' => true, 'data' => $rows]);
} catch (Throwable $e) {
    jsonResponse(['success' => false, 'message' => 'Could not load client options.', 'error_code' => 'CLIENT_OPTIONS_FAILED'], 500);
}
