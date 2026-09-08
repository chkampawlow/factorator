<?php

header('Content-Type: application/json');

require_once __DIR__ . '/../config/response.php';
require_once __DIR__ . '/refresh_token_service.php';
require_once __DIR__ . '/auth_cookie.php';

try {
    if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
        jsonResponse(['success' => false, 'message' => 'Method not allowed. Use POST.'], 405);
    }

    $data = json_decode(file_get_contents('php://input'), true);
    $refreshToken = refreshTokenFromRequest(is_array($data) ? $data : null);
    if ($refreshToken === '') {
        throw new InvalidArgumentException('Refresh token is required.');
    }

    $rotation = rotateRefreshToken($refreshToken);
    $accessToken = generateJwt($rotation['user'], 60 * 15);
    setAuthCookies($accessToken, $rotation['refresh_token'], 60 * 15, (int)$rotation['expires_in']);

    jsonResponse([
        'success' => true,
        'access_expires_in' => 60 * 15,
    ]);
} catch (Throwable $e) {
    jsonResponse([
        'success' => false,
        'message' => 'Invalid or expired refresh token.',
    ], 401);
}
