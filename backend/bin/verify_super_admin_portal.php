<?php

declare(strict_types=1);

if (PHP_SAPI !== 'cli') {
    http_response_code(404);
    exit;
}

$portalCandidates = [
    __DIR__ . '/../server_dashboard.php',
    __DIR__ . '/../../server_dashboard.php',
];
$source = '';
foreach ($portalCandidates as $portalCandidate) {
    if (is_file($portalCandidate)) {
        $source = file_get_contents($portalCandidate) ?: '';
        break;
    }
}
$failures = [];

$requiredGuards = [
    "SERVER_DASHBOARD_ACCESS_KEY",
    "SERVER_DASHBOARD_SQL_ENABLED",
    "SERVER_DASHBOARD_REQUIRE_HTTPS",
    "SERVER_DASHBOARD_ALLOWED_IPS",
    "resolveBackendDirectory",
    "session_set_cookie_params",
    "'httponly' => true",
    "'samesite' => 'Strict'",
    'csrfValid()',
    'hash_equals($dbName',
    "confirm_write",
    "confirm_database",
    "super-admin-sql.jsonl",
    "multi_query",
    "AUTH.LOGIN_SUCCEEDED",
    "DOCUMENT_EMAIL.SENT",
    "EMAIL.FAILED",
    "auth_refresh_tokens",
    "'accept_user'",
    "acceptUserForm",
    "SUPER_ADMIN.USER_ACCEPTED",
    "set_user_approval_policy",
    "new_user_approval_required",
    "SUPER_ADMIN.USER_AUTO_ACTIVATION_ENABLED",
    "super-admin-operations.jsonl",
    "Authentication trend",
    "Account status",
    "New registrations",
    "data-open-section=\"security\"",
    "registrationActivity",
    "archived_users",
    "el-fatoura-icon.svg",
    "Error Center",
    "Recent application errors",
    "Supplier workflow diagnostics",
    "dashboardDiagnosticHint",
    "Account Activity",
    "Performed by",
    "actor_user.email",
    "auditChangedFields",
];

foreach ($requiredGuards as $guard) {
    if (!str_contains($source, $guard)) $failures[] = "missing guard: $guard";
}

foreach (["const DASHBOARD_ACCESS_KEY", "serverstat", "\$_GET['key']"] as $retiredPattern) {
    if (str_contains($source, $retiredPattern)) $failures[] = "retired insecure access pattern remains: $retiredPattern";
}

$approvalSources = [
    __DIR__ . '/../auth/signup.php' => ['platformBooleanSetting', '$initialAccountStatus', "'requires_approval' => \$requiresApproval"],
    __DIR__ . '/../auth/login.php' => ['ACCOUNT_PENDING_APPROVAL', 'AUTH.LOGIN_BLOCKED_PENDING'],
    __DIR__ . '/../auth/auth_required.php' => ['ACCOUNT_PENDING_APPROVAL'],
    __DIR__ . '/../auth/verify_2fa_login.php' => ['ACCOUNT_PENDING_APPROVAL'],
    __DIR__ . '/../sql/2026-09-08-user-account-approval.sql' => ["ENUM('PENDING','ACTIVE','ARCHIVED')", 'approved_at'],
    __DIR__ . '/../sql/2026-09-09-new-user-approval-policy.sql' => ['erp_platform_settings', 'new_user_approval_required'],
    __DIR__ . '/../config/platform_settings.php' => ['platformBooleanSetting', 'NEW_USER_APPROVAL_SETTING'],
];
foreach ($approvalSources as $path => $patterns) {
    $approvalSource = is_file($path) ? (file_get_contents($path) ?: '') : '';
    foreach ($patterns as $pattern) {
        if (!str_contains($approvalSource, $pattern)) {
            $failures[] = 'missing account approval guard: ' . basename($path) . ':' . $pattern;
        }
    }
}

$emailAuditSources = [
    __DIR__ . '/../auth/send_verification_email.php' => ['EMAIL.SENT', 'EMAIL.FAILED', 'EMAIL_VERIFICATION'],
    __DIR__ . '/../auth/forgot_password.php' => ['EMAIL.SENT', 'EMAIL.FAILED', 'PASSWORD_RESET'],
    __DIR__ . '/../user/invite_member.php' => ['EMAIL.SENT', 'EMAIL.FAILED', 'COMPANY_INVITATION'],
];
foreach ($emailAuditSources as $path => $events) {
    $emailSource = is_file($path) ? (file_get_contents($path) ?: '') : '';
    foreach ($events as $event) {
        if (!str_contains($emailSource, $event)) $failures[] = 'missing email audit event: ' . basename($path) . ':' . $event;
    }
}

if ($failures) {
    foreach ($failures as $failure) fwrite(STDERR, "FAIL $failure" . PHP_EOL);
    exit(1);
}

echo 'PASS Super Admin portal access, user approval, cross-account actor audit, dashboard charts, operations metrics, email audit and SQL guards' . PHP_EOL;
