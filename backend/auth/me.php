<?php

require_once __DIR__ . '/auth_required.php';
require_once __DIR__ . '/../config/response.php';
require_once __DIR__ . '/../config/db.php';
require_once __DIR__ . '/role_helper.php';


try {
    $authUser = requireAuth(true);
    $conn = db();
    ensureUserRoleColumn($conn);

    $actorId = authActorId($authUser);
    $companyId = authTenantId($authUser);
    $stmt = $conn->prepare("
        SELECT id, display_name, email, email_verified_at
        FROM users
        WHERE id = ?
        LIMIT 1
    ");

    $stmt->bind_param("i", $actorId);
    $stmt->execute();

    $user = $stmt->get_result()->fetch_assoc();
    $stmt->close();

    if (!$user) {
        jsonResponse([
            "success" => false,
            "message" => "User not found."
        ], 404);
        exit;
    }

    $membership = requireActiveCompanyMembership($conn, $actorId, $companyId);
    $role = normalizeUserRole($membership['role'] ?? null);
    $company = companyPayload($membership);
    $membershipData = membershipPayload($membership, 'normalizeUserRole');

    jsonResponse([
        "success" => true,
        "user" => [
            "id" => (int)$user['id'],
            "display_name" => $user['display_name'] ?? "",
            "email" => $user['email'],
            "email_verified" => !empty($user['email_verified_at']),
            "organization_name" => $company['organization_name'],
            "fiscal_id" => $company['fiscal_id'],
            "phone" => $company['phone'],
            "fodec" => $company['fodec'],
            "is_fodec" => $company['is_fodec'],
            "fax" => $company['fax'],
            "address" => $company['address'],
            "website" => $company['website'],
            "role" => $role,
            "tenant_id" => $companyId,
            "company_id" => $companyId,
            "membership_id" => (int)$membership['membership_id'],
            "membership_status" => $membership['membership_status'],
            "is_company_owner" => (int)($membership['is_owner'] ?? 0) === 1,
        ],
        'membership' => $membershipData,
        'company' => $company,
        'permissions' => permissionsForMembership($membership),
    ]);

} catch (Throwable $e) {
    jsonResponse([
        "success" => false,
        "message" => $e->getMessage()
    ], 401);
}
