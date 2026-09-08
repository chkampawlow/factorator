<?php

declare(strict_types=1);

if (PHP_SAPI !== 'cli') { http_response_code(404); exit; }

require_once __DIR__ . '/../auth/role_helper.php';
require_once __DIR__ . '/../auth/jwt_helper.php';

function companyContextAssert(bool $condition, string $label): void
{
    if (!$condition) {
        fwrite(STDERR, 'FAIL ' . $label . PHP_EOL);
        exit(1);
    }
    echo 'PASS ' . $label . PHP_EOL;
}

$account = [
    'id' => 202,
    'email' => 'employee@example.test',
    'email_verified_at' => '2026-08-14 10:00:00',
];
$membership = [
    'membership_id' => 303,
    'company_id' => 101,
    'user_id' => 202,
    'role' => 'COMMERCIAL',
    'membership_status' => 'ACTIVE',
    'membership_version' => 7,
    'is_owner' => 0,
    'company_status' => 'ACTIVE',
];
$principal = buildCompanyPrincipal($account, $membership);

companyContextAssert($principal->id === 101, 'legacy principal id remains the company data scope');
companyContextAssert(authActorId($principal) === 202, 'actor id identifies the employee');
companyContextAssert(authTenantId($principal) === 101, 'tenant id identifies the company');
companyContextAssert(authMembershipId($principal) === 303, 'membership id is retained');
companyContextAssert($principal->role === 'COMMERCIAL', 'membership role is authoritative');

$payload = membershipPayload($membership, 'normalizeUserRole');
companyContextAssert($payload['tenant_id'] === 101 && $payload['company_id'] === 101,
    'membership response exposes company and transitional tenant aliases');

$jwtUser = [
    'id' => 202,
    'email' => 'employee@example.test',
    'role' => 'COMMERCIAL',
    'company_id' => 101,
    'membership_id' => 303,
    'membership_version' => 7,
];
$access = decodeJwt(generateJwt($jwtUser, 300));
$refresh = decodeJwt(generateRefreshJwt($jwtUser, 300));
companyContextAssert(($access->type ?? '') === 'access', 'access tokens are explicitly typed');
companyContextAssert(($refresh->type ?? '') === 'refresh', 'refresh tokens are explicitly typed');
companyContextAssert((int)$access->user->id === 202, 'JWT user id is the actor, not the company');
companyContextAssert((int)$access->user->company_id === 101
    && (int)$access->user->membership_id === 303
    && (int)$access->user->membership_version === 7,
    'JWT retains company membership identity and version');

echo 'Company context helper tests passed.' . PHP_EOL;
