<?php
header('Content-Type: application/json');
require_once __DIR__ . '/../config/response.php';
require_once __DIR__ . '/../config/db.php';
require_once __DIR__ . '/../auth/auth_required.php';
require_once __DIR__ . '/../auth/role_helper.php';



try {
    if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
        jsonResponse(['success' => false, 'message' => 'Method not allowed'], 405);
    }

    $userId = (int)requireAuth()->id;
    $data = json_decode(file_get_contents('php://input'), true);
    $id = (int)($data['id'] ?? 0);
    if ($id <= 0) throw new Exception('Invalid delivery note id');

    $conn = db();
    requirePermission($conn, $userId, 'deliveries.delete');

    $stmt = $conn->prepare("DELETE FROM erp_delivery_notes WHERE id = ? AND user_id = ? AND status = 'DRAFT'");
    $stmt->bind_param('ii', $id, $userId);
    $stmt->execute();
    $affected = $stmt->affected_rows;
    $stmt->close();

    if ($affected !== 1) throw new Exception('Only a draft delivery note can be deleted');

    jsonResponse(['success' => true, 'id' => $id]);
} catch (Throwable $e) {
    jsonResponse(['success' => false, 'message' => $e->getMessage()], 400);
}
