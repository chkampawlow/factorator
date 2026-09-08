<?php
header('Content-Type: application/json');

require_once __DIR__ . '/../config/response.php';
require_once __DIR__ . '/../config/db.php';
require_once __DIR__ . '/../auth/auth_required.php';
require_once __DIR__ . '/../auth/role_helper.php';


try {
    if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
        jsonResponse([
            "success" => false,
            "message" => "Method not allowed. Use POST."
        ], 405);
        exit;
    }

    $authUser = requireAuth();
    $user_id = (int)$authUser->id;

    $data = json_decode(file_get_contents("php://input"), true);

    if (!is_array($data)) {
        throw new Exception("Invalid JSON body");
    }

    $id = isset($data['id']) ? (int)$data['id'] : 0;

    if ($id <= 0) {
        throw new Exception("Invalid product id");
    }

    $conn = db();
    $typeStmt = $conn->prepare("SELECT item_type FROM products WHERE id = ? AND user_id = ? LIMIT 1");
    $typeStmt->bind_param("ii", $id, $user_id);
    $typeStmt->execute();
    $product = $typeStmt->get_result()->fetch_assoc();
    $typeStmt->close();
    if (!$product) {
        throw new Exception("Product not found or not allowed");
    }
    requirePermission($conn, $user_id, strtoupper((string)($product['item_type'] ?? 'PRODUCT')) === 'SERVICE' ? 'services.delete' : 'products.delete');

    $stmt = $conn->prepare("
        DELETE FROM products
        WHERE id = ? AND user_id = ?
    ");
    $stmt->bind_param("ii", $id, $user_id);
    $stmt->execute();

    if ($stmt->affected_rows === 0) {
        $stmt->close();
        throw new Exception("Product not found or not allowed");
    }

    $stmt->close();

    jsonResponse([
        "success" => true,
        "message" => "Product deleted successfully"
    ]);
} catch (Throwable $e) {
    jsonResponse([
        "success" => false,
        "message" => $e->getMessage()
    ], resourceExceptionStatus($e));
}
?>
