<?php

header('Content-Type: application/json');

require_once __DIR__ . '/../config/response.php';
require_once __DIR__ . '/../config/db.php';
require_once __DIR__ . '/../auth/auth_required.php';
require_once __DIR__ . '/../auth/role_helper.php';

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    jsonResponse(['success' => false, 'message' => 'Method not allowed.'], 405);
}

$auth = requireAuth();
$conn = db();
requireAdministratorRole($conn, authTenantId($auth));
jsonResponse([
    'success' => false,
    'message' => 'Company archiving is temporarily unavailable while employee workspaces are being migrated.',
    'code' => 'COMPANY_ARCHIVE_MIGRATION_LOCK',
], 409);
