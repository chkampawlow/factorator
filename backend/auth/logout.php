<?php

header('Content-Type: application/json');

require_once __DIR__ . '/../config/response.php';
require_once __DIR__ . '/refresh_token_service.php';
require_once __DIR__ . '/auth_cookie.php';

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    jsonResponse(['success' => false, 'message' => 'Method not allowed. Use POST.'], 405);
}

$data = json_decode(file_get_contents('php://input'), true);
$refreshToken = refreshTokenFromRequest(is_array($data) ? $data : null);
revokeRefreshToken($refreshToken);
clearAuthCookies();

jsonResponse(['success' => true, 'message' => 'Signed out.']);
