<?php
header('Content-Type: application/json');

require_once __DIR__ . '/../config/response.php';
require_once __DIR__ . '/../config/db.php';
require_once __DIR__ . '/../auth/auth_required.php';
require_once __DIR__ . '/../auth/role_helper.php';
require_once __DIR__ . '/../config/field_projection.php';


try {
    if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
        jsonResponse([
            "success" => false,
            "message" => "Method not allowed. Use GET."
        ], 405);
        exit;
    }

    $authUser = requireAuth();
    $user_id = (int)$authUser->id;

    $conn = db();requireAnyPermission($conn,$user_id,['clients.view','orders.view','deliveries.view','invoices.view']);

    $stmt = $conn->prepare("
        SELECT
            id,
            reference,
            CASE WHEN type = 'person' THEN 'individual' ELSE type END AS type,
            name,
            email,
            phone,
            address,
            fiscalId,
            cin,
            payment_terms_days
        FROM clients
        WHERE user_id = ?
        ORDER BY id DESC
    ");

    $stmt->bind_param("i", $user_id);
    $stmt->execute();

    $result = $stmt->get_result();

    $clients = [];

    while ($row = $result->fetch_assoc()) {
        $clients[] = $row;
    }

    $stmt->close();
    $role = currentUserRole($conn, $user_id);
    $clients = projectRows($clients, static fn(array $row): array => projectClientFields($row, $role));

    jsonResponse([
        "success" => true,
        "data" => $clients
    ]);

} catch (Throwable $e) {

    jsonResponse([
        "success" => false,
        "message" => $e->getMessage()
    ], 400);

}
?>
