<?php

declare(strict_types=1);

if (PHP_SAPI !== 'cli') { http_response_code(404); exit; }

require_once __DIR__ . '/../config/db.php';
require_once __DIR__ . '/../auth/role_helper.php';
require_once __DIR__ . '/../user/membership_service.php';

$conn = db();
$database = (string)$conn->query('SELECT DATABASE()')->fetch_row()[0];
if (!preg_match('/(?:^|_)(?:test|testing|local)(?:_|$)/i', $database)) {
    fwrite(STDERR, "REFUSED: company membership fixtures may only run in a local/test database; connected to {$database}." . PHP_EOL);
    exit(2);
}

$marker = bin2hex(random_bytes(5));
$emails = [
    "workspace-admin-a-{$marker}@example.test",
    "workspace-manager-a-{$marker}@example.test",
    "workspace-employee-{$marker}@example.test",
    "workspace-admin-b-{$marker}@example.test",
];
$failures = [];

function workspaceAssert(bool $condition, string $label, array &$failures): void
{
    echo ($condition ? 'PASS ' : 'FAIL ') . $label . PHP_EOL;
    if (!$condition) $failures[] = $label;
}

$conn->begin_transaction();
try {
    $password = password_hash('Workspace-integration-2026!', PASSWORD_DEFAULT);
    $insertUser = $conn->prepare("\n        INSERT INTO users\n            (display_name, organization_name, fiscal_id, email, password_hash, email_verified_at, role, account_status)\n        VALUES (?, ?, ?, ?, ?, NOW(), ?, 'ACTIVE')\n    ");
    $userIds = [];
    foreach ([
        ['Admin A', 'Workspace A', "WA{$marker}", $emails[0], 'ADMINISTRATOR'],
        ['Manager A', null, null, $emails[1], 'COMMERCIAL'],
        ['Employee', null, null, $emails[2], 'ADMINISTRATOR'],
        ['Admin B', 'Workspace B', "WB{$marker}", $emails[3], 'ADMINISTRATOR'],
    ] as [$displayName, $organization, $fiscalId, $email, $legacyRole]) {
        $insertUser->bind_param('ssssss', $displayName, $organization, $fiscalId, $email, $password, $legacyRole);
        $insertUser->execute();
        $userIds[] = (int)$conn->insert_id;
    }
    $insertUser->close();
    [$adminA, $managerA, $employee, $adminB] = $userIds;

    $insertCompany = $conn->prepare('INSERT INTO companies(id, owner_user_id, organization_name, fiscal_id) VALUES(?,?,?,?)');
    $companyAName = 'Workspace A'; $companyAFiscal = "WA{$marker}";
    $insertCompany->bind_param('iiss', $adminA, $adminA, $companyAName, $companyAFiscal); $insertCompany->execute();
    $companyBName = 'Workspace B'; $companyBFiscal = "WB{$marker}";
    $insertCompany->bind_param('iiss', $adminB, $adminB, $companyBName, $companyBFiscal); $insertCompany->execute();
    $insertCompany->close();

    $insertMembership = $conn->prepare("\n        INSERT INTO company_memberships(company_id,user_id,role,status,is_owner,version,joined_at)\n        VALUES(?,?,?,'ACTIVE',?,?,NOW())\n    ");
    $adminRole = 'ADMINISTRATOR'; $commercialRole = 'COMMERCIAL'; $owner = 1; $notOwner = 0; $version = 1;
    $insertMembership->bind_param('iisii', $adminA, $adminA, $adminRole, $owner, $version); $insertMembership->execute(); $adminAMembership = (int)$conn->insert_id;
    $insertMembership->bind_param('iisii', $adminA, $managerA, $adminRole, $notOwner, $version); $insertMembership->execute(); $managerAMembership = (int)$conn->insert_id;
    $insertMembership->bind_param('iisii', $adminA, $employee, $commercialRole, $notOwner, $version); $insertMembership->execute(); $employeeMembership = (int)$conn->insert_id;
    $insertMembership->bind_param('iisii', $adminB, $adminB, $adminRole, $owner, $version); $insertMembership->execute(); $adminBMembership = (int)$conn->insert_id;
    $insertMembership->close();

    $default = $conn->prepare('UPDATE users SET default_company_id=? WHERE id=?');
    $default->bind_param('ii', $adminA, $adminA); $default->execute();
    $default->bind_param('ii', $adminA, $managerA); $default->execute();
    $default->bind_param('ii', $adminA, $employee); $default->execute();
    $default->bind_param('ii', $adminB, $adminB); $default->execute();
    $default->close();

    $client = $conn->prepare("INSERT INTO clients(reference,type,name,email,user_id) VALUES('C000001','ENTREPRISE',?,?,?)");
    $clientAName = "Client A {$marker}"; $clientAEmail = "client-a-{$marker}@example.test";
    $client->bind_param('ssi', $clientAName, $clientAEmail, $adminA); $client->execute();
    $clientBName = "Client B {$marker}"; $clientBEmail = "client-b-{$marker}@example.test";
    $client->bind_param('ssi', $clientBName, $clientBEmail, $adminB); $client->execute();
    $client->close();

    $membership = requireActiveCompanyMembership($conn, $employee);
    workspaceAssert((int)$membership['company_id'] === $adminA, 'default company resolves for an employee', $failures);
    workspaceAssert(normalizeUserRole($membership['role']) === 'COMMERCIAL', 'membership role overrides the legacy users.role', $failures);
    try { requireActiveCompanyMembership($conn, $employee, $adminB); $foreignDenied = false; }
    catch (Throwable) { $foreignDenied = true; }
    workspaceAssert($foreignDenied, 'employee cannot select a company without membership', $failures);

    $employeePrincipal = buildCompanyPrincipal([
        'id' => $employee,
        'email' => $emails[2],
        'email_verified_at' => '2026-08-14 10:00:00',
    ], $membership);
    workspaceAssert($employeePrincipal->id === $adminA && authActorId($employeePrincipal) === $employee,
        'business scope and employee actor remain distinct', $failures);
    $clientCount = $conn->prepare('SELECT COUNT(*) FROM clients WHERE user_id=?');
    $tenantAlias = (int)$employeePrincipal->id;
    $clientCount->bind_param('i', $tenantAlias); $clientCount->execute();
    workspaceAssert((int)$clientCount->get_result()->fetch_row()[0] === 1,
        'employee tenant alias reads the shared company data', $failures);
    $clientCount->close();

    $refresh = $conn->prepare("\n        INSERT INTO auth_refresh_tokens(user_id,company_id,membership_id,token_hash,expires_at,user_agent_hash,ip_hash)\n        VALUES(?,?,?,?,DATE_ADD(NOW(),INTERVAL 1 DAY),?,?)\n    ");
    $uaHash = str_repeat('a', 64); $ipHash = str_repeat('b', 64);
    $tokenA = hash('sha256', "A-{$marker}");
    $refresh->bind_param('iiisss', $employee, $adminA, $employeeMembership, $tokenA, $uaHash, $ipHash); $refresh->execute();
    $tokenB = hash('sha256', "B-{$marker}");
    $refresh->bind_param('iiisss', $employee, $adminB, $adminBMembership, $tokenB, $uaHash, $ipHash); $refresh->execute();
    $refresh->close();

    $adminMembership = requireActiveCompanyMembership($conn, $managerA, $adminA);
    setActiveAuthPrincipal(buildCompanyPrincipal([
        'id' => $managerA,
        'email' => $emails[1],
        'email_verified_at' => '2026-08-14 10:00:00',
    ], $adminMembership));
    $result = updateCompanyMembershipRole($conn, $adminA, $managerA, $employeeMembership, 0, 'STOCK');
    workspaceAssert($result['changed'] && $result['role'] === 'STOCK', 'administrator changes a same-company membership role', $failures);
    $changed = $conn->query("SELECT role,version FROM company_memberships WHERE id={$employeeMembership}")->fetch_assoc();
    workspaceAssert($changed['role'] === 'STOCK' && (int)$changed['version'] === 2, 'role change increments the membership session version', $failures);
    $legacyRole = (string)$conn->query("SELECT role FROM users WHERE id={$employee}")->fetch_row()[0];
    workspaceAssert($legacyRole === 'ADMINISTRATOR', 'role change does not mutate the global identity role', $failures);
    $tokens = $conn->query("SELECT company_id,revoked_at FROM auth_refresh_tokens WHERE user_id={$employee} ORDER BY company_id")->fetch_all(MYSQLI_ASSOC);
    workspaceAssert(!empty($tokens[0]['revoked_at']) && empty($tokens[1]['revoked_at']), 'role change revokes only the target company session', $failures);
    $audit = $conn->query("SELECT tenant_id,actor_id,entity_id FROM app_audit_log WHERE action='MEMBERSHIP.ROLE_CHANGED' AND entity_id='{$employeeMembership}' ORDER BY id DESC LIMIT 1")->fetch_assoc();
    workspaceAssert((int)$audit['tenant_id'] === $adminA && (int)$audit['actor_id'] === $managerA,
        'membership audit records the company and real administrator actor', $failures);

    try { updateCompanyMembershipRole($conn, $adminA, $managerA, $adminBMembership, 0, 'STOCK'); $foreignUpdateDenied = false; }
    catch (CompanyMembershipException $error) { $foreignUpdateDenied = $error->httpStatus === 404; }
    workspaceAssert($foreignUpdateDenied, 'foreign membership IDs are hidden and cannot be changed', $failures);

    try { updateCompanyMembershipRole($conn, $adminA, $managerA, $adminAMembership, 0, 'COMMERCIAL'); $ownerDemotionDenied = false; }
    catch (CompanyMembershipException $error) { $ownerDemotionDenied = $error->httpStatus === 409; }
    workspaceAssert($ownerDemotionDenied, 'company owner cannot be demoted from administrator', $failures);

    $suspend = $conn->prepare("UPDATE company_memberships SET status='SUSPENDED' WHERE id=?");
    $suspend->bind_param('i', $employeeMembership); $suspend->execute(); $suspend->close();
    try { requireActiveCompanyMembership($conn, $employee, $adminA); $suspendedDenied = false; }
    catch (Throwable) { $suspendedDenied = true; }
    workspaceAssert($suspendedDenied, 'suspended membership cannot authenticate', $failures);
} finally {
    $conn->rollback();
}

$placeholders = implode(',', array_fill(0, count($emails), '?'));
$cleanup = $conn->prepare("SELECT COUNT(*) FROM users WHERE email IN ({$placeholders})");
$cleanup->bind_param('ssss', ...$emails);
$cleanup->execute();
workspaceAssert((int)$cleanup->get_result()->fetch_row()[0] === 0, 'all company membership fixtures rolled back', $failures);
$cleanup->close();

if ($failures !== []) exit(1);
echo "Company membership integration tests passed on {$database}." . PHP_EOL;
