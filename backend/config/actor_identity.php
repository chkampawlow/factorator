<?php

declare(strict_types=1);

function actorCommercialName(mysqli $conn, int $actorId): string
{
    $stmt = $conn->prepare('SELECT display_name, email FROM users WHERE id = ? LIMIT 1');
    if (!$stmt) throw new RuntimeException('Could not load the connected user.');
    $stmt->bind_param('i', $actorId);
    $stmt->execute();
    $user = $stmt->get_result()->fetch_assoc();
    $stmt->close();

    $displayName = trim((string)($user['display_name'] ?? ''));
    if ($displayName !== '') return $displayName;

    $email = trim((string)($user['email'] ?? ''));
    $emailName = strstr($email, '@', true);
    return $emailName !== false && $emailName !== '' ? $emailName : $email;
}
