<?php

function requiredIdempotencyKey(?array $data = null): string
{
    $key = trim((string)($_SERVER['HTTP_IDEMPOTENCY_KEY'] ?? ''));
    if ($key === '' && $data !== null) {
        $key = trim((string)($data['idempotency_key'] ?? ''));
    }
    if ($key === '') {
        $key = trim((string)($_POST['idempotency_key'] ?? ''));
    }
    if (strlen($key) < 8 || strlen($key) > 128 || !preg_match('/^[A-Za-z0-9._:-]+$/', $key)) {
        throw new Exception('A valid idempotency key is required');
    }
    return $key;
}

function idempotencyRequestHash(array $payload): string
{
    ksort($payload);
    return hash('sha256', json_encode($payload, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE | JSON_PRESERVE_ZERO_FRACTION));
}

/**
 * Claims a key inside the caller's transaction.
 * Returns the prior entity id for a replay, or null when this request owns the key.
 */
function claimIdempotencyKey(
    mysqli $conn,
    int $userId,
    string $operation,
    string $key,
    string $requestHash
): ?int {
    if (strlen($operation) > 64) {
        throw new Exception('Invalid idempotency operation');
    }

    $stmt = $conn->prepare('INSERT INTO erp_idempotency_keys(user_id,operation_name,idempotency_key,request_hash) VALUES(?,?,?,?) ON DUPLICATE KEY UPDATE idempotency_key=VALUES(idempotency_key)');
    $stmt->bind_param('isss', $userId, $operation, $key, $requestHash);
    $stmt->execute();
    $claimed = $stmt->affected_rows === 1;
    $stmt->close();
    if ($claimed) {
        return null;
    }

    $stmt = $conn->prepare('SELECT request_hash,entity_id FROM erp_idempotency_keys WHERE user_id=? AND operation_name=? AND idempotency_key=? FOR UPDATE');
    $stmt->bind_param('iss', $userId, $operation, $key);
    $stmt->execute();
    $existing = $stmt->get_result()->fetch_assoc();
    $stmt->close();

    if (!$existing || !hash_equals((string)$existing['request_hash'], $requestHash)) {
        throw new Exception('Idempotency key was already used with a different request');
    }
    if ($existing['entity_id'] === null) {
        throw new Exception('The original idempotent request did not complete');
    }
    return (int)$existing['entity_id'];
}

function completeIdempotencyKey(
    mysqli $conn,
    int $userId,
    string $operation,
    string $key,
    int $entityId
): void {
    $stmt = $conn->prepare('UPDATE erp_idempotency_keys SET entity_id=?,completed_at=NOW() WHERE user_id=? AND operation_name=? AND idempotency_key=? AND entity_id IS NULL');
    $stmt->bind_param('iiss', $entityId, $userId, $operation, $key);
    $stmt->execute();
    if ($stmt->affected_rows !== 1) {
        throw new Exception('Could not complete idempotent request');
    }
    $stmt->close();
}
