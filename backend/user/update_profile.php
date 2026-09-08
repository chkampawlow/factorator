<?php

header('Content-Type: application/json');

require_once __DIR__ . '/../auth/auth_required.php';
require_once __DIR__ . '/../auth/role_helper.php';
require_once __DIR__ . '/../config/response.php';
require_once __DIR__ . '/../config/db.php';
require_once __DIR__ . '/../config/audit.php';

try {
    if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
        jsonResponse(['success' => false, 'message' => 'Method not allowed. Use POST.'], 405);
    }
    $auth = requireAuth();
    $conn = db();
    $companyId = authTenantId($auth);
    $actorId = authActorId($auth);
    requireAdministratorRole($conn, $companyId);

    $data = json_decode(file_get_contents('php://input'), true);
    if (!is_array($data)) {
        jsonResponse(['success' => false, 'message' => 'Invalid JSON body.'], 400);
    }
    $organizationName = trim((string)($data['organization_name'] ?? ''));
    $phone = trim((string)($data['phone'] ?? ''));
    $fax = trim((string)($data['fax'] ?? ''));
    $address = trim((string)($data['address'] ?? ''));
    $website = trim((string)($data['website'] ?? ''));
    if ($organizationName === '') {
        jsonResponse(['success' => false, 'message' => 'Organization name is required.'], 422);
    }
    if (mb_strlen($organizationName) > 191 || mb_strlen($phone) > 30 || mb_strlen($fax) > 50
        || mb_strlen($address) > 255 || mb_strlen($website) > 255) {
        jsonResponse(['success' => false, 'message' => 'One or more company fields are too long.'], 422);
    }
    if ($website !== '' && filter_var($website, FILTER_VALIDATE_URL) === false) {
        jsonResponse(['success' => false, 'message' => 'Website must be a valid URL.'], 422);
    }

    $conn->begin_transaction();
    $beforeStmt = $conn->prepare('SELECT organization_name, fiscal_id, phone, fax, address, website, fodec, status, owner_user_id FROM companies WHERE id = ? LIMIT 1 FOR UPDATE');
    $beforeStmt->bind_param('i', $companyId);
    $beforeStmt->execute();
    $before = $beforeStmt->get_result()->fetch_assoc();
    $beforeStmt->close();
    if (!$before) {
        jsonResponse(['success' => false, 'message' => 'Company workspace not found.'], 404);
    }

    $update = $conn->prepare('UPDATE companies SET organization_name = ?, phone = NULLIF(?, \'\'), fax = NULLIF(?, \'\'), address = NULLIF(?, \'\'), website = NULLIF(?, \'\') WHERE id = ?');
    $update->bind_param('sssssi', $organizationName, $phone, $fax, $address, $website, $companyId);
    $update->execute();
    $update->close();

    // Transitional mirror for older PDF/report joins until company snapshots
    // become authoritative everywhere.
    $ownerId = (int)$before['owner_user_id'];
    $mirror = $conn->prepare('UPDATE users SET organization_name = ?, phone = NULLIF(?, \'\'), fax = NULLIF(?, \'\'), address = NULLIF(?, \'\'), website = NULLIF(?, \'\') WHERE id = ?');
    $mirror->bind_param('sssssi', $organizationName, $phone, $fax, $address, $website, $ownerId);
    $mirror->execute();
    $mirror->close();

    auditLog($conn, $companyId, $actorId, 'COMPANY.PROFILE_UPDATED', 'COMPANY', $companyId, $before, [
        'organization_name' => $organizationName,
        'phone' => $phone,
        'fax' => $fax,
        'address' => $address,
        'website' => $website,
    ]);
    $conn->commit();
    jsonResponse([
        'success' => true,
        'message' => 'Company profile updated successfully.',
        'company' => [
            'id' => $companyId,
            'organization_name' => $organizationName,
            'fiscal_id' => (string)($before['fiscal_id'] ?? ''),
            'phone' => $phone,
            'fax' => $fax,
            'address' => $address,
            'website' => $website,
            'fodec' => (int)($before['fodec'] ?? 0),
            'is_fodec' => (int)($before['fodec'] ?? 0) === 1,
            'status' => (string)($before['status'] ?? 'ACTIVE'),
        ],
    ]);
} catch (Throwable $e) {
    if (isset($conn)) {
        try { $conn->rollback(); } catch (Throwable $ignored) {}
    }
    jsonResponse(['success' => false, 'message' => $e->getMessage()], 400);
}
