<?php

header('Content-Type: application/json');

require_once __DIR__ . '/../config/db.php';
require_once __DIR__ . '/../config/response.php';
require_once __DIR__ . '/../config/validator.php';
require_once __DIR__ . '/role_helper.php';
require_once __DIR__ . '/../config/rate_limit.php';
require_once __DIR__ . '/../config/platform_settings.php';
require_once __DIR__ . '/password_policy.php';
require_once __DIR__ . '/company_context.php';




try {
    if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
        jsonResponse([
            'success' => false,
            'message' => 'Method not allowed. Use POST.'
        ], 405);
        exit;
    }

    $data = requireJsonBody();

    enforceRateLimit('signup', 'signup', 5, 60 * 60);

    $organization_name = getOptionalString($data, 'organization_name');
    $fiscal_id = strtoupper(getRequiredString($data, 'fiscal_id', 'Fiscal ID'));
    $email = strtolower(getRequiredString($data, 'email', 'Email'));
    $phone = preg_replace('/\s+/', ' ', getRequiredString($data, 'phone', 'Phone'));

    // Optional: FODEC flag stored on user profile.
    // New UX: a checkbox sends a boolean (is_fodec / isFodec / fodec_enabled / fodecEnabled).
    // Store only fodec = 1 or 0. The actual rate is calculated by currency where totals are computed.

    $isFodecRaw = null;
    if (array_key_exists('is_fodec', $data)) $isFodecRaw = $data['is_fodec'];
    if ($isFodecRaw === null && array_key_exists('isFodec', $data)) $isFodecRaw = $data['isFodec'];
    if ($isFodecRaw === null && array_key_exists('fodec_enabled', $data)) $isFodecRaw = $data['fodec_enabled'];
    if ($isFodecRaw === null && array_key_exists('fodecEnabled', $data)) $isFodecRaw = $data['fodecEnabled'];
    // extra common keys
    if ($isFodecRaw === null && array_key_exists('fodec', $data)) $isFodecRaw = $data['fodec'];
    if ($isFodecRaw === null && array_key_exists('has_fodec', $data)) $isFodecRaw = $data['has_fodec'];
    if ($isFodecRaw === null && array_key_exists('hasFodec', $data)) $isFodecRaw = $data['hasFodec'];

    $isFodec = false;
    if ($isFodecRaw !== null) {
        if (is_bool($isFodecRaw)) {
            $isFodec = $isFodecRaw;
        } elseif (is_numeric($isFodecRaw)) {
            $isFodec = ((int)$isFodecRaw) === 1;
        } else {
            $s = strtolower(trim((string)$isFodecRaw));
            $isFodec = in_array($s, ['1', 'true', 'yes', 'y', 'on'], true);
        }
    }

    // Backward-compatible numeric input
    $fodec_rate_raw = getOptionalString($data, 'fodec_rate');
    if ($fodec_rate_raw === '' && isset($data['fodecRate'])) {
        $fodec_rate_raw = trim((string)$data['fodecRate']);
    }

    $fodec = $isFodec ? 1 : 0;
    if ($fodec === 0 && $fodec_rate_raw !== '') {
        $legacyRate = (float)str_replace(',', '.', $fodec_rate_raw);
        $fodec = $legacyRate > 0 ? 1 : 0;
    }

    structuredLog('INFO','AUTH.SIGNUP_TAX_OPTION_NORMALIZED',[
        'fodec_selected'=>$isFodec,
        'fodec_rate_present'=>$fodec_rate_raw !== '',
        'computed_flag'=>$fodec,
    ]);

    $password = (string)($data['password'] ?? '');
    $confirm_password = (string)($data['confirm_password'] ?? '');

    if ($password === '' || $confirm_password === '') {
        throw new Exception('Password and confirm password are required.');
    }

    validateEmailIfPresent($email);
    validateMaxLength($organization_name, 255, 'Organization name');
    validateMaxLength($fiscal_id, 13, 'Fiscal ID');
    validateMaxLength($email, 255, 'Email');
    validateMaxLength($phone, 20, 'Phone');

    if ($fodec !== 0 && $fodec !== 1) {
        throw new Exception('Invalid fodec value.');
    }

    if (!preg_match('/^[0-9]{7}[A-Z]{1}$/', $fiscal_id)) {
        throw new Exception('Invalid fiscal ID.');
    }

    if (!preg_match('/^\+\d{1,3}\s\d{6,12}$/', $phone)) {
        throw new Exception('Invalid phone number. Example: +216 20123456');
    }

    assertStrongPassword($password, [$email, $organization_name, $fiscal_id]);

    if ($password !== $confirm_password) {
        throw new Exception('Passwords do not match.');
    }

    $conn = db();
    ensureUserRoleColumn($conn);
    $requiresApproval = platformBooleanSetting($conn, NEW_USER_APPROVAL_SETTING, true);
    $initialAccountStatus = $requiresApproval ? 'PENDING' : 'ACTIVE';
    $approvedAt = $requiresApproval ? null : gmdate('Y-m-d H:i:s');

    ensureUserFiscalIdUnique(
        $conn,
        $fiscal_id,
        null,
        'fiscal_id'
    );

    $stmt = $conn->prepare('SELECT id FROM users WHERE email = ? LIMIT 1');

    if (!$stmt) {
        throw new Exception('Failed to prepare email uniqueness query: ' . $conn->error);
    }

    $stmt->bind_param('s', $email);
    $stmt->execute();
    $existing = $stmt->get_result()->fetch_assoc();
    $stmt->close();

    if ($existing) {
        throw new Exception('This email is already used.');
    }

    $conn->begin_transaction();
    $password_hash = password_hash($password, PASSWORD_DEFAULT);

    $stmt = $conn->prepare('
        INSERT INTO users (
            display_name,
            organization_name,
            fiscal_id,
            email,
            phone,
            password_hash,
            fodec,
            role,
            account_status,
            approved_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ');

    if (!$stmt) {
        throw new Exception('Failed to prepare signup query: ' . $conn->error);
    }

    $role = 'ADMINISTRATOR';

    $stmt->bind_param(
        'ssssssisss',
        $organization_name,
        $organization_name,
        $fiscal_id,
        $email,
        $phone,
        $password_hash,
        $fodec,
        $role,
        $initialAccountStatus,
        $approvedAt
    );

    $stmt->execute();

    if ($stmt->error) {
        throw new Exception('Failed to create account: ' . $stmt->error);
    }

    $userId = $stmt->insert_id;
    $stmt->close();

    $membership = createOwnerCompany($conn, $userId, [
        'organization_name' => $organization_name,
        'fiscal_id' => $fiscal_id,
        'phone' => $phone,
        'fodec' => $fodec,
    ]);
    $companyId = (int)$membership['company_id'];
    $defaultStmt = $conn->prepare('UPDATE users SET default_company_id = ? WHERE id = ?');
    $defaultStmt->bind_param('ii', $companyId, $userId);
    $defaultStmt->execute();
    $defaultStmt->close();
    $conn->commit();

    $debug = null;
    if (isset($_GET['debug']) && (string)$_GET['debug'] === '1') {
        $debug = [
            'received_keys' => array_keys($data),
            'isFodecRaw' => $isFodecRaw,
            'isFodec' => $isFodec,
            'fodec_rate_raw' => $fodec_rate_raw,
            'computed_fodec' => $fodec,
        ];
    }

    $payload = [
        'success' => true,
        'message' => $requiresApproval
            ? 'Account created. A super administrator must approve it before you can sign in.'
            : 'Account created successfully.',
        'user_id' => $userId,
        'account_status' => $initialAccountStatus,
        'requires_approval' => $requiresApproval,
    ];
    if ($debug !== null) {
        $payload['debug'] = $debug;
    }

    jsonResponse($payload);
} catch (Throwable $e) {
    if (isset($conn)) {
        try { $conn->rollback(); } catch (Throwable $ignored) {}
    }
    jsonResponse([
        'success' => false,
        'message' => $e->getMessage()
    ], 400);
}
