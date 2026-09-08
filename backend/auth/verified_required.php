<?php

require_once __DIR__ . '/../config/db.php';
require_once __DIR__ . '/../config/response.php';
require_once __DIR__ . '/company_context.php';

function requireVerifiedEmail(object $authUser): void
{
    $conn = db();

    $stmt = $conn->prepare("
        SELECT email_verified_at
        FROM users
        WHERE id = ?
        LIMIT 1
    ");

    $userId = authActorId($authUser);
    $stmt->bind_param("i", $userId);
    $stmt->execute();

    $row = $stmt->get_result()->fetch_assoc();
    $stmt->close();

    if (!$row || empty($row['email_verified_at'])) {
        jsonResponse([
            "success" => false,
            "message" => "Email not verified.",
            "code" => "EMAIL_NOT_VERIFIED"
        ], 403);
        exit;
    }
}
