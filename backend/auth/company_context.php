<?php

declare(strict_types=1);

/**
 * Store the authenticated actor and active company for the current request.
 * Business endpoints will migrate from user_id to tenant_id in stages, while
 * security and audit code can use the actor immediately.
 */
function setActiveAuthPrincipal(object $principal): void
{
    $GLOBALS['active_auth_principal'] = $principal;
}

function activeAuthPrincipal(): ?object
{
    $principal = $GLOBALS['active_auth_principal'] ?? null;
    return is_object($principal) ? $principal : null;
}

function authActorId(object $principal): int
{
    return (int)($principal->actor_id ?? $principal->id ?? 0);
}

function authTenantId(object $principal): int
{
    return (int)($principal->tenant_id ?? $principal->company_id ?? $principal->id ?? 0);
}

function authMembershipId(object $principal): int
{
    return (int)($principal->membership_id ?? 0);
}

function buildCompanyPrincipal(array $account, array $membership): object
{
    $actorId = (int)($account['id'] ?? $membership['user_id'] ?? 0);
    $companyId = (int)($membership['company_id'] ?? 0);
    return (object)[
        // Transitional tenant alias for existing business queries.
        'id' => $companyId,
        'actor_id' => $actorId,
        'email' => (string)($account['email'] ?? ''),
        'email_verified' => !empty($account['email_verified_at']),
        'tenant_id' => $companyId,
        'company_id' => $companyId,
        'membership_id' => (int)($membership['membership_id'] ?? 0),
        'membership_version' => (int)($membership['membership_version'] ?? 1),
        'membership_status' => (string)($membership['membership_status'] ?? ''),
        'is_owner' => (int)($membership['is_owner'] ?? 0) === 1,
        'role' => function_exists('normalizeUserRole')
            ? normalizeUserRole($membership['role'] ?? null)
            : strtoupper(trim((string)($membership['role'] ?? 'UNAUTHORIZED'))),
    ];
}

function companyMembershipForUser(
    mysqli $conn,
    int $userId,
    ?int $companyId = null,
    bool $forUpdate = false
): ?array {
    if ($userId <= 0) {
        return null;
    }

    if ($companyId === null || $companyId <= 0) {
        $defaultStmt = $conn->prepare('SELECT default_company_id FROM users WHERE id = ? LIMIT 1');
        $defaultStmt->bind_param('i', $userId);
        $defaultStmt->execute();
        $defaultCompanyId = (int)($defaultStmt->get_result()->fetch_assoc()['default_company_id'] ?? 0);
        $defaultStmt->close();

        if ($defaultCompanyId > 0) {
            $companyId = $defaultCompanyId;
        } else {
            $countStmt = $conn->prepare("\n                SELECT MIN(company_id) AS company_id, COUNT(*) AS membership_count\n                FROM company_memberships\n                WHERE user_id = ? AND status = 'ACTIVE'\n            ");
            $countStmt->bind_param('i', $userId);
            $countStmt->execute();
            $membershipSummary = $countStmt->get_result()->fetch_assoc() ?: [];
            $countStmt->close();
            if ((int)($membershipSummary['membership_count'] ?? 0) !== 1) {
                return null;
            }
            $companyId = (int)$membershipSummary['company_id'];
        }
    }

    $whereCompany = ' AND cm.company_id = ?';
    $locking = $forUpdate ? ' FOR UPDATE' : '';
    $stmt = $conn->prepare("\n        SELECT\n            cm.id AS membership_id,\n            cm.company_id,\n            cm.user_id,\n            cm.role,\n            cm.status AS membership_status,\n            cm.is_owner,\n            cm.version AS membership_version,\n            cm.joined_at,\n            c.owner_user_id,\n            c.organization_name,\n            c.fiscal_id,\n            c.phone,\n            c.fax,\n            c.address,\n            c.website,\n            c.fodec,\n            c.status AS company_status\n        FROM company_memberships cm\n        JOIN companies c ON c.id = cm.company_id\n        WHERE cm.user_id = ?{$whereCompany}\n        ORDER BY cm.is_owner DESC, cm.id ASC\n        LIMIT 1{$locking}\n    ");
    $stmt->bind_param('ii', $userId, $companyId);
    $stmt->execute();
    $membership = $stmt->get_result()->fetch_assoc() ?: null;
    $stmt->close();

    return $membership;
}

function requireActiveCompanyMembership(
    mysqli $conn,
    int $userId,
    ?int $companyId = null,
    bool $forUpdate = false
): array {
    $membership = companyMembershipForUser($conn, $userId, $companyId, $forUpdate);
    if (!$membership) {
        throw new RuntimeException('No company membership is available for this account.');
    }
    if (($membership['membership_status'] ?? '') !== 'ACTIVE') {
        throw new RuntimeException('This company membership is not active.');
    }
    if (($membership['company_status'] ?? '') !== 'ACTIVE') {
        throw new RuntimeException('This company workspace is archived.');
    }

    return $membership;
}

function createOwnerCompany(mysqli $conn, int $userId, array $profile): array
{
    if ($userId <= 0) {
        throw new InvalidArgumentException('A valid owner user is required.');
    }

    $organizationName = trim((string)($profile['organization_name'] ?? ''));
    if ($organizationName === '') {
        $organizationName = 'Workspace ' . $userId;
    }
    $fiscalId = trim((string)($profile['fiscal_id'] ?? '')) ?: null;
    $phone = trim((string)($profile['phone'] ?? '')) ?: null;
    $fax = trim((string)($profile['fax'] ?? '')) ?: null;
    $address = trim((string)($profile['address'] ?? '')) ?: null;
    $website = trim((string)($profile['website'] ?? '')) ?: null;
    $fodec = !empty($profile['fodec']) ? 1 : 0;

    $companyStmt = $conn->prepare('
        INSERT INTO companies
            (id, owner_user_id, organization_name, fiscal_id, phone, fax, address, website, fodec)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
    ');
    $companyStmt->bind_param(
        'iissssssi',
        $userId,
        $userId,
        $organizationName,
        $fiscalId,
        $phone,
        $fax,
        $address,
        $website,
        $fodec
    );
    $companyStmt->execute();
    $companyStmt->close();

    $role = 'ADMINISTRATOR';
    $membershipStmt = $conn->prepare("\n        INSERT INTO company_memberships\n            (company_id, user_id, role, status, is_owner, joined_at)\n        VALUES (?, ?, ?, 'ACTIVE', 1, NOW())\n    ");
    $membershipStmt->bind_param('iis', $userId, $userId, $role);
    $membershipStmt->execute();
    $membershipId = (int)$membershipStmt->insert_id;
    $membershipStmt->close();

    $membership = companyMembershipForUser($conn, $userId, $userId);
    if (!$membership || (int)$membership['membership_id'] !== $membershipId) {
        throw new RuntimeException('Could not initialize the owner membership.');
    }

    return $membership;
}

function companyPayload(array $membership): array
{
    $fodec = (int)($membership['fodec'] ?? 0);
    return [
        'id' => (int)$membership['company_id'],
        'organization_name' => (string)($membership['organization_name'] ?? ''),
        'fiscal_id' => (string)($membership['fiscal_id'] ?? ''),
        'phone' => (string)($membership['phone'] ?? ''),
        'fax' => (string)($membership['fax'] ?? ''),
        'address' => (string)($membership['address'] ?? ''),
        'website' => (string)($membership['website'] ?? ''),
        'fodec' => $fodec,
        'is_fodec' => $fodec === 1,
        'status' => (string)($membership['company_status'] ?? ''),
    ];
}

function membershipPayload(array $membership, ?callable $normalizeRole = null): array
{
    $role = (string)($membership['role'] ?? 'UNAUTHORIZED');
    if ($normalizeRole !== null) {
        $role = (string)$normalizeRole($role);
    }

    return [
        'id' => (int)$membership['membership_id'],
        'tenant_id' => (int)$membership['company_id'],
        'company_id' => (int)$membership['company_id'],
        'role' => $role,
        'status' => (string)($membership['membership_status'] ?? ''),
        'is_owner' => (int)($membership['is_owner'] ?? 0) === 1,
        'version' => (int)($membership['membership_version'] ?? 1),
        'joined_at' => $membership['joined_at'] ?? null,
    ];
}
