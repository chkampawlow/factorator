<?php
header('Content-Type: application/json');

require_once __DIR__ . '/../config/response.php';
require_once __DIR__ . '/../config/db.php';
require_once __DIR__ . '/../auth/auth_required.php';
require_once __DIR__ . '/../auth/role_helper.php';




// Make mysqli throw exceptions so errors are never silent
mysqli_report(MYSQLI_REPORT_ERROR | MYSQLI_REPORT_STRICT);

try {
    $method = strtoupper($_SERVER['REQUEST_METHOD'] ?? '');
    if ($method !== 'POST' && $method !== 'DELETE') {
        jsonResponse([
            'success' => false,
            'message' => 'Method not allowed. Use POST or DELETE.'
        ], 405);
        exit;
    }

    $authUser = requireAuth();
    $user_id = (int)($authUser->id ?? 0);
    if ($user_id <= 0) {
        throw new Exception('Unauthorized');
    }

    // Accept id from JSON body OR query string (DELETE?id=...)
    $rawBody = file_get_contents('php://input');
    $data = json_decode($rawBody ?: '', true);

    $id = 0;
    if (is_array($data) && isset($data['id'])) {
        $id = (int)$data['id'];
    }
    if ($id <= 0 && isset($_GET['id'])) {
        $id = (int)$_GET['id'];
    }

    if ($id <= 0) {
        throw new Exception('Client ID is required');
    }

    $conn = db();
    requirePermission($conn, $user_id, 'clients.delete');

    // 1) check ownership
    $check = $conn->prepare("SELECT id FROM clients WHERE id = ? AND user_id = ? LIMIT 1");
    $check->bind_param("ii", $id, $user_id);
    $check->execute();
    $row = $check->get_result()->fetch_assoc();
    $check->close();

    if (!$row) {
        jsonResponse([
            'success' => false,
            'message' => 'Client not found or unauthorized'
        ], 404);
        exit;
    }

    // 2) delete ONLY the client
    $stmt = $conn->prepare("DELETE FROM clients WHERE id = ? AND user_id = ? LIMIT 1");
    $stmt->bind_param("ii", $id, $user_id);
    $stmt->execute();

    $affected = (int)$stmt->affected_rows;
    $stmt->close();

    if ($affected <= 0) {
        throw new Exception('Delete failed (no rows affected)');
    }

    jsonResponse([
        'success' => true,
        'message' => 'Client deleted successfully',
        'id' => $id
    ]);
} catch (Throwable $e) {
    jsonResponse([
        'success' => false,
        'message' => $e->getMessage()
    ], 400);
}
