<?php

declare(strict_types=1);

if (PHP_SAPI !== 'cli') { http_response_code(404); exit; }

require_once __DIR__ . '/../config/db.php';
require_once __DIR__ . '/../user/invitation_service.php';
require_once __DIR__ . '/../user/membership_service.php';

$conn = db();
$database = (string)$conn->query('SELECT DATABASE()')->fetch_row()[0];
if (!preg_match('/(?:^|_)(?:test|testing|local)(?:_|$)/i', $database)) {
    fwrite(
        STDERR,
        "REFUSED: company invitation fixtures may only run in a local/test database; connected to {$database}." . PHP_EOL
    );
    exit(2);
}

// The local integration path intentionally exercises a manually shared
// development link. Unlike an emailed production link, it does not prove
// control of the invited mailbox.
$originalAppEnvironment = $_ENV['APP_ENV'] ?? null;
$_ENV['APP_ENV'] = 'development';

$marker = bin2hex(random_bytes(5));
$failures = [];
$emails = [
    'invite-owner-a-' . $marker . '@example.test',
    'invite-admin-a-' . $marker . '@example.test',
    'invite-owner-b-' . $marker . '@example.test',
    'invite-employee-' . $marker . '@example.test',
    'invite-revoked-' . $marker . '@example.test',
    'invite-expired-' . $marker . '@example.test',
];

function invitationLifecycleAssert(bool $condition, string $label, array &$failures): void
{
    echo ($condition ? 'PASS ' : 'FAIL ') . $label . PHP_EOL;
    if (!$condition) $failures[] = $label;
}

function invitationLifecycleInvitationErrorCode(callable $operation): string
{
    try {
        $operation();
    } catch (CompanyInvitationException $error) {
        return $error->errorCode;
    }
    return 'NO_ERROR';
}

function invitationLifecycleMembershipErrorCode(callable $operation): string
{
    try {
        $operation();
    } catch (CompanyMembershipException $error) {
        return $error->errorCode;
    }
    return 'NO_ERROR';
}

function invitationLifecycleInsertRefreshSession(
    mysqli $conn,
    int $userId,
    int $companyId,
    int $membershipId,
    string $marker
): string {
    $tokenHash = hash('sha256', $marker . '-' . bin2hex(random_bytes(8)));
    $userAgentHash = str_repeat('a', 64);
    $ipHash = str_repeat('b', 64);
    $stmt = $conn->prepare("\n        INSERT INTO auth_refresh_tokens\n            (user_id, company_id, membership_id, token_hash, expires_at, user_agent_hash, ip_hash)\n        VALUES (?, ?, ?, ?, DATE_ADD(NOW(), INTERVAL 1 DAY), ?, ?)\n    ");
    $stmt->bind_param(
        'iiisss',
        $userId,
        $companyId,
        $membershipId,
        $tokenHash,
        $userAgentHash,
        $ipHash
    );
    $stmt->execute();
    $stmt->close();
    return $tokenHash;
}

function invitationLifecycleSessionIsRevoked(mysqli $conn, string $tokenHash): bool
{
    $stmt = $conn->prepare('SELECT revoked_at FROM auth_refresh_tokens WHERE token_hash = ? LIMIT 1');
    $stmt->bind_param('s', $tokenHash);
    $stmt->execute();
    $row = $stmt->get_result()->fetch_assoc();
    $stmt->close();
    return $row && $row['revoked_at'] !== null;
}

$conn->begin_transaction();
try {
    $passwordHash = password_hash('Fixture-owner-2026!', PASSWORD_DEFAULT);
    $insertUser = $conn->prepare("\n        INSERT INTO users\n            (display_name, organization_name, fiscal_id, email, password_hash, email_verified_at, role, account_status)\n        VALUES (?, ?, ?, ?, ?, NOW(), ?, 'ACTIVE')\n    ");
    $userIds = [];
    foreach ([
        ['Owner A', 'Invitation Workspace A', 'IA' . $marker, $emails[0], 'ADMINISTRATOR'],
        ['Admin A', 'Invitation Workspace A', null, $emails[1], 'ADMINISTRATOR'],
        ['Owner B', 'Invitation Workspace B', 'IB' . $marker, $emails[2], 'ADMINISTRATOR'],
    ] as [$displayName, $organizationName, $fiscalId, $email, $role]) {
        $insertUser->bind_param(
            'ssssss',
            $displayName,
            $organizationName,
            $fiscalId,
            $email,
            $passwordHash,
            $role
        );
        $insertUser->execute();
        $userIds[] = (int)$conn->insert_id;
    }
    $insertUser->close();
    [$ownerA, $adminA, $ownerB] = $userIds;

    $insertCompany = $conn->prepare(
        'INSERT INTO companies(id, owner_user_id, organization_name, fiscal_id) VALUES(?,?,?,?)'
    );
    $companyAName = 'Invitation Workspace A';
    $companyAFiscalId = 'IA' . $marker;
    $insertCompany->bind_param('iiss', $ownerA, $ownerA, $companyAName, $companyAFiscalId);
    $insertCompany->execute();
    $companyBName = 'Invitation Workspace B';
    $companyBFiscalId = 'IB' . $marker;
    $insertCompany->bind_param('iiss', $ownerB, $ownerB, $companyBName, $companyBFiscalId);
    $insertCompany->execute();
    $insertCompany->close();

    $insertMembership = $conn->prepare("\n        INSERT INTO company_memberships\n            (company_id, user_id, role, status, is_owner, version, joined_at)\n        VALUES (?, ?, ?, 'ACTIVE', ?, 1, NOW())\n    ");
    $administratorRole = 'ADMINISTRATOR';
    $ownerFlag = 1;
    $memberFlag = 0;
    $insertMembership->bind_param('iisi', $ownerA, $ownerA, $administratorRole, $ownerFlag);
    $insertMembership->execute();
    $ownerAMembershipId = (int)$conn->insert_id;
    $insertMembership->bind_param('iisi', $ownerA, $adminA, $administratorRole, $memberFlag);
    $insertMembership->execute();
    $adminAMembershipId = (int)$conn->insert_id;
    $insertMembership->bind_param('iisi', $ownerB, $ownerB, $administratorRole, $ownerFlag);
    $insertMembership->execute();
    $ownerBMembershipId = (int)$conn->insert_id;
    $insertMembership->close();

    $setDefaultCompany = $conn->prepare('UPDATE users SET default_company_id = ? WHERE id = ?');
    $setDefaultCompany->bind_param('ii', $ownerA, $ownerA);
    $setDefaultCompany->execute();
    $setDefaultCompany->bind_param('ii', $ownerA, $adminA);
    $setDefaultCompany->execute();
    $setDefaultCompany->bind_param('ii', $ownerB, $ownerB);
    $setDefaultCompany->execute();
    $setDefaultCompany->close();

    $columns = $conn->query('SHOW COLUMNS FROM company_invitations')->fetch_all(MYSQLI_ASSOC);
    $columnNames = array_column($columns, 'Field');
    invitationLifecycleAssert(
        in_array('token_hash', $columnNames, true) && !in_array('token', $columnNames, true),
        'invitation storage exposes only a token hash column',
        $failures
    );

    $acceptedInvite = createCompanyInvitation(
        $conn,
        $ownerA,
        $ownerA,
        $emails[3],
        'Invited Employee',
        'STOCK',
        72
    );
    $acceptedToken = (string)$acceptedInvite['token'];
    $acceptedInvitationId = (int)$acceptedInvite['id'];
    $storedToken = $conn->query(
        "SELECT token_hash FROM company_invitations WHERE id={$acceptedInvitationId}"
    )->fetch_assoc();
    invitationLifecycleAssert(
        is_array($storedToken)
            && hash_equals(hash('sha256', $acceptedToken), (string)$storedToken['token_hash'])
            && !hash_equals($acceptedToken, (string)$storedToken['token_hash']),
        'raw invitation token is returned once but only its SHA-256 hash is stored',
        $failures
    );
    $accepted = acceptCompanyInvitation(
        $conn,
        $acceptedToken,
        'Employee-access-2026!',
        'Employee-access-2026!',
        'Invited Employee',
        '+216 20123456'
    );
    $employeeId = (int)$accepted['user_id'];
    $employeeMembershipId = (int)$accepted['membership_id'];
    $acceptedRow = $conn->query("\n        SELECT\n            u.email, u.display_name, u.default_company_id, u.email_verified_at,\n            cm.company_id, cm.role, cm.status, cm.version, cm.is_owner,\n            ci.status AS invitation_status, ci.accepted_by, ci.accepted_at\n        FROM users u\n        JOIN company_memberships cm ON cm.user_id = u.id AND cm.id = {$employeeMembershipId}\n        JOIN company_invitations ci ON ci.id = {$acceptedInvitationId}\n        WHERE u.id = {$employeeId}\n    ")->fetch_assoc();
    invitationLifecycleAssert(
        is_array($acceptedRow)
            && (int)$acceptedRow['company_id'] === $ownerA
            && (int)$acceptedRow['default_company_id'] === $ownerA
            && $acceptedRow['status'] === 'ACTIVE'
            && $acceptedRow['role'] === 'STOCK'
            && (int)$acceptedRow['version'] === 1
            && (int)$acceptedRow['is_owner'] === 0
            && $acceptedRow['email_verified_at'] === null,
        'manual development acceptance creates an actor with an ACTIVE same-company membership and default company',
        $failures
    );
    invitationLifecycleAssert(
        is_array($acceptedRow)
            && $acceptedRow['invitation_status'] === 'ACCEPTED'
            && (int)$acceptedRow['accepted_by'] === $employeeId
            && $acceptedRow['accepted_at'] !== null,
        'acceptance links the consumed invitation to the new actor',
        $failures
    );
    $rawTokenNeedle = '%' . $acceptedToken . '%';
    $rawTokenAudit = $conn->prepare("\n        SELECT COUNT(*)\n        FROM app_audit_log\n        WHERE tenant_id = ?\n          AND action LIKE 'MEMBERSHIP.INVITATION_%'\n          AND (before_values LIKE ? OR after_values LIKE ?)\n    ");
    $rawTokenAudit->bind_param('iss', $ownerA, $rawTokenNeedle, $rawTokenNeedle);
    $rawTokenAudit->execute();
    $rawTokenAuditCount = (int)$rawTokenAudit->get_result()->fetch_row()[0];
    $rawTokenAudit->close();
    invitationLifecycleAssert(
        $rawTokenAuditCount === 0,
        'raw invitation token is absent from creation and acceptance audit records',
        $failures
    );
    invitationLifecycleAssert(
        invitationLifecycleInvitationErrorCode(static fn() => acceptCompanyInvitation(
            $conn,
            $acceptedToken,
            'Employee-access-2026!',
            'Employee-access-2026!',
            'Invited Employee'
        )) === 'INVITATION_UNAVAILABLE',
        'an accepted invitation token is single-use',
        $failures
    );
    $acceptedCounts = $conn->query("\n        SELECT\n            (SELECT COUNT(*) FROM users WHERE email = '{$emails[3]}') AS users_count,\n            (SELECT COUNT(*) FROM company_memberships WHERE company_id = {$ownerA} AND user_id = {$employeeId}) AS memberships_count\n    ")->fetch_assoc();
    invitationLifecycleAssert(
        (int)$acceptedCounts['users_count'] === 1 && (int)$acceptedCounts['memberships_count'] === 1,
        'reusing an accepted token creates no duplicate user or membership',
        $failures
    );
    invitationLifecycleAssert(
        invitationLifecycleInvitationErrorCode(static fn() => createCompanyInvitation(
            $conn,
            $ownerB,
            $ownerB,
            $emails[1],
            'Foreign Existing Account',
            'COMMERCIAL',
            72
        )) === 'INVITATION_UNAVAILABLE',
        'an identity belonging only to another company cannot be invited',
        $failures
    );

    $revokedInvite = createCompanyInvitation(
        $conn,
        $ownerB,
        $ownerB,
        $emails[4],
        'Revoked Employee',
        'COMMERCIAL',
        72
    );
    invitationLifecycleAssert(
        invitationLifecycleInvitationErrorCode(static fn() => revokeCompanyInvitation(
            $conn,
            $ownerA,
            $ownerA,
            (int)$revokedInvite['id']
        )) === 'INVITATION_NOT_FOUND',
        'foreign invitation IDs are hidden from other companies',
        $failures
    );
    $revoked = revokeCompanyInvitation($conn, $ownerB, $ownerB, (int)$revokedInvite['id']);
    invitationLifecycleAssert(
        $revoked['changed'] === true && $revoked['status'] === 'REVOKED',
        'a pending invitation can be revoked',
        $failures
    );
    invitationLifecycleAssert(
        invitationLifecycleInvitationErrorCode(static fn() => acceptCompanyInvitation(
            $conn,
            (string)$revokedInvite['token'],
            'Revoked-access-2026!',
            'Revoked-access-2026!',
            'Revoked Employee'
        )) === 'INVITATION_UNAVAILABLE',
        'a revoked invitation token cannot be accepted',
        $failures
    );

    $expiredInvite = createCompanyInvitation(
        $conn,
        $ownerA,
        $ownerA,
        $emails[5],
        'Expired Employee',
        'ACCOUNTING',
        1
    );
    $expireInvitation = $conn->prepare(
        'UPDATE company_invitations SET expires_at = DATE_SUB(NOW(), INTERVAL 1 MINUTE) WHERE id = ?'
    );
    $expiredInvitationId = (int)$expiredInvite['id'];
    $expireInvitation->bind_param('i', $expiredInvitationId);
    $expireInvitation->execute();
    $expireInvitation->close();
    invitationLifecycleAssert(
        invitationLifecycleInvitationErrorCode(static fn() => acceptCompanyInvitation(
            $conn,
            (string)$expiredInvite['token'],
            'Expired-access-2026!',
            'Expired-access-2026!',
            'Expired Employee'
        )) === 'INVITATION_UNAVAILABLE',
        'an expired invitation token cannot be accepted',
        $failures
    );
    $revokeExpired = revokeCompanyInvitation($conn, $ownerA, $ownerA, $expiredInvitationId);
    invitationLifecycleAssert(
        $revokeExpired['changed'] === false && $revokeExpired['status'] === 'EXPIRED',
        'an expired pending invitation is finalized as EXPIRED instead of revoked',
        $failures
    );

    invitationLifecycleAssert(
        invitationLifecycleMembershipErrorCode(static fn() => updateCompanyMembershipStatus(
            $conn,
            $ownerA,
            $adminA,
            $ownerAMembershipId,
            0,
            'SUSPENDED'
        )) === 'OWNER_IMMUTABLE',
        'company owner membership cannot be suspended',
        $failures
    );
    invitationLifecycleAssert(
        invitationLifecycleMembershipErrorCode(static fn() => assertCompanyKeepsActiveAdministrator(
            $conn,
            $ownerB,
            $ownerBMembershipId
        )) === 'LAST_ADMIN_REQUIRED',
        'last-active-administrator guard rejects removal of the only administrator',
        $failures
    );
    invitationLifecycleAssert(
        invitationLifecycleMembershipErrorCode(static fn() => updateCompanyMembershipStatus(
            $conn,
            $ownerA,
            $employeeId,
            $employeeMembershipId,
            0,
            'SUSPENDED'
        )) === 'SELF_PROTECTED',
        'a member cannot suspend their own membership',
        $failures
    );

    $secondaryRole = 'STOCK';
    $insertSecondaryMembership = $conn->prepare("\n        INSERT INTO company_memberships\n            (company_id, user_id, role, status, is_owner, version, invited_by, joined_at)\n        VALUES (?, ?, ?, 'ACTIVE', 0, 1, ?, NOW())\n    ");
    $insertSecondaryMembership->bind_param('iisi', $ownerB, $employeeId, $secondaryRole, $ownerB);
    $insertSecondaryMembership->execute();
    $employeeCompanyBMembershipId = (int)$conn->insert_id;
    $insertSecondaryMembership->close();
    invitationLifecycleAssert(
        invitationLifecycleMembershipErrorCode(static fn() => updateCompanyMembershipStatus(
            $conn,
            $ownerA,
            $ownerA,
            $employeeCompanyBMembershipId,
            0,
            'SUSPENDED'
        )) === 'MEMBERSHIP_NOT_FOUND',
        'foreign membership IDs are hidden from other companies',
        $failures
    );

    $companyAToken1 = invitationLifecycleInsertRefreshSession(
        $conn,
        $employeeId,
        $ownerA,
        $employeeMembershipId,
        'company-a-one-' . $marker
    );
    $companyBToken = invitationLifecycleInsertRefreshSession(
        $conn,
        $employeeId,
        $ownerB,
        $employeeCompanyBMembershipId,
        'company-b-' . $marker
    );
    $suspended = updateCompanyMembershipStatus(
        $conn,
        $ownerA,
        $ownerA,
        $employeeMembershipId,
        0,
        'SUSPENDED'
    );
    $suspendedRow = $conn->query(
        "SELECT status, version, suspended_at FROM company_memberships WHERE id={$employeeMembershipId}"
    )->fetch_assoc();
    $defaultAfterSuspend = (int)$conn->query(
        "SELECT default_company_id FROM users WHERE id={$employeeId}"
    )->fetch_row()[0];
    invitationLifecycleAssert(
        $suspended['changed'] === true
            && $suspendedRow['status'] === 'SUSPENDED'
            && (int)$suspendedRow['version'] === 2
            && $suspendedRow['suspended_at'] !== null,
        'suspension changes status and increments the membership version',
        $failures
    );
    invitationLifecycleAssert(
        invitationLifecycleSessionIsRevoked($conn, $companyAToken1)
            && !invitationLifecycleSessionIsRevoked($conn, $companyBToken),
        'suspension revokes only sessions for the affected company',
        $failures
    );
    invitationLifecycleAssert(
        $defaultAfterSuspend === $ownerB,
        'suspension moves the actor default to another active company',
        $failures
    );

    $companyAToken2 = invitationLifecycleInsertRefreshSession(
        $conn,
        $employeeId,
        $ownerA,
        $employeeMembershipId,
        'company-a-two-' . $marker
    );
    $reactivated = updateCompanyMembershipStatus(
        $conn,
        $ownerA,
        $ownerA,
        $employeeMembershipId,
        0,
        'ACTIVE'
    );
    $reactivatedRow = $conn->query(
        "SELECT status, version, suspended_at FROM company_memberships WHERE id={$employeeMembershipId}"
    )->fetch_assoc();
    invitationLifecycleAssert(
        $reactivated['changed'] === true
            && $reactivatedRow['status'] === 'ACTIVE'
            && (int)$reactivatedRow['version'] === 3
            && $reactivatedRow['suspended_at'] === null,
        'reactivation restores ACTIVE status and increments the membership version',
        $failures
    );
    invitationLifecycleAssert(
        invitationLifecycleSessionIsRevoked($conn, $companyAToken2)
            && !invitationLifecycleSessionIsRevoked($conn, $companyBToken),
        'reactivation also invalidates stale sessions only in the affected company',
        $failures
    );

    $companyAToken3 = invitationLifecycleInsertRefreshSession(
        $conn,
        $employeeId,
        $ownerA,
        $employeeMembershipId,
        'company-a-three-' . $marker
    );
    $removed = updateCompanyMembershipStatus(
        $conn,
        $ownerA,
        $ownerA,
        $employeeMembershipId,
        0,
        'REVOKED'
    );
    $removedRow = $conn->query(
        "SELECT status, version, revoked_at FROM company_memberships WHERE id={$employeeMembershipId}"
    )->fetch_assoc();
    invitationLifecycleAssert(
        $removed['changed'] === true
            && $removedRow['status'] === 'REVOKED'
            && (int)$removedRow['version'] === 4
            && $removedRow['revoked_at'] !== null,
        'removal revokes the membership and increments its version',
        $failures
    );
    invitationLifecycleAssert(
        invitationLifecycleSessionIsRevoked($conn, $companyAToken3)
            && !invitationLifecycleSessionIsRevoked($conn, $companyBToken),
        'removal revokes only sessions for the removed company membership',
        $failures
    );
    invitationLifecycleAssert(
        invitationLifecycleMembershipErrorCode(static fn() => updateCompanyMembershipStatus(
            $conn,
            $ownerA,
            $ownerA,
            $employeeMembershipId,
            0,
            'ACTIVE'
        )) === 'MEMBERSHIP_REVOKED',
        'a removed membership cannot be reactivated',
        $failures
    );

    $returningInvite = createCompanyInvitation(
        $conn,
        $ownerA,
        $ownerA,
        $emails[3],
        'Returning Employee',
        'ACCOUNTING',
        72
    );
    $wrongExistingPasswordCode = invitationLifecycleInvitationErrorCode(
        static fn() => acceptCompanyInvitation(
            $conn,
            (string)$returningInvite['token'],
            'Wrong-credential-2026!',
            'Wrong-credential-2026!',
            'Returning Employee'
        )
    );
    $stillRevoked = $conn->query(
        "SELECT status, version FROM company_memberships WHERE id={$employeeMembershipId}"
    )->fetch_assoc();
    $returningInvitationStatus = (string)$conn->query(
        'SELECT status FROM company_invitations WHERE id=' . (int)$returningInvite['id']
    )->fetch_row()[0];
    invitationLifecycleAssert(
        $wrongExistingPasswordCode !== 'NO_ERROR'
            && $stillRevoked['status'] === 'REVOKED'
            && (int)$stillRevoked['version'] === 4
            && $returningInvitationStatus === 'PENDING',
        're-invitation verifies the existing actor password before changing membership state',
        $failures
    );
    $returned = acceptCompanyInvitation(
        $conn,
        (string)$returningInvite['token'],
        'Employee-access-2026!',
        'Employee-access-2026!',
        'Returning Employee'
    );
    $returnedRow = $conn->query("\n        SELECT\n            u.email_verified_at,\n            cm.company_id, cm.status, cm.role, cm.version, cm.revoked_at,\n            ci.status AS invitation_status, ci.accepted_by\n        FROM users u\n        JOIN company_memberships cm ON cm.id = {$employeeMembershipId} AND cm.user_id = u.id\n        JOIN company_invitations ci ON ci.id = " . (int)$returningInvite['id'] . "\n        WHERE u.id = {$employeeId}\n    ")->fetch_assoc();
    $returningUserCount = (int)$conn->query(
        "SELECT COUNT(*) FROM users WHERE email='{$emails[3]}'"
    )->fetch_row()[0];
    invitationLifecycleAssert(
        (int)$returned['user_id'] === $employeeId
            && (int)$returned['membership_id'] === $employeeMembershipId
            && (int)$returnedRow['company_id'] === $ownerA
            && $returnedRow['status'] === 'ACTIVE'
            && $returnedRow['role'] === 'ACCOUNTING'
            && (int)$returnedRow['version'] === 5
            && $returnedRow['revoked_at'] === null
            && $returnedRow['invitation_status'] === 'ACCEPTED'
            && (int)$returnedRow['accepted_by'] === $employeeId
            && $returnedRow['email_verified_at'] === null
            && $returningUserCount === 1,
        'a valid same-company re-invitation reactivates the existing actor and membership without duplication',
        $failures
    );

    // Keep otherwise-unused fixture IDs explicit so accidental setup drift is visible.
    invitationLifecycleAssert(
        $adminAMembershipId > 0 && $ownerBMembershipId > 0,
        'administrator safety fixtures were created',
        $failures
    );
} catch (Throwable $error) {
    $label = 'unexpected lifecycle test error: ' . get_class($error) . ': ' . $error->getMessage();
    echo 'FAIL ' . $label . PHP_EOL;
    $failures[] = $label;
} finally {
    $conn->rollback();
    if ($originalAppEnvironment === null) {
        unset($_ENV['APP_ENV']);
    } else {
        $_ENV['APP_ENV'] = $originalAppEnvironment;
    }
}

$cleanupPattern = '%-' . $marker . '@example.test';
$cleanupUsers = $conn->prepare('SELECT COUNT(*) FROM users WHERE email LIKE ?');
$cleanupUsers->bind_param('s', $cleanupPattern);
$cleanupUsers->execute();
$remainingUsers = (int)$cleanupUsers->get_result()->fetch_row()[0];
$cleanupUsers->close();
$cleanupInvitations = $conn->prepare('SELECT COUNT(*) FROM company_invitations WHERE email LIKE ?');
$cleanupInvitations->bind_param('s', $cleanupPattern);
$cleanupInvitations->execute();
$remainingInvitations = (int)$cleanupInvitations->get_result()->fetch_row()[0];
$cleanupInvitations->close();
$companyFiscalPattern = 'I_' . $marker;
$cleanupCompanies = $conn->prepare('SELECT COUNT(*) FROM companies WHERE fiscal_id LIKE ?');
$cleanupCompanies->bind_param('s', $companyFiscalPattern);
$cleanupCompanies->execute();
$remainingCompanies = (int)$cleanupCompanies->get_result()->fetch_row()[0];
$cleanupCompanies->close();
invitationLifecycleAssert(
    $remainingUsers === 0 && $remainingInvitations === 0 && $remainingCompanies === 0,
    'all invitation lifecycle fixtures rolled back',
    $failures
);

if ($failures !== []) exit(1);
echo "Company invitation lifecycle tests passed on {$database}." . PHP_EOL;
