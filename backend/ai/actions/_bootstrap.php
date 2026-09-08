<?php

declare(strict_types=1);

require_once dirname(__DIR__) . '/database.php';
require_once dirname(__DIR__, 2) . '/config/cors.php';
require_once dirname(__DIR__, 2) . '/config/security_headers.php';
require_once dirname(__DIR__, 2) . '/config/request_limits.php';
require_once dirname(__DIR__, 2) . '/config/startup.php';

header('Content-Type: application/json; charset=utf-8');
header('Cache-Control: no-store');

applyCors('POST, OPTIONS', 'Content-Type, Authorization');
applySecurityHeaders();
applyRequestLimits();
enforceStartupConfiguration();

if (strtoupper((string) ($_SERVER['REQUEST_METHOD'] ?? '')) === 'OPTIONS') {
    http_response_code(204);
    exit;
}

if (strtoupper((string) ($_SERVER['REQUEST_METHOD'] ?? '')) !== 'POST') {
    respond(405, [
        'success' => false,
        'message' => 'Method not allowed. Use POST.',
    ]);
}

if (session_status() !== PHP_SESSION_ACTIVE) {
    session_start();
}

function respond(int $status, array $payload): never
{
    http_response_code($status);

    echo json_encode(
        $payload,
        JSON_UNESCAPED_UNICODE |
        JSON_UNESCAPED_SLASHES |
        JSON_THROW_ON_ERROR
    );

    exit;
}

/*
|--------------------------------------------------------------------------
| Legacy AI mutation safety gate
|--------------------------------------------------------------------------
| These standalone endpoints predate the membership-aware JWT/cookie,
| permission, confirmation, idempotency and audit contract used by the rest
| of the application. Keep them fail-closed until they are rebuilt on that
| shared contract. Read-only assistant endpoints are not routed through here.
*/
const AI_MUTATION_ACTIONS_DISABLED = true;

$disabledMutationScripts = [
    'create_client.php',
    'update_client.php',
    'delete_client.php',
    'create_product.php',
    'update_product.php',
    'delete_product.php',
    'create_invoice.php',
];
$currentMutationScript = basename((string)($_SERVER['SCRIPT_FILENAME'] ?? ''));

if (AI_MUTATION_ACTIONS_DISABLED && in_array($currentMutationScript, $disabledMutationScripts, true)) {
    respond(503, [
        'success' => false,
        'message' => 'AI mutation actions are temporarily disabled.',
        'code' => 'AI_MUTATION_ACTIONS_DISABLED',
    ]);
}

function input(): array
{
    $raw = file_get_contents('php://input');

    if ($raw === false || trim($raw) === '') {
        respond(400, [
            'success' => false,
            'message' => 'The request body is empty.',
        ]);
    }

    try {
        $data = json_decode($raw, true, 512, JSON_THROW_ON_ERROR);
    } catch (JsonException) {
        respond(400, [
            'success' => false,
            'message' => 'Invalid JSON body.',
        ]);
    }

    if (!is_array($data)) {
        respond(400, [
            'success' => false,
            'message' => 'The request body must be a JSON object.',
        ]);
    }

    return $data;
}

/*
|--------------------------------------------------------------------------
| Authentication
|--------------------------------------------------------------------------
| This code intentionally does not trust a user_id supplied by the AI or
| request body. Your login code must store the authenticated ID in:
|
|     $_SESSION['user_id']
|
| If your app uses JWT instead of PHP sessions, replace this function with
| your existing verified-JWT middleware and return the verified user ID.
*/

function authenticatedUserId(): int
{
    $userId = filter_var(
        $_SESSION['user_id'] ?? null,
        FILTER_VALIDATE_INT,
        ['options' => ['min_range' => 1]]
    );

    if ($userId === false) {
        respond(401, [
            'success' => false,
            'message' => 'Authentication required.',
        ]);
    }

    return (int) $userId;
}

function requiredString(
    array $data,
    string $key,
    int $maxLength = 255
): string {
    $value = trim((string) ($data[$key] ?? ''));

    if ($value === '') {
        respond(422, [
            'success' => false,
            'message' => "{$key} is required.",
        ]);
    }

    if (mb_strlen($value) > $maxLength) {
        respond(422, [
            'success' => false,
            'message' => "{$key} is too long.",
        ]);
    }

    return $value;
}

function optionalString(
    array $data,
    string $key,
    int $maxLength = 255
): ?string {
    if (!array_key_exists($key, $data) || $data[$key] === null) {
        return null;
    }

    $value = trim((string) $data[$key]);

    if (mb_strlen($value) > $maxLength) {
        respond(422, [
            'success' => false,
            'message' => "{$key} is too long.",
        ]);
    }

    return $value === '' ? null : $value;
}

function positiveId(array $data, string $key): int
{
    $value = filter_var(
        $data[$key] ?? null,
        FILTER_VALIDATE_INT,
        ['options' => ['min_range' => 1]]
    );

    if ($value === false) {
        respond(422, [
            'success' => false,
            'message' => "{$key} must be a positive integer.",
        ]);
    }

    return (int) $value;
}

function decimalValue(
    mixed $value,
    string $field,
    float $minimum = 0.0
): float {
    if (!is_numeric($value)) {
        respond(422, [
            'success' => false,
            'message' => "{$field} must be numeric.",
        ]);
    }

    $number = round((float) $value, 3);

    if ($number < $minimum) {
        respond(422, [
            'success' => false,
            'message' => "{$field} must be at least {$minimum}.",
        ]);
    }

    return $number;
}

function validDate(string $value, string $field): string
{
    $date = DateTimeImmutable::createFromFormat('!Y-m-d', $value);
    $errors = DateTimeImmutable::getLastErrors();

    if (
        !$date ||
        ($errors !== false &&
            ($errors['warning_count'] > 0 || $errors['error_count'] > 0)) ||
        $date->format('Y-m-d') !== $value
    ) {
        respond(422, [
            'success' => false,
            'message' => "{$field} must use YYYY-MM-DD.",
        ]);
    }

    return $value;
}

function ensureUserExists(PDO $pdo, int $userId): void
{
    $statement = $pdo->prepare(
        'SELECT id FROM users WHERE id = :id LIMIT 1'
    );
    $statement->execute(['id' => $userId]);

    if (!$statement->fetch()) {
        respond(401, [
            'success' => false,
            'message' => 'Authenticated user does not exist.',
        ]);
    }
}
