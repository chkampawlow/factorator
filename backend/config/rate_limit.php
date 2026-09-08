<?php

require_once __DIR__ . '/db.php';
require_once __DIR__ . '/response.php';

function rateLimitClientIp(): string
{
    return trim((string)($_SERVER['REMOTE_ADDR'] ?? 'unknown')) ?: 'unknown';
}

function rateLimitSubject(string $identifier): string
{
    return hash('sha256', rateLimitClientIp() . '|' . strtolower(trim($identifier)));
}

function enforceRateLimit(string $action, string $identifier, int $maxAttempts, int $windowSeconds): void
{
    $conn = db();
    $subjectHash = rateLimitSubject($identifier);
    $keyHash = hash('sha256', $action . '|' . $subjectHash);

    $stmt = $conn->prepare("
        INSERT INTO auth_rate_limits
            (key_hash, action_name, subject_hash, attempts, window_started_at, updated_at)
        VALUES (?, ?, ?, 1, NOW(), NOW())
        ON DUPLICATE KEY UPDATE
            attempts = IF(window_started_at <= DATE_SUB(NOW(), INTERVAL ? SECOND), 1, attempts + 1),
            window_started_at = IF(window_started_at <= DATE_SUB(NOW(), INTERVAL ? SECOND), NOW(), window_started_at),
            updated_at = NOW()
    ");
    $stmt->bind_param('sssii', $keyHash, $action, $subjectHash, $windowSeconds, $windowSeconds);
    $stmt->execute();
    $stmt->close();

    $stmt = $conn->prepare('
        SELECT attempts, GREATEST(1, ? - TIMESTAMPDIFF(SECOND, window_started_at, NOW())) AS retry_after
        FROM auth_rate_limits
        WHERE key_hash = ?
        LIMIT 1
    ');
    $stmt->bind_param('is', $windowSeconds, $keyHash);
    $stmt->execute();
    $row = $stmt->get_result()->fetch_assoc();
    $stmt->close();

    if ((int)($row['attempts'] ?? 0) > $maxAttempts) {
        $retryAfter = max(1, (int)($row['retry_after'] ?? $windowSeconds));
        header('Retry-After: ' . $retryAfter);
        jsonResponse([
            'success' => false,
            'message' => 'Too many requests. Please try again later.',
            'code' => 'RATE_LIMITED',
            'retry_after' => $retryAfter,
        ], 429);
    }

    if (random_int(1, 100) === 1) {
        $conn->query('DELETE FROM auth_rate_limits WHERE updated_at < DATE_SUB(NOW(), INTERVAL 2 DAY)');
    }
}

function clearRateLimit(string $action, string $identifier): void
{
    $keyHash = hash('sha256', $action . '|' . rateLimitSubject($identifier));
    $stmt = db()->prepare('DELETE FROM auth_rate_limits WHERE key_hash = ?');
    $stmt->bind_param('s', $keyHash);
    $stmt->execute();
    $stmt->close();
}
