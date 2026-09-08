<?php
ini_set('display_errors', '0');
ini_set('display_startup_errors', '0');
ini_set('log_errors', '1');
error_reporting(E_ALL);

header('Content-Type: application/json');

require_once __DIR__ . '/../config/db.php';
require_once __DIR__ . '/../config/response.php';
require_once __DIR__ . '/auth_required.php';
require_once __DIR__ . '/../config/rate_limit.php';




try {
    if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
        jsonResponse([
            "success" => false,
            "message" => "Method not allowed. Use POST."
        ], 405);
        exit;
    }

    $data = json_decode(file_get_contents("php://input"), true);

    if (!is_array($data)) {
        throw new InvalidArgumentException("Invalid JSON body.");
    }

    $code = trim($data['code'] ?? '');

    if ($code === '') {
        throw new InvalidArgumentException("Verification code is required");
    }

    if (!preg_match('/^\d{6}$/', $code)) {
        throw new InvalidArgumentException("Verification code must be 6 digits");
    }

    $tokenHash = hash('sha256', $code);
    $type = 'email_verification';
    $authUser = requireAuth(true);
    $authenticatedUserId = authActorId($authUser);

    enforceRateLimit('verify_email', (string)$authenticatedUserId, 10, 15 * 60);

    $conn = db();

    $stmt = $conn->prepare("
        SELECT id, user_id, expires_at, attempts
        FROM user_tokens
        WHERE token_hash = ? AND type = ? AND user_id = ?
        LIMIT 1
    ");

    if (!$stmt) {
        throw new Exception("Prepare failed (select token): " . $conn->error);
    }

    $stmt->bind_param("ssi", $tokenHash, $type, $authenticatedUserId);
    $stmt->execute();
    $tokenRow = $stmt->get_result()->fetch_assoc();
    $stmt->close();

    if (!$tokenRow) {
        throw new DomainException("Invalid verification code");
    }

    if ((int)$tokenRow['attempts'] >= 5) {
        throw new DomainException("Too many attempts. Request a new code.");
    }

    if (strtotime($tokenRow['expires_at']) < time()) {
        throw new DomainException("Verification code expired");
    }

    $verifiedAt = date('Y-m-d H:i:s');

    $updateUserStmt = $conn->prepare("
        UPDATE users
        SET email_verified_at = ?
        WHERE id = ?
    ");

    if (!$updateUserStmt) {
        throw new Exception("Prepare failed (update user): " . $conn->error);
    }

    $userId = (int)$tokenRow['user_id'];
    $updateUserStmt->bind_param("si", $verifiedAt, $userId);
    $updateUserStmt->execute();
    $updateUserStmt->close();

    $deleteStmt = $conn->prepare("
        DELETE FROM user_tokens
        WHERE id = ?
    ");

    if (!$deleteStmt) {
        throw new Exception("Prepare failed (delete token): " . $conn->error);
    }

    $tokenId = (int)$tokenRow['id'];
    $deleteStmt->bind_param("i", $tokenId);
    $deleteStmt->execute();
    $deleteStmt->close();

    clearRateLimit('verify_email', (string)$authenticatedUserId);

    jsonResponse([
        "success" => true,
        "message" => "Email verified successfully"
    ]);

} catch (InvalidArgumentException | DomainException $e) {
    jsonResponse([
        "success" => false,
        "message" => $e->getMessage()
    ], 400);
} catch (Throwable $e) {
    structuredLog('ERROR','AUTH.EMAIL_VERIFICATION_ERROR',['exception'=>get_class($e),'message'=>$e->getMessage()]);
    jsonResponse([
        "success" => false,
        "message" => "Unable to verify the email right now."
    ], 500);
}
