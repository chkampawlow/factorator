<?php

declare(strict_types=1);

require_once __DIR__ . '/../auth/password_policy.php';
require_once __DIR__ . '/../auth/role_helper.php';
require_once __DIR__ . '/../config/audit.php';
require_once __DIR__ . '/membership_service.php';

final class CompanyInvitationException extends RuntimeException
{
    public function __construct(
        string $message,
        public readonly int $httpStatus = 400,
        public readonly string $errorCode = 'INVITATION_ERROR'
    ) {
        parent::__construct($message);
    }
}

function invitationEnvironment(): string
{
    $environment = strtolower(trim((string)($_ENV['APP_ENV'] ?? getenv('APP_ENV') ?: '')));
    return in_array($environment, ['development', 'staging', 'production'], true)
        ? $environment
        : 'unknown';
}

function normalizeInvitationEmail(string $email): string
{
    return strtolower(trim($email));
}

function assertInvitationInput(string $email, string $displayName, string $role, int $expiresInHours): string
{
    if (!filter_var($email, FILTER_VALIDATE_EMAIL) || strlen($email) > 191) {
        throw new CompanyInvitationException('A valid employee email is required.', 422, 'INVITATION_EMAIL_INVALID');
    }
    if ($displayName !== '' && passwordLength($displayName) > 191) {
        throw new CompanyInvitationException('Employee name is too long.', 422, 'INVITATION_NAME_INVALID');
    }
    $normalizedRole = normalizeUserRole($role);
    if (!in_array($normalizedRole, availableUserRoles(), true)) {
        throw new CompanyInvitationException('Invalid employee role.', 422, 'INVITATION_ROLE_INVALID');
    }
    if ($expiresInHours < 1 || $expiresInHours > 168) {
        throw new CompanyInvitationException(
            'Invitation expiry must be between 1 and 168 hours.',
            422,
            'INVITATION_EXPIRY_INVALID'
        );
    }

    return $normalizedRole;
}

function invitationStatus(array $invitation): string
{
    $status = strtoupper((string)($invitation['status'] ?? ''));
    if ($status === 'PENDING' && array_key_exists('is_expired', $invitation)) {
        return (int)$invitation['is_expired'] === 1 ? 'EXPIRED' : 'PENDING';
    }
    $expiresAt = strtotime((string)($invitation['expires_at'] ?? ''));
    if ($status === 'PENDING' && $expiresAt !== false && $expiresAt <= time()) {
        return 'EXPIRED';
    }
    return $status;
}

function createCompanyInvitation(
    mysqli $conn,
    int $companyId,
    int $actorId,
    string $email,
    string $displayName,
    string $role,
    int $expiresInHours = 72
): array {
    $email = normalizeInvitationEmail($email);
    $displayName = trim($displayName);
    $normalizedRole = assertInvitationInput($email, $displayName, $role, $expiresInHours);

    // Lock invitation rows before the identity row. Acceptance follows the
    // same order, preventing replace-vs-accept deadlocks.
    $pendingStmt = $conn->prepare("\n        SELECT id, company_id\n        FROM company_invitations\n        WHERE email = ? AND status = 'PENDING' AND expires_at > NOW()\n        ORDER BY id ASC\n        FOR UPDATE\n    ");
    $pendingStmt->bind_param('s', $email);
    $pendingStmt->execute();
    $pendingInvitations = $pendingStmt->get_result()->fetch_all(MYSQLI_ASSOC);
    $pendingStmt->close();
    foreach ($pendingInvitations as $pendingInvitation) {
        if ((int)$pendingInvitation['company_id'] !== $companyId) {
            throw new CompanyInvitationException(
                'Invitation cannot be created for this address.',
                409,
                'INVITATION_UNAVAILABLE'
            );
        }
    }

    // Existing identities are accepted only for a same-company rehire. Joining
    // multiple companies remains disabled until the product has a company
    // switcher and an authenticated existing-account acceptance flow.
    $accountStmt = $conn->prepare("\n        SELECT u.id, u.account_status, cm.id AS membership_id, cm.status AS membership_status\n        FROM users u\n        LEFT JOIN company_memberships cm\n            ON cm.user_id = u.id AND cm.company_id = ?\n        WHERE u.email = ?\n        LIMIT 1 FOR UPDATE\n    ");
    $accountStmt->bind_param('is', $companyId, $email);
    $accountStmt->execute();
    $existingAccount = $accountStmt->get_result()->fetch_assoc();
    $accountStmt->close();
    if ($existingAccount && (
        strtoupper((string)($existingAccount['account_status'] ?? '')) !== 'ACTIVE'
        || (int)($existingAccount['membership_id'] ?? 0) <= 0
        || strtoupper((string)($existingAccount['membership_status'] ?? '')) !== 'REVOKED'
    )) {
        throw new CompanyInvitationException(
            'Invitation cannot be created for this address.',
            409,
            'INVITATION_UNAVAILABLE'
        );
    }

    // A replacement invalidates old links before a new one is issued.
    $replaceStmt = $conn->prepare("\n        UPDATE company_invitations\n        SET status = CASE WHEN expires_at <= NOW() THEN 'EXPIRED' ELSE 'REVOKED' END,\n            revoked_at = CASE WHEN expires_at > NOW() THEN NOW() ELSE revoked_at END\n        WHERE company_id = ? AND email = ? AND status = 'PENDING'\n    ");
    $replaceStmt->bind_param('is', $companyId, $email);
    $replaceStmt->execute();
    $replacedInvitationCount = $replaceStmt->affected_rows;
    $replaceStmt->close();

    $token = bin2hex(random_bytes(32));
    $tokenHash = hash('sha256', $token);
    $stmt = $conn->prepare("\n        INSERT INTO company_invitations\n            (company_id, email, display_name, role, status, token_hash, invited_by, expires_at)\n        VALUES (?, ?, NULLIF(?, ''), ?, 'PENDING', ?, ?, DATE_ADD(NOW(), INTERVAL ? HOUR))\n    ");
    $stmt->bind_param(
        'issssii',
        $companyId,
        $email,
        $displayName,
        $normalizedRole,
        $tokenHash,
        $actorId,
        $expiresInHours
    );
    $stmt->execute();
    $invitationId = (int)$stmt->insert_id;
    $stmt->close();

    $readStmt = $conn->prepare("\n        SELECT id, company_id, email, display_name, role, status, expires_at, created_at\n        FROM company_invitations\n        WHERE id = ? AND company_id = ?\n        LIMIT 1\n    ");
    $readStmt->bind_param('ii', $invitationId, $companyId);
    $readStmt->execute();
    $invitation = $readStmt->get_result()->fetch_assoc();
    $readStmt->close();
    if (!$invitation) {
        throw new RuntimeException('The invitation could not be created.');
    }

    auditLog(
        $conn,
        $companyId,
        $actorId,
        'MEMBERSHIP.INVITATION_CREATED',
        'COMPANY_INVITATION',
        $invitationId,
        null,
        [
            'email_hash' => hash('sha256', $email),
            'role' => $normalizedRole,
            'expires_at' => $invitation['expires_at'],
            'replaced_pending_count' => $replacedInvitationCount,
        ]
    );

    $invitation['id'] = $invitationId;
    $invitation['company_id'] = $companyId;
    $invitation['token'] = $token;
    $invitation['replaced_pending_count'] = $replacedInvitationCount;
    return $invitation;
}

function revokeCompanyInvitation(
    mysqli $conn,
    int $companyId,
    int $actorId,
    int $invitationId
): array {
    if ($invitationId <= 0) {
        throw new CompanyInvitationException('Invitation ID is required.', 422, 'INVITATION_ID_REQUIRED');
    }

    $stmt = $conn->prepare("\n        SELECT id, email, role, status, expires_at, (expires_at <= NOW()) AS is_expired\n        FROM company_invitations\n        WHERE id = ? AND company_id = ?\n        LIMIT 1 FOR UPDATE\n    ");
    $stmt->bind_param('ii', $invitationId, $companyId);
    $stmt->execute();
    $invitation = $stmt->get_result()->fetch_assoc();
    $stmt->close();
    if (!$invitation) {
        throw new CompanyInvitationException('Invitation not found.', 404, 'INVITATION_NOT_FOUND');
    }

    $effectiveStatus = invitationStatus($invitation);
    if ($effectiveStatus === 'EXPIRED' && $invitation['status'] === 'PENDING') {
        $stmt = $conn->prepare("\n            UPDATE company_invitations\n            SET status = 'EXPIRED'\n            WHERE id = ? AND company_id = ? AND status = 'PENDING'\n        ");
        $stmt->bind_param('ii', $invitationId, $companyId);
        $stmt->execute();
        $stmt->close();
        return ['invitation_id' => $invitationId, 'status' => 'EXPIRED', 'changed' => false];
    }
    if ($effectiveStatus === 'REVOKED') {
        return ['invitation_id' => $invitationId, 'status' => 'REVOKED', 'changed' => false];
    }
    if ($effectiveStatus !== 'PENDING') {
        throw new CompanyInvitationException(
            'Only pending invitations can be revoked.',
            409,
            'INVITATION_NOT_PENDING'
        );
    }

    $stmt = $conn->prepare("\n        UPDATE company_invitations\n        SET status = 'REVOKED', revoked_at = NOW()\n        WHERE id = ? AND company_id = ? AND status = 'PENDING'\n    ");
    $stmt->bind_param('ii', $invitationId, $companyId);
    $stmt->execute();
    $stmt->close();

    auditLog(
        $conn,
        $companyId,
        $actorId,
        'MEMBERSHIP.INVITATION_REVOKED',
        'COMPANY_INVITATION',
        $invitationId,
        ['status' => 'PENDING'],
        ['status' => 'REVOKED', 'email_hash' => hash('sha256', (string)$invitation['email'])]
    );

    return ['invitation_id' => $invitationId, 'status' => 'REVOKED', 'changed' => true];
}

function acceptCompanyInvitation(
    mysqli $conn,
    string $token,
    string $password,
    string $confirmPassword,
    string $displayName,
    string $phone = ''
): array {
    $token = trim($token);
    $unavailable = static function (): CompanyInvitationException {
        return new CompanyInvitationException(
            'Invitation is invalid or unavailable.',
            400,
            'INVITATION_UNAVAILABLE'
        );
    };
    if (!preg_match('/^[a-f0-9]{64}$/i', $token)) {
        throw $unavailable();
    }
    if ($password === '' || $confirmPassword === '') {
        throw new CompanyInvitationException(
            'Password and password confirmation are required.',
            422,
            'INVITATION_PASSWORD_REQUIRED'
        );
    }
    if (!hash_equals($password, $confirmPassword)) {
        throw new CompanyInvitationException('Passwords do not match.', 422, 'INVITATION_PASSWORD_MISMATCH');
    }
    $displayName = trim($displayName);
    $phone = trim($phone);
    if ($displayName !== '' && passwordLength($displayName) > 191) {
        throw new CompanyInvitationException('Employee name is too long.', 422, 'INVITATION_NAME_INVALID');
    }
    if (passwordLength($phone) > 30) {
        throw new CompanyInvitationException('Phone number is too long.', 422, 'INVITATION_PHONE_INVALID');
    }
    if ($phone !== '' && !preg_match('/^\+\d{1,3}\s\d{6,12}$/', $phone)) {
        throw new CompanyInvitationException(
            'Invalid phone number. Example: +216 20123456.',
            422,
            'INVITATION_PHONE_INVALID'
        );
    }

    $tokenHash = hash('sha256', $token);
    $stmt = $conn->prepare("\n        SELECT\n            ci.id, ci.company_id, ci.email, ci.display_name, ci.role, ci.status,\n            ci.invited_by, ci.expires_at, (ci.expires_at <= NOW()) AS is_expired,\n            c.status AS company_status\n        FROM company_invitations ci\n        JOIN companies c ON c.id = ci.company_id\n        WHERE ci.token_hash = ?\n        LIMIT 1 FOR UPDATE\n    ");
    $stmt->bind_param('s', $tokenHash);
    $stmt->execute();
    $invitation = $stmt->get_result()->fetch_assoc();
    $stmt->close();
    if (!$invitation || invitationStatus($invitation) !== 'PENDING'
        || ($invitation['company_status'] ?? '') !== 'ACTIVE') {
        throw $unavailable();
    }

    $finalDisplayName = $displayName !== '' ? $displayName : trim((string)$invitation['display_name']);
    if ($finalDisplayName === '') {
        throw new CompanyInvitationException(
            'Employee name is required.',
            422,
            'INVITATION_NAME_REQUIRED'
        );
    }

    $email = normalizeInvitationEmail((string)$invitation['email']);

    // Keep acceptance non-enumerating: registered addresses outside this
    // exact rehire flow and unknown/revoked links share the same public error.
    $accountStmt = $conn->prepare("\n        SELECT id, display_name, password_hash, email_verified_at, account_status\n        FROM users\n        WHERE email = ?\n        LIMIT 1 FOR UPDATE\n    ");
    $accountStmt->bind_param('s', $email);
    $accountStmt->execute();
    $existingAccount = $accountStmt->get_result()->fetch_assoc();
    $accountStmt->close();

    $companyId = (int)$invitation['company_id'];
    $invitationId = (int)$invitation['id'];
    $invitedBy = (int)$invitation['invited_by'];
    $role = normalizeUserRole($invitation['role'] ?? null);
    if (!in_array($role, availableUserRoles(), true)) {
        throw $unavailable();
    }

    // This phase exposes the token only to an authenticated administrator in
    // explicit development mode. That manual handoff does not prove mailbox
    // ownership, so acceptance must leave a new address unverified.
    $emailWasDelivered = false;
    $rehired = false;
    $acceptanceBefore = null;

    if ($existingAccount) {
        if (strtoupper((string)($existingAccount['account_status'] ?? '')) !== 'ACTIVE'
            || !password_verify($password, (string)($existingAccount['password_hash'] ?? ''))) {
            throw $unavailable();
        }
        $userId = (int)$existingAccount['id'];
        $membershipStmt = $conn->prepare("\n            SELECT id, status, role, version\n            FROM company_memberships\n            WHERE company_id = ? AND user_id = ?\n            LIMIT 1 FOR UPDATE\n        ");
        $membershipStmt->bind_param('ii', $companyId, $userId);
        $membershipStmt->execute();
        $membership = $membershipStmt->get_result()->fetch_assoc();
        $membershipStmt->close();
        if (!$membership || strtoupper((string)$membership['status']) !== 'REVOKED') {
            throw $unavailable();
        }
        $membershipId = (int)$membership['id'];
        $acceptanceBefore = [
            'status' => (string)$membership['status'],
            'role' => normalizeUserRole($membership['role'] ?? null),
            'version' => (int)$membership['version'],
        ];
        $stmt = $conn->prepare("\n            UPDATE company_memberships\n            SET role = ?, status = 'ACTIVE', is_owner = 0, invited_by = ?, joined_at = NOW(),\n                suspended_at = NULL, revoked_at = NULL, version = version + 1\n            WHERE id = ? AND company_id = ? AND user_id = ? AND status = 'REVOKED'\n        ");
        $stmt->bind_param('siiii', $role, $invitedBy, $membershipId, $companyId, $userId);
        $stmt->execute();
        if ($stmt->affected_rows !== 1) {
            $stmt->close();
            throw $unavailable();
        }
        $stmt->close();
        $verifiedFlag = $emailWasDelivered ? 1 : 0;
        $stmt = $conn->prepare("\n            UPDATE users\n            SET default_company_id = ?,\n                email_verified_at = IF(? = 1, COALESCE(email_verified_at, NOW()), email_verified_at)\n            WHERE id = ?\n        ");
        $stmt->bind_param('iii', $companyId, $verifiedFlag, $userId);
        $stmt->execute();
        $stmt->close();
        revokeMembershipCompanySessions($conn, $userId, $companyId);
        $rehired = true;
    } else {
        assertStrongPassword($password, [$email, $finalDisplayName]);
        $passwordHash = password_hash($password, PASSWORD_DEFAULT);
        $organizationName = $finalDisplayName;
        $verifiedFlag = $emailWasDelivered ? 1 : 0;
        $stmt = $conn->prepare("\n            INSERT INTO users\n                (display_name, organization_name, fiscal_id, email, phone, password_hash,\n                 email_verified_at, role, account_status, default_company_id)\n            VALUES (?, ?, NULL, ?, NULLIF(?, ''), ?, IF(? = 1, NOW(), NULL), ?, 'ACTIVE', ?)\n        ");
        $stmt->bind_param(
            'sssssisi',
            $finalDisplayName,
            $organizationName,
            $email,
            $phone,
            $passwordHash,
            $verifiedFlag,
            $role,
            $companyId
        );
        $stmt->execute();
        $userId = (int)$stmt->insert_id;
        $stmt->close();

        $stmt = $conn->prepare("\n            INSERT INTO company_memberships\n                (company_id, user_id, role, status, is_owner, invited_by, joined_at)\n            VALUES (?, ?, ?, 'ACTIVE', 0, ?, NOW())\n        ");
        $stmt->bind_param('iisi', $companyId, $userId, $role, $invitedBy);
        $stmt->execute();
        $membershipId = (int)$stmt->insert_id;
        $stmt->close();
    }

    $stmt = $conn->prepare("\n        UPDATE company_invitations\n        SET status = 'ACCEPTED', accepted_by = ?, accepted_at = NOW()\n        WHERE id = ? AND company_id = ? AND status = 'PENDING'\n    ");
    $stmt->bind_param('iii', $userId, $invitationId, $companyId);
    $stmt->execute();
    if ($stmt->affected_rows !== 1) {
        $stmt->close();
        throw $unavailable();
    }
    $stmt->close();

    auditLog(
        $conn,
        $companyId,
        $userId,
        'MEMBERSHIP.INVITATION_ACCEPTED',
        'COMPANY_MEMBERSHIP',
        $membershipId,
        $acceptanceBefore,
        [
            'invitation_id' => $invitationId,
            'role' => $role,
            'status' => 'ACTIVE',
            'rehired' => $rehired,
            'email_hash' => hash('sha256', $email),
        ],
        'AUTH'
    );

    return [
        'user_id' => $userId,
        'company_id' => $companyId,
        'membership_id' => $membershipId,
        'role' => $role,
        'status' => 'ACTIVE',
        'rehired' => $rehired,
        'email_verified' => $emailWasDelivered || !empty($existingAccount['email_verified_at']),
    ];
}
