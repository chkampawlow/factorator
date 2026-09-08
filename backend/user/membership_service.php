<?php

declare(strict_types=1);

require_once __DIR__ . '/../auth/role_helper.php';
require_once __DIR__ . '/../config/audit.php';

final class CompanyMembershipException extends RuntimeException
{
    public function __construct(
        string $message,
        public readonly int $httpStatus = 400,
        public readonly string $errorCode = 'MEMBERSHIP_ERROR'
    ) {
        parent::__construct($message);
    }
}

/**
 * Lock every active administrator in a company before removing one of them.
 * Locking the rows, instead of only counting them, prevents two concurrent
 * demotions/suspensions from both observing the same administrator count.
 *
 * @return int[]
 */
function lockActiveCompanyAdministratorIds(mysqli $conn, int $companyId): array
{
    $stmt = $conn->prepare("\n        SELECT id\n        FROM company_memberships\n        WHERE company_id = ? AND status = 'ACTIVE' AND role = 'ADMINISTRATOR'\n        ORDER BY id ASC\n        FOR UPDATE\n    ");
    $stmt->bind_param('i', $companyId);
    $stmt->execute();
    $rows = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);
    $stmt->close();

    return array_map(static fn(array $row): int => (int)$row['id'], $rows);
}

/**
 * Serialize role/status changes for one company in a deterministic order.
 * Small-business teams are short lists, and this avoids two administrators
 * deadlocking while changing different administrator memberships at once.
 */
function lockCompanyMembershipIds(mysqli $conn, int $companyId): array
{
    $stmt = $conn->prepare("\n        SELECT id\n        FROM company_memberships\n        WHERE company_id = ?\n        ORDER BY id ASC\n        FOR UPDATE\n    ");
    $stmt->bind_param('i', $companyId);
    $stmt->execute();
    $rows = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);
    $stmt->close();

    return array_map(static fn(array $row): int => (int)$row['id'], $rows);
}

function assertCompanyKeepsActiveAdministrator(
    mysqli $conn,
    int $companyId,
    int $targetMembershipId
): void {
    $administratorIds = lockActiveCompanyAdministratorIds($conn, $companyId);
    if (in_array($targetMembershipId, $administratorIds, true) && count($administratorIds) <= 1) {
        throw new CompanyMembershipException(
            'The company must keep at least one active administrator.',
            409,
            'LAST_ADMIN_REQUIRED'
        );
    }
}

function revokeMembershipCompanySessions(mysqli $conn, int $userId, int $companyId): void
{
    $stmt = $conn->prepare("\n        UPDATE auth_refresh_tokens\n        SET revoked_at = COALESCE(revoked_at, NOW())\n        WHERE user_id = ? AND company_id = ?\n    ");
    $stmt->bind_param('ii', $userId, $companyId);
    $stmt->execute();
    $stmt->close();
}

function updateMemberDefaultCompany(
    mysqli $conn,
    int $userId,
    int $companyId,
    string $membershipStatus
): void {
    if ($membershipStatus === 'ACTIVE') {
        $stmt = $conn->prepare("\n            SELECT u.default_company_id\n            FROM users u\n            LEFT JOIN company_memberships cm\n                ON cm.user_id = u.id\n               AND cm.company_id = u.default_company_id\n               AND cm.status = 'ACTIVE'\n            LEFT JOIN companies c\n                ON c.id = cm.company_id AND c.status = 'ACTIVE'\n            WHERE u.id = ?\n              AND cm.id IS NOT NULL\n              AND c.id IS NOT NULL\n            LIMIT 1\n        ");
        $stmt->bind_param('i', $userId);
        $stmt->execute();
        $hasValidDefault = (bool)$stmt->get_result()->fetch_assoc();
        $stmt->close();
        if (!$hasValidDefault) {
            $stmt = $conn->prepare('UPDATE users SET default_company_id = ? WHERE id = ?');
            $stmt->bind_param('ii', $companyId, $userId);
            $stmt->execute();
            $stmt->close();
        }
        return;
    }

    $stmt = $conn->prepare("\n        SELECT MIN(cm.company_id) AS company_id\n        FROM company_memberships cm\n        JOIN companies c ON c.id = cm.company_id AND c.status = 'ACTIVE'\n        WHERE cm.user_id = ? AND cm.company_id <> ? AND cm.status = 'ACTIVE'\n    ");
    $stmt->bind_param('ii', $userId, $companyId);
    $stmt->execute();
    $fallbackCompanyId = (int)($stmt->get_result()->fetch_assoc()['company_id'] ?? 0);
    $stmt->close();

    if ($fallbackCompanyId > 0) {
        $stmt = $conn->prepare("\n            UPDATE users\n            SET default_company_id = ?\n            WHERE id = ? AND default_company_id = ?\n        ");
        $stmt->bind_param('iii', $fallbackCompanyId, $userId, $companyId);
    } else {
        $stmt = $conn->prepare("\n            UPDATE users\n            SET default_company_id = NULL\n            WHERE id = ? AND default_company_id = ?\n        ");
        $stmt->bind_param('ii', $userId, $companyId);
    }
    $stmt->execute();
    $stmt->close();
}

function updateCompanyMembershipRole(
    mysqli $conn,
    int $companyId,
    int $actorId,
    int $membershipId,
    int $targetUserId,
    string $role
): array {
    $normalizedRole = normalizeUserRole($role);
    if (!in_array($normalizedRole, availableUserRoles(), true)) {
        throw new CompanyMembershipException('Invalid user role.', 422, 'MEMBERSHIP_ROLE_INVALID');
    }
    if ($membershipId <= 0 && $targetUserId <= 0) {
        throw new CompanyMembershipException('Membership ID is required.', 422, 'MEMBERSHIP_ID_REQUIRED');
    }

    lockCompanyMembershipIds($conn, $companyId);

    $where = $membershipId > 0 ? 'cm.id = ?' : 'cm.user_id = ?';
    $lookupId = $membershipId > 0 ? $membershipId : $targetUserId;
    $stmt = $conn->prepare("\n        SELECT cm.id, cm.user_id, cm.role, cm.status, cm.is_owner\n        FROM company_memberships cm\n        WHERE {$where} AND cm.company_id = ?\n        LIMIT 1 FOR UPDATE\n    ");
    $stmt->bind_param('ii', $lookupId, $companyId);
    $stmt->execute();
    $target = $stmt->get_result()->fetch_assoc();
    $stmt->close();
    if (!$target) {
        throw new CompanyMembershipException('Membership not found.', 404, 'MEMBERSHIP_NOT_FOUND');
    }
    if (($target['status'] ?? '') !== 'ACTIVE') {
        throw new CompanyMembershipException(
            'Only active memberships can change role.',
            409,
            'MEMBERSHIP_NOT_ACTIVE'
        );
    }
    $oldRole = normalizeUserRole($target['role'] ?? null);
    $targetMembershipId = (int)$target['id'];
    $targetActorId = (int)$target['user_id'];
    if ($targetActorId === $actorId && $oldRole !== $normalizedRole) {
        throw new CompanyMembershipException(
            'Ask another administrator to change your role.',
            409,
            'SELF_PROTECTED'
        );
    }
    if ($oldRole !== $normalizedRole
        && (int)$target['is_owner'] === 1
        && $normalizedRole !== 'ADMINISTRATOR') {
        throw new CompanyMembershipException(
            'The company owner must remain an administrator.',
            409,
            'OWNER_IMMUTABLE'
        );
    }
    if ($oldRole === 'ADMINISTRATOR' && $normalizedRole !== 'ADMINISTRATOR') {
        assertCompanyKeepsActiveAdministrator($conn, $companyId, $targetMembershipId);
    }

    if ($oldRole !== $normalizedRole) {
        $update = $conn->prepare('UPDATE company_memberships SET role = ?, version = version + 1 WHERE id = ? AND company_id = ?');
        $update->bind_param('sii', $normalizedRole, $targetMembershipId, $companyId);
        $update->execute();
        $update->close();

        revokeMembershipCompanySessions($conn, $targetActorId, $companyId);

        auditLog(
            $conn,
            $companyId,
            $actorId,
            'MEMBERSHIP.ROLE_CHANGED',
            'COMPANY_MEMBERSHIP',
            $targetMembershipId,
            ['role' => $oldRole],
            ['role' => $normalizedRole, 'user_id' => $targetActorId]
        );
    }

    return [
        'membership_id' => $targetMembershipId,
        'user_id' => $targetActorId,
        'old_role' => $oldRole,
        'role' => $normalizedRole,
        'changed' => $oldRole !== $normalizedRole,
    ];
}

function updateCompanyMembershipStatus(
    mysqli $conn,
    int $companyId,
    int $actorId,
    int $membershipId,
    int $targetUserId,
    string $status
): array {
    $normalizedStatus = strtoupper(trim($status));
    if (!in_array($normalizedStatus, ['ACTIVE', 'SUSPENDED', 'REVOKED'], true)) {
        throw new CompanyMembershipException('Invalid membership status.', 422, 'MEMBERSHIP_STATUS_INVALID');
    }
    if ($membershipId <= 0 && $targetUserId <= 0) {
        throw new CompanyMembershipException('Membership ID is required.', 422, 'MEMBERSHIP_ID_REQUIRED');
    }

    lockCompanyMembershipIds($conn, $companyId);

    $where = $membershipId > 0 ? 'cm.id = ?' : 'cm.user_id = ?';
    $lookupId = $membershipId > 0 ? $membershipId : $targetUserId;
    $stmt = $conn->prepare("\n        SELECT cm.id, cm.user_id, cm.role, cm.status, cm.is_owner, cm.version\n        FROM company_memberships cm\n        WHERE {$where} AND cm.company_id = ?\n        LIMIT 1 FOR UPDATE\n    ");
    $stmt->bind_param('ii', $lookupId, $companyId);
    $stmt->execute();
    $target = $stmt->get_result()->fetch_assoc();
    $stmt->close();
    if (!$target) {
        throw new CompanyMembershipException('Membership not found.', 404, 'MEMBERSHIP_NOT_FOUND');
    }

    $targetMembershipId = (int)$target['id'];
    $targetActorId = (int)$target['user_id'];
    $oldStatus = strtoupper((string)$target['status']);
    $role = normalizeUserRole($target['role'] ?? null);
    $isOwner = (int)$target['is_owner'] === 1;

    if ($targetActorId === $actorId && $oldStatus !== $normalizedStatus) {
        throw new CompanyMembershipException(
            'Ask another administrator to change your membership status.',
            409,
            'SELF_PROTECTED'
        );
    }
    if ($isOwner && $normalizedStatus !== 'ACTIVE') {
        throw new CompanyMembershipException(
            'The company owner membership must remain active.',
            409,
            'OWNER_IMMUTABLE'
        );
    }
    if ($oldStatus === 'REVOKED' && $normalizedStatus !== 'REVOKED') {
        throw new CompanyMembershipException(
            'A revoked membership cannot be reactivated.',
            409,
            'MEMBERSHIP_REVOKED'
        );
    }
    if ($oldStatus === 'ACTIVE' && $normalizedStatus !== 'ACTIVE' && $role === 'ADMINISTRATOR') {
        assertCompanyKeepsActiveAdministrator($conn, $companyId, $targetMembershipId);
    }

    $changed = $oldStatus !== $normalizedStatus;
    if ($changed) {
        if ($normalizedStatus === 'ACTIVE') {
            $stmt = $conn->prepare("\n                UPDATE company_memberships\n                SET status = 'ACTIVE', suspended_at = NULL, version = version + 1\n                WHERE id = ? AND company_id = ?\n            ");
        } elseif ($normalizedStatus === 'SUSPENDED') {
            $stmt = $conn->prepare("\n                UPDATE company_memberships\n                SET status = 'SUSPENDED', suspended_at = NOW(), version = version + 1\n                WHERE id = ? AND company_id = ?\n            ");
        } else {
            $stmt = $conn->prepare("\n                UPDATE company_memberships\n                SET status = 'REVOKED', suspended_at = NULL, revoked_at = NOW(), version = version + 1\n                WHERE id = ? AND company_id = ?\n            ");
        }
        $stmt->bind_param('ii', $targetMembershipId, $companyId);
        $stmt->execute();
        $stmt->close();

        revokeMembershipCompanySessions($conn, $targetActorId, $companyId);
        updateMemberDefaultCompany($conn, $targetActorId, $companyId, $normalizedStatus);

        auditLog(
            $conn,
            $companyId,
            $actorId,
            'MEMBERSHIP.STATUS_CHANGED',
            'COMPANY_MEMBERSHIP',
            $targetMembershipId,
            ['status' => $oldStatus],
            ['status' => $normalizedStatus, 'user_id' => $targetActorId]
        );
    }

    return [
        'membership_id' => $targetMembershipId,
        'user_id' => $targetActorId,
        'old_status' => $oldStatus,
        'status' => $normalizedStatus,
        'changed' => $changed,
    ];
}
