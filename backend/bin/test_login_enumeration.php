<?php

require_once __DIR__ . '/../config/db.php';

function postLogin(array $payload): array
{
    $context = stream_context_create([
        'http' => [
            'method' => 'POST',
            'header' => "Content-Type: application/json\r\n",
            'content' => json_encode($payload),
            'ignore_errors' => true,
            'timeout' => 10,
        ],
    ]);

    $body = file_get_contents('http://localhost/backend/auth/login.php', false, $context);
    $status = 0;
    foreach ($http_response_header ?? [] as $header) {
        if (preg_match('/^HTTP\/\S+\s+(\d{3})/', $header, $matches)) {
            $status = (int)$matches[1];
            break;
        }
    }

    return ['status' => $status, 'body' => json_decode((string)$body, true)];
}

$conn = db();
$result = $conn->query("SELECT email FROM users WHERE email <> '' LIMIT 1");
$knownEmail = (string)($result?->fetch_assoc()['email'] ?? '');
if ($knownEmail === '') {
    fwrite(STDERR, "FAIL no user fixture is available\n");
    exit(1);
}

$wrongPassword = 'wrong-' . bin2hex(random_bytes(16));
$unknownEmail = 'unknown-' . bin2hex(random_bytes(12)) . '@example.invalid';
$knownFailure = postLogin(['email' => $knownEmail, 'password' => $wrongPassword]);
$unknownFailure = postLogin(['email' => $unknownEmail, 'password' => $wrongPassword]);

$expectedPublicBody = ['success' => false, 'message' => 'Invalid email or password.'];
$knownPublicBody = $knownFailure['body'];
$unknownPublicBody = $unknownFailure['body'];
$knownRequestId = is_array($knownPublicBody) ? ($knownPublicBody['request_id'] ?? null) : null;
$unknownRequestId = is_array($unknownPublicBody) ? ($unknownPublicBody['request_id'] ?? null) : null;
unset($knownPublicBody['request_id'], $unknownPublicBody['request_id']);
$passed = $knownFailure['status'] === 401
    && $unknownFailure['status'] === 401
    && is_string($knownRequestId) && $knownRequestId !== ''
    && is_string($unknownRequestId) && $unknownRequestId !== ''
    && $knownPublicBody === $expectedPublicBody
    && $unknownPublicBody === $expectedPublicBody;

if (!$passed) {
    fwrite(STDERR, 'FAIL login failures differ: ' . json_encode([
        'known' => $knownFailure,
        'unknown' => $unknownFailure,
    ], JSON_UNESCAPED_SLASHES) . "\n");
    exit(1);
}

echo "PASS unknown email and incorrect password return identical 401 responses\n";
