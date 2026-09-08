<?php

require_once __DIR__ . '/response.php';

function auditRedact($value)
{
    if (!is_array($value)) {
        return $value;
    }
    $sensitive = ['password', 'password_hash', 'token', 'access_token', 'refresh_token',
        'secret', 'google2fa_secret', 'authorization', 'proof_path', 'attachment_path'];
    $clean = [];
    foreach ($value as $key => $item) {
        $normalized = strtolower((string) $key);
        $clean[$key] = in_array($normalized, $sensitive, true) ? '[REDACTED]' : auditRedact($item);
    }
    return $clean;
}

function auditLog(
    mysqli $conn,
    ?int $tenantId,
    ?int $actorId,
    string $action,
    string $entityType,
    $entityId = null,
    ?array $before = null,
    ?array $after = null,
    string $source = 'API'
): void {
    if (function_exists('activeAuthPrincipal')) {
        $principal = activeAuthPrincipal();
        if ($principal !== null) {
            $tenantId = authTenantId($principal);
            $actorId = authActorId($principal);
        }
    }
    $requestId = appRequestId();
    $entityIdValue = $entityId === null ? null : (string) $entityId;
    $beforeJson = $before === null ? null : json_encode(auditRedact($before), JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
    $afterJson = $after === null ? null : json_encode(auditRedact($after), JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
    $ip = trim((string) ($_SERVER['REMOTE_ADDR'] ?? ''));
    $ipHash = $ip === '' ? null : hash_hmac('sha256', $ip, (string) ($_ENV['JWT_SECRET'] ?? 'local-audit-key'));
    $userAgent = mb_substr(trim((string) ($_SERVER['HTTP_USER_AGENT'] ?? '')), 0, 255);

    $stmt = $conn->prepare('INSERT INTO app_audit_log
        (tenant_id,actor_id,action,entity_type,entity_id,before_values,after_values,
         request_id,source,source_ip_hash,user_agent)
        VALUES (NULLIF(?,0),NULLIF(?,0),?,?,?,?,?,?,?,?,?)');
    $tenant = $tenantId ?? 0;
    $actor = $actorId ?? 0;
    $stmt->bind_param('iisssssssss', $tenant, $actor, $action, $entityType, $entityIdValue,
        $beforeJson, $afterJson, $requestId, $source, $ipHash, $userAgent);
    $stmt->execute();
    $stmt->close();
}
