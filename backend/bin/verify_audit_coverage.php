<?php

if (PHP_SAPI !== 'cli') {
    http_response_code(404);
    exit;
}

require_once __DIR__ . '/../config/db.php';

$required = [
    'auth/login.php' => ['AUTH.LOGIN_FAILED', 'AUTH.LOGIN_SUCCEEDED'],
    'auth/verify_2fa_login.php' => ['AUTH.LOGIN_2FA_FAILED', 'AUTH.LOGIN_SUCCEEDED'],
    'auth/refresh_token_service.php' => ['AUTH.LOGOUT'],
    'user/update_user_role.php' => ['USER.ROLE_CHANGED'],
    'invoices/update_invoice.php' => ['INVOICE.VALIDATED', 'INVOICE.CANCELLED'],
    'invoice_settlements/add_payment.php' => ['PAYMENT.POSTED'],
    'invoice_settlements/void_payment.php' => ['PAYMENT.VOIDED'],
    'invoice_settlements/add_withholding.php' => ['WITHHOLDING.RECORDED'],
    'invoice_settlements/update_withholding.php' => ['WITHHOLDING.STATUS_CHANGED'],
    'supplier_invoices/add_supplier_payment.php' => ['SUPPLIER_PAYMENT.POSTED'],
    'supplier_invoices/save_supplier_credit_note.php' => ['SUPPLIER_CREDIT.VALIDATED'],
    'supplier_returns/confirm_supplier_return.php' => ['SUPPLIER_RETURN.CONFIRMED'],
    'products/product_inventory.php' => ['STOCK.MOVEMENT_RECORDED'],
    'taxes/save_tax_profile.php' => ['TAX_PROFILE.CREATED'],
    'taxes/assign_product_tax_profile.php' => ['TAX_PROFILE.ASSIGNED'],
    'reports/export.php' => ['REPORT.EXPORTED'],
    'reports/queue_export.php' => ['REPORT.EXPORT_QUEUED'],
    'reports/queue_reconciliation.php' => ['REPORT.RECONCILIATION_QUEUED'],
    'reports/presets/save.php' => ['REPORT.PRESET_UPDATED', 'REPORT.PRESET_CREATED'],
    'reports/presets/delete.php' => ['REPORT.PRESET_DELETED'],
    'notifications/mark_read.php' => ['NOTIFICATION.'],
];

$missing = [];
$root = dirname(__DIR__);
foreach ($required as $file => $actions) {
    $contents = file_get_contents($root . '/' . $file);
    foreach ($actions as $action) {
        if ($contents === false || !str_contains($contents, $action)) $missing[] = "$file:$action";
    }
}

$conn = db();
$triggerCount = 0;
try {
    $conn->query("UPDATE app_audit_log SET action='TAMPER_TEST' WHERE action='SYSTEM.AUDIT_ENABLED'");
} catch (mysqli_sql_exception $e) {
    if (str_contains($e->getMessage(), 'immutable')) $triggerCount++;
}
try {
    $conn->query("DELETE FROM app_audit_log WHERE action='SYSTEM.AUDIT_ENABLED'");
} catch (mysqli_sql_exception $e) {
    if (str_contains($e->getMessage(), 'append-only')) $triggerCount++;
}
$seedCount = (int) $conn->query("SELECT COUNT(*) FROM app_audit_log WHERE action='SYSTEM.AUDIT_ENABLED'")->fetch_row()[0];
$success = $missing === [] && $triggerCount === 2 && $seedCount === 1;

echo json_encode([
    'success' => $success,
    'append_only_triggers' => $triggerCount,
    'system_enable_records' => $seedCount,
    'covered_action_groups' => count($required),
    'missing' => $missing,
], JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES) . PHP_EOL;

exit($success ? 0 : 1);
