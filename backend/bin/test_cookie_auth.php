<?php

require_once __DIR__ . '/../config/db.php';
require_once __DIR__ . '/../auth/jwt_helper.php';
require_once __DIR__ . '/../auth/refresh_token_service.php';

function cookieRequest(string $method, string $path, string $cookie): array
{
    $context = stream_context_create(['http' => [
        'method' => $method,
        'header' => "Content-Type: application/json\r\nCookie: {$cookie}\r\n",
        'content' => $method === 'POST' ? '{}' : null,
        'ignore_errors' => true,
        'timeout' => 10,
    ]]);
    $body = file_get_contents('http://localhost/backend/' . $path, false, $context);
    $headers = $http_response_header ?? [];
    $status = 0;
    foreach ($headers as $header) {
        if (preg_match('/^HTTP\/\S+\s+(\d{3})/', $header, $matches)) $status = (int)$matches[1];
    }
    return ['status' => $status, 'body' => json_decode((string)$body, true), 'headers' => $headers];
}

function pass(bool $condition, string $message): void
{
    if (!$condition) throw new RuntimeException('FAIL ' . $message);
    echo 'PASS ' . $message . "\n";
}

$conn = db();
$user = $conn->query("
    SELECT
        u.id,
        u.email,
        cm.role,
        cm.company_id,
        cm.id AS membership_id,
        cm.version AS membership_version
    FROM company_memberships cm
    JOIN companies c ON c.id = cm.company_id AND c.status = 'ACTIVE'
    JOIN users u ON u.id = cm.user_id
    WHERE cm.status = 'ACTIVE'
      AND cm.role = 'ADMINISTRATOR'
      AND u.account_status = 'ACTIVE'
      AND u.email_verified_at IS NOT NULL
    ORDER BY cm.is_owner DESC, cm.id
    LIMIT 1
")->fetch_assoc();
if (!$user) throw new RuntimeException('FAIL no administrator fixture is available');

$access = generateJwt($user, 300);
$business = cookieRequest('GET', 'clients/get_clients.php', 'ef_access=' . rawurlencode($access));
pass($business['status'] === 200, 'HttpOnly-style access cookie authenticates business requests');
$me = cookieRequest('GET', 'auth/me.php', 'ef_access=' . rawurlencode($access));
pass($me['status'] === 200
    && (int)($me['body']['user']['id'] ?? 0) === (int)$user['id']
    && (int)($me['body']['company']['id'] ?? 0) === (int)$user['company_id']
    && (int)($me['body']['membership']['id'] ?? 0) === (int)$user['membership_id'],
    'session payload keeps actor, company, and membership identities distinct');

$refresh = issueRefreshToken($user, 600);
$refreshAsAccess = cookieRequest('GET', 'clients/get_clients.php', 'ef_access=' . rawurlencode($refresh));
pass($refreshAsAccess['status'] === 401, 'refresh tokens cannot authenticate business endpoints');
$rotation = cookieRequest('POST', 'auth/refresh.php', 'ef_refresh=' . rawurlencode($refresh));
$setCookies = array_values(array_filter($rotation['headers'], static fn(string $header): bool => stripos($header, 'Set-Cookie:') === 0));
pass($rotation['status'] === 200 && ($rotation['body']['success'] ?? false) === true, 'refresh cookie rotates successfully');
pass(!isset($rotation['body']['access_token']) && !isset($rotation['body']['refresh_token']), 'token secrets are absent from JSON responses');
pass(count($setCookies) === 2
    && stripos(implode("\n", $setCookies), 'HttpOnly') !== false
    && stripos(implode("\n", $setCookies), 'SameSite=Lax') !== false,
    'rotated cookies are HttpOnly and SameSite');

$rotatedRefresh = '';
foreach ($setCookies as $header) {
    if (preg_match('/ef_refresh=([^;]+)/', $header, $matches)) $rotatedRefresh = rawurldecode($matches[1]);
}
pass($rotatedRefresh !== '', 'rotated refresh cookie is issued');
$logout = cookieRequest('POST', 'auth/logout.php', 'ef_refresh=' . rawurlencode($rotatedRefresh));
pass($logout['status'] === 200, 'cookie session logs out successfully');
$afterLogout = cookieRequest('POST', 'auth/refresh.php', 'ef_refresh=' . rawurlencode($rotatedRefresh));
pass($afterLogout['status'] === 401, 'logged-out refresh cookie cannot be reused');
