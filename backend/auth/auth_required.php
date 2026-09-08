<?php

header('Content-Type: application/json');

require_once __DIR__ . '/jwt_helper.php';
require_once __DIR__ . '/../config/response.php';
require_once __DIR__ . '/../config/db.php';
require_once __DIR__ . '/verified_required.php';
require_once __DIR__ . '/role_helper.php';




function requireAuth(bool $allowUnverified = false): object
{
    $token = getBearerToken();

    if (!$token) {
        jsonResponse([
            "success" => false,
            "message" => "Missing access token."
        ], 401);
        exit;
    }

    try {
        $decoded = decodeJwt($token);
        $tokenType = (string)($decoded->type ?? 'access');
        if ($tokenType !== 'access') {
            throw new UnexpectedValueException('Wrong token type.');
        }
        $tokenUser = $decoded->user;
        $actorId = (int)($tokenUser->id ?? 0);
        if ($actorId <= 0) {
            throw new UnexpectedValueException('Token actor is missing.');
        }
        $conn = db();
        $statusStmt = $conn->prepare('SELECT id,email,email_verified_at,account_status FROM users WHERE id=? LIMIT 1');
        $statusStmt->bind_param('i',$actorId);$statusStmt->execute();
        $account = $statusStmt->get_result()->fetch_assoc();$statusStmt->close();
        $accountStatus = strtoupper((string)($account['account_status'] ?? 'ACTIVE'));
        if(!$account || $accountStatus !== 'ACTIVE') {
            $isPending = $accountStatus === 'PENDING';
            jsonResponse([
                'success'=>false,
                'message'=>$isPending
                    ? 'Your account is awaiting approval by a super administrator.'
                    : 'This user account is not active.',
                'code'=>$isPending ? 'ACCOUNT_PENDING_APPROVAL' : 'ACCOUNT_INACTIVE',
            ],403);
        }

        $requestedCompanyId = (int)($tokenUser->company_id ?? $tokenUser->tenant_id ?? 0);
        try {
            $membership = requireActiveCompanyMembership(
                $conn,
                $actorId,
                $requestedCompanyId > 0 ? $requestedCompanyId : null
            );
        } catch (RuntimeException $membershipError) {
            jsonResponse([
                'success' => false,
                'message' => $membershipError->getMessage(),
                'code' => 'MEMBERSHIP_INACTIVE',
            ], 403);
        }
        $tokenMembershipId = (int)($tokenUser->membership_id ?? 0);
        $tokenMembershipVersion = (int)($tokenUser->membership_version ?? 0);
        if (($tokenMembershipId > 0 && $tokenMembershipId !== (int)$membership['membership_id'])
            || ($tokenMembershipVersion > 0
                && $tokenMembershipVersion !== (int)($membership['membership_version'] ?? 1))) {
            jsonResponse([
                'success' => false,
                'message' => 'This company session is no longer current.',
                'code' => 'MEMBERSHIP_SESSION_STALE',
            ], 401);
        }

        $principal = buildCompanyPrincipal($account, $membership);
        setActiveAuthPrincipal($principal);
        appSetLogContext(authTenantId($principal), authActorId($principal));
        if (!$allowUnverified) {
            requireVerifiedEmail($principal);
        }
        return $principal;
    } catch (Throwable $e) {
        jsonResponse([
            "success" => false,
            "message" => "Invalid or expired token."
        ], 401);
        exit;
    }
}
