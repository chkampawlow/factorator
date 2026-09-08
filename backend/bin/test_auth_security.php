<?php

require_once __DIR__ . '/../config/db.php';
require_once __DIR__ . '/../auth/jwt_helper.php';

function httpRequest(string $method, string $path, ?array $payload = null, array $headers = []): array
{
    $headerLines = array_merge(['Content-Type: application/json'], $headers);
    $options = [
        'method' => $method,
        'header' => implode("\r\n", $headerLines) . "\r\n",
        'ignore_errors' => true,
        'timeout' => 10,
    ];
    if ($payload !== null) $options['content'] = json_encode($payload);
    $context = stream_context_create(['http' => $options]);
    $body = file_get_contents('http://localhost/backend/' . ltrim($path, '/'), false, $context);
    $status = 0;
    foreach ($http_response_header ?? [] as $header) {
        if (preg_match('/^HTTP\/\S+\s+(\d{3})/', $header, $matches)) {
            $status = (int)$matches[1];
            break;
        }
    }
    return ['status' => $status, 'body' => json_decode((string)$body, true)];
}

function check(bool $condition, string $message): void
{
    if (!$condition) throw new RuntimeException('FAIL ' . $message);
    echo 'PASS ' . $message . "\n";
}

$conn = db();
$user = $conn->query("SELECT id,email,role,email_verified_at FROM users WHERE account_status='ACTIVE' AND email_verified_at IS NOT NULL ORDER BY id LIMIT 1")->fetch_assoc();
if (!$user) throw new RuntimeException('FAIL no active verified user fixture is available');

$originalVerifiedAt = $user['email_verified_at'];
$verificationChanged = false;

try {
    $totp = httpRequest('POST', 'auth/verify_2fa_login.php', ['code' => '000000']);
    check($totp['status'] !== 200 && empty($totp['body']['access_token']), 'TOTP without a password challenge cannot log in');

    $token = generateJwt($user, 300);
    $userId = (int)$user['id'];
    $stmt = $conn->prepare('UPDATE users SET email_verified_at = NULL WHERE id = ?');
    $stmt->bind_param('i', $userId);
    $stmt->execute();
    $stmt->close();
    $verificationChanged = true;

    $business = httpRequest('GET', 'clients/get_clients.php', null, ['X-Access-Token: ' . $token]);
    check($business['status'] === 403 && ($business['body']['code'] ?? '') === 'EMAIL_NOT_VERIFIED', 'unverified users cannot access business data');

    $restore = $conn->prepare('UPDATE users SET email_verified_at = ? WHERE id = ?');
    $restore->bind_param('si', $originalVerifiedAt, $userId);
    $restore->execute();
    $restore->close();
    $verificationChanged = false;

    $limitedEmail = 'limited-' . bin2hex(random_bytes(8)) . '@example.invalid';
    $unrelatedEmail = 'unrelated-' . bin2hex(random_bytes(8)) . '@example.invalid';
    $password = 'Definitely-wrong-2026!';
    $lastLimited = null;
    for ($attempt = 1; $attempt <= 11; $attempt++) {
        $lastLimited = httpRequest('POST', 'auth/login.php', ['email' => $limitedEmail, 'password' => $password]);
    }
    $unrelated = httpRequest('POST', 'auth/login.php', ['email' => $unrelatedEmail, 'password' => $password]);
    check($lastLimited['status'] === 429 && ($lastLimited['body']['code'] ?? '') === 'RATE_LIMITED', 'brute-force attempts trigger the login rate limit');
    check($unrelated['status'] === 401, 'rate limiting one identity does not lock out an unrelated identity');
} finally {
    if ($verificationChanged) {
        $userId = (int)$user['id'];
        $restore = $conn->prepare('UPDATE users SET email_verified_at = ? WHERE id = ?');
        $restore->bind_param('si', $originalVerifiedAt, $userId);
        $restore->execute();
        $restore->close();
    }
}
