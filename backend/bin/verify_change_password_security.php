<?php

declare(strict_types=1);

if (PHP_SAPI !== 'cli') {
    http_response_code(404);
    exit;
}

$source = file_get_contents(__DIR__ . '/../auth/change_password.php') ?: '';
$checks = [
    'authenticated caller required' => "requireAuth()",
    'current password verified' => 'password_verify($currentPassword',
    'shared password policy applied' => 'assertStrongPassword($newPassword',
    'password uses the platform hash' => 'password_hash($newPassword, PASSWORD_DEFAULT)',
    'new password confirmation uses constant-time comparison' => 'hash_equals($newPassword, $confirmPassword)',
    'refresh sessions revoked' => 'UPDATE auth_refresh_tokens',
    'password values excluded from audit event' => "'AUTH.PASSWORD_CHANGED'",
    'authentication cookies cleared' => 'clearAuthCookies()',
    'rate limit enforced' => "enforceRateLimit('change_password'",
];

$failures = [];
foreach ($checks as $label => $needle) {
    $passed = str_contains($source, $needle);
    echo ($passed ? 'PASS ' : 'FAIL ') . $label . PHP_EOL;
    if (!$passed) $failures[] = $label;
}

if (preg_match('/auditLog\([^;]*(currentPassword|newPassword|confirmPassword)/s', $source) === 1) {
    $failures[] = 'audit event contains a password variable';
    fwrite(STDERR, "FAIL audit event contains a password variable\n");
}

exit($failures === [] ? 0 : 1);
