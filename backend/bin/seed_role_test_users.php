<?php

declare(strict_types=1);

/**
 * Create or refresh one active test user for every application role.
 *
 * Usage:
 *   TEST_USER_PASSWORD='Factorator-Test-2026!' \
 *     php backend/bin/seed_role_test_users.php <company_id>
 *
 * Optional:
 *   TEST_USER_EMAIL_DOMAIN=example.com
 *
 * This script is intentionally CLI-only and idempotent. Existing accounts with
 * the generated email addresses are updated and their company memberships are
 * reactivated instead of duplicated.
 */

if (PHP_SAPI !== 'cli') {
    http_response_code(404);
    exit;
}

require_once __DIR__ . '/../config/db.php';

const TEST_ROLES = [
    'ADMINISTRATOR' => 'Administrator Test',
    'COMMERCIAL' => 'Commercial Test',
    'STOCK' => 'Stock Test',
    'ACCOUNTING' => 'Accounting Test',
];

function fail(string $message, int $exitCode = 1): never
{
    fwrite(STDERR, "Error: {$message}\n");
    exit($exitCode);
}

function tableExists(mysqli $db, string $table): bool
{
    $statement = $db->prepare(
        'SELECT 1 FROM information_schema.tables '
        . 'WHERE table_schema = DATABASE() AND table_name = ? LIMIT 1'
    );
    $statement->bind_param('s', $table);
    $statement->execute();
    $exists = $statement->get_result()->fetch_row() !== null;
    $statement->close();
    return $exists;
}

function columnExists(mysqli $db, string $table, string $column): bool
{
    $statement = $db->prepare(
        'SELECT 1 FROM information_schema.columns '
        . 'WHERE table_schema = DATABASE() AND table_name = ? '
        . 'AND column_name = ? LIMIT 1'
    );
    $statement->bind_param('ss', $table, $column);
    $statement->execute();
    $exists = $statement->get_result()->fetch_row() !== null;
    $statement->close();
    return $exists;
}

$companyId = filter_var(
    $argv[1] ?? null,
    FILTER_VALIDATE_INT,
    ['options' => ['min_range' => 1]]
);
if ($companyId === false) {
    fail('Pass a valid company ID: php backend/bin/seed_role_test_users.php <company_id>', 2);
}

$password = (string)($_ENV['TEST_USER_PASSWORD'] ?? getenv('TEST_USER_PASSWORD') ?: '');
if (strlen($password) < 12) {
    fail('Set TEST_USER_PASSWORD to a test password containing at least 12 characters.', 2);
}

$emailDomain = strtolower(trim(
    (string)($_ENV['TEST_USER_EMAIL_DOMAIN'] ?? getenv('TEST_USER_EMAIL_DOMAIN') ?: 'example.com')
));
if (!filter_var("accounting@{$emailDomain}", FILTER_VALIDATE_EMAIL)) {
    fail('TEST_USER_EMAIL_DOMAIN is not a valid email domain.', 2);
}

$db = db();

foreach (['users', 'companies', 'company_memberships'] as $requiredTable) {
    if (!tableExists($db, $requiredTable)) {
        fail("Missing table '{$requiredTable}'. Run the company workspace migrations first.");
    }
}
foreach (['display_name', 'default_company_id', 'account_status', 'approved_at'] as $requiredColumn) {
    if (!columnExists($db, 'users', $requiredColumn)) {
        fail("Missing users.{$requiredColumn}. Run all backend migrations first.");
    }
}

$companyStatement = $db->prepare(
    "SELECT id, organization_name FROM companies WHERE id = ? AND status = 'ACTIVE' LIMIT 1"
);
$companyStatement->bind_param('i', $companyId);
$companyStatement->execute();
$company = $companyStatement->get_result()->fetch_assoc();
$companyStatement->close();
if (!$company) {
    fail("Active company {$companyId} was not found.");
}

$passwordHash = password_hash($password, PASSWORD_DEFAULT);
if ($passwordHash === false) {
    fail('Could not hash the test password.');
}

$slugByRole = [
    'ADMINISTRATOR' => 'administrator',
    'COMMERCIAL' => 'commercial',
    'STOCK' => 'stock',
    'ACCOUNTING' => 'accounting',
];

$results = [];
$db->begin_transaction();

try {
    foreach (TEST_ROLES as $role => $displayName) {
        $slug = $slugByRole[$role];
        $email = "factorator.qa.{$slug}.c{$companyId}@{$emailDomain}";
        $organizationName = (string)$company['organization_name'];

        $findUser = $db->prepare('SELECT id FROM users WHERE email = ? LIMIT 1 FOR UPDATE');
        $findUser->bind_param('s', $email);
        $findUser->execute();
        $existing = $findUser->get_result()->fetch_assoc();
        $findUser->close();

        if ($existing) {
            $userId = (int)$existing['id'];
            $updateUser = $db->prepare(
                "UPDATE users SET display_name = ?, organization_name = ?, password_hash = ?, "
                . "email_verified_at = COALESCE(email_verified_at, NOW()), role = ?, "
                . "account_status = 'ACTIVE', approved_at = COALESCE(approved_at, NOW()), "
                . 'archived_at = NULL, archived_by = NULL, archive_reason = NULL, '
                . 'default_company_id = ? WHERE id = ?'
            );
            $updateUser->bind_param(
                'ssssii',
                $displayName,
                $organizationName,
                $passwordHash,
                $role,
                $companyId,
                $userId
            );
            $updateUser->execute();
            $updateUser->close();
            $operation = 'updated';
        } else {
            $insertUser = $db->prepare(
                "INSERT INTO users "
                . '(display_name, organization_name, fiscal_id, email, password_hash, '
                . 'email_verified_at, role, account_status, approved_at, default_company_id) '
                . "VALUES (?, ?, NULL, ?, ?, NOW(), ?, 'ACTIVE', NOW(), ?)"
            );
            $insertUser->bind_param(
                'sssssi',
                $displayName,
                $organizationName,
                $email,
                $passwordHash,
                $role,
                $companyId
            );
            $insertUser->execute();
            $userId = (int)$insertUser->insert_id;
            $insertUser->close();
            $operation = 'created';
        }

        $membership = $db->prepare(
            "INSERT INTO company_memberships "
            . '(company_id, user_id, role, status, is_owner, joined_at) '
            . "VALUES (?, ?, ?, 'ACTIVE', 0, NOW()) "
            . "ON DUPLICATE KEY UPDATE role = VALUES(role), status = 'ACTIVE', "
            . 'is_owner = 0, joined_at = COALESCE(joined_at, NOW()), '
            . 'suspended_at = NULL, revoked_at = NULL, version = version + 1'
        );
        $membership->bind_param('iis', $companyId, $userId, $role);
        $membership->execute();
        $membership->close();

        $results[] = [
            'email' => $email,
            'role' => $role,
            'user_id' => $userId,
            'operation' => $operation,
        ];
    }

    $db->commit();
} catch (Throwable $error) {
    $db->rollback();
    fail('No users were changed: ' . $error->getMessage());
}

fwrite(STDOUT, "Four active, verified role-test users are ready for company {$companyId}.\n\n");
foreach ($results as $result) {
    fwrite(
        STDOUT,
        sprintf(
            "%-14s %-48s user=%d (%s)\n",
            $result['role'],
            $result['email'],
            $result['user_id'],
            $result['operation']
        )
    );
}
fwrite(STDOUT, "\nAll four accounts use TEST_USER_PASSWORD. Remove them after testing.\n");
