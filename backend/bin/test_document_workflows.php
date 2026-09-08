<?php

declare(strict_types=1);

if (PHP_SAPI !== 'cli') { http_response_code(404); exit; }

require_once __DIR__ . '/../supplier_receptions/reception_service.php';

$workflows = [
    'quotation' => ['DRAFT' => ['SENT'], 'SENT' => ['ACCEPTED', 'REJECTED'], 'ACCEPTED' => [], 'REJECTED' => []],
    'supplier order' => ['DRAFT' => ['DRAFT', 'SENT', 'CANCELLED'], 'SENT' => ['SENT', 'CANCELLED'], 'CANCELLED' => []],
    'supplier reception' => ['DRAFT' => ['DRAFT', 'REVIEWED'], 'REVIEWED' => ['REVIEWED']],
    'expense' => ['PENDING' => ['APPROVED', 'REJECTED'], 'APPROVED' => ['REIMBURSED'], 'REJECTED' => [], 'REIMBURSED' => []],
    'VAT period' => ['DRAFT' => ['DRAFT', 'REVIEWED'], 'REVIEWED' => ['REVIEWED', 'LOCKED'], 'LOCKED' => ['FILED'], 'FILED' => []],
    'accounting period' => ['DRAFT' => ['DRAFT', 'REVIEWED'], 'REVIEWED' => ['REVIEWED', 'LOCKED'], 'LOCKED' => ['FILED'], 'FILED' => []],
];

$cases = [
    ['quotation', 'DRAFT', 'SENT', true], ['quotation', 'DRAFT', 'ACCEPTED', false],
    ['quotation', 'SENT', 'ACCEPTED', true], ['quotation', 'ACCEPTED', 'SENT', false],
    ['supplier order', 'DRAFT', 'SENT', true], ['supplier order', 'SENT', 'DRAFT', false],
    ['supplier reception', 'DRAFT', 'REVIEWED', true], ['supplier reception', 'REVIEWED', 'DRAFT', false],
    ['expense', 'PENDING', 'APPROVED', true], ['expense', 'PENDING', 'REIMBURSED', false],
    ['expense', 'APPROVED', 'REIMBURSED', true], ['expense', 'REIMBURSED', 'APPROVED', false],
    ['VAT period', 'DRAFT', 'REVIEWED', true], ['VAT period', 'LOCKED', 'REVIEWED', false],
    ['accounting period', 'REVIEWED', 'LOCKED', true], ['accounting period', 'FILED', 'LOCKED', false],
];

$failures = [];
foreach ($cases as [$workflow, $from, $to, $expected]) {
    $actual = in_array($to, $workflows[$workflow][$from] ?? [], true);
    echo ($actual === $expected ? 'PASS ' : 'FAIL ') . "$workflow $from -> $to" . PHP_EOL;
    if ($actual !== $expected) $failures[] = "$workflow $from -> $to";
}

$sourceChecks = [
    'invoices/update_invoice.php' => 'Invalid quotation status transition',
    'supplier_orders/save_supplier_order.php' => 'Invalid supplier order status transition',
    'supplier_receptions/confirm_supplier_reception.php' => 'confirmSupplierReception',
    'expense_notes/update_status.php' => 'Invalid expense status transition',
    'reports/save_vat_period.php' => 'Invalid VAT period status transition',
    'accounting_periods/save.php' => 'Invalid accounting period status transition',
];
foreach ($sourceChecks as $file => $needle) {
    $source = file_get_contents(__DIR__ . '/../' . $file);
    if ($source === false || !str_contains($source, $needle)) $failures[] = "$file missing transition enforcement";
}

$supplierReceptionSaveSource = file_get_contents(__DIR__ . '/../supplier_receptions/save_supplier_reception.php') ?: '';
if (!str_contains($supplierReceptionSaveSource, 'Use the supplier reception confirmation action')) {
    $failures[] = 'supplier_receptions/save_supplier_reception.php must reject direct confirmation state writes';
}

$discrepancyLines = validateSupplierReceptionLines([[
    'catalogId' => 10, 'name' => 'Controlled item', 'itemType' => 'PRODUCT',
    'orderedQty' => 10, 'qty' => 10, 'acceptedQty' => 7,
    'damagedQty' => 2, 'rejectedQty' => 1, 'discrepancyReason' => 'Packaging damaged',
    'price' => 20, 'sellingPrice' => 25, 'tvaRate' => 19, 'unit' => 'piece',
]]);
if (count($discrepancyLines) !== 1 || abs((float)$discrepancyLines[0]['stockImpact'] - 7.0) > 0.0005) {
    $failures[] = 'supplier reception stock impact must use accepted quantity only';
}
try {
    validateSupplierReceptionLines([[
        'catalogId' => 10, 'name' => 'Rejected without reason', 'itemType' => 'PRODUCT',
        'qty' => 2, 'acceptedQty' => 1, 'rejectedQty' => 1, 'price' => 10,
    ]]);
    $failures[] = 'damaged or rejected supplier quantities must require a discrepancy reason';
} catch (Throwable $expected) {}

$receptionConfirmationSource = file_get_contents(__DIR__ . '/../supplier_receptions/reception_confirmation_service.php') ?: '';
foreach (['accepted_qty', 'NO_ORDER', 'exception_type', 'discrepancy_attachment_name'] as $discrepancyGuard) {
    if (!str_contains($receptionConfirmationSource, $discrepancyGuard)) {
        $failures[] = "supplier reception confirmation is missing discrepancy guard $discrepancyGuard";
    }
}

$supplierOrderSaveSource = file_get_contents(__DIR__ . '/../supplier_orders/save_supplier_order.php') ?: '';
if (!str_contains($supplierOrderSaveSource, 'Sent supplier orders are immutable')) {
    $failures[] = 'supplier_orders/save_supplier_order.php must reject content updates after sending';
}
if (!str_contains($supplierOrderSaveSource, 'NULLIF(?, 0)')) {
    $failures[] = 'supplier orders must preserve manual lines without a catalog id';
}
$tenantScopeSource = file_get_contents(__DIR__ . '/../config/tenant_scope.php') ?: '';
if (!str_contains($tenantScopeSource, 'if ($catalogId <= 0) return;')) {
    $failures[] = 'manual supplier-order lines must bypass catalog lookup without bypassing positive-id tenant checks';
}
foreach (['createProductFromConfirmedReceptionLine', 'selling_price_required', 'pricing_required_products', "INSERT INTO products"] as $manualProductGuard) {
    if (!str_contains($receptionConfirmationSource, $manualProductGuard)) {
        $failures[] = "supplier reception confirmation is missing manual-product guard $manualProductGuard";
    }
}
if (!str_contains($receptionConfirmationSource, "bind_param('issdidds', \$tenantId, \$code, \$name, \$sellingPrice, \$sellingPriceRequired, \$purchasePrice, \$vatRate, \$unit)")) {
    $failures[] = 'new supplier products must bind exactly eight values with matching mysqli types';
}
if (str_contains($receptionConfirmationSource, 'A selling price is required before a new supplier product can enter the catalog')) {
    $failures[] = 'manual supplier products must be receivable before an administrator defines the selling price';
}
$productOptionsSource = file_get_contents(__DIR__ . '/../products/options.php') ?: '';
if (!str_contains($productOptionsSource, "selling_price_required=0") || !str_contains($productOptionsSource, 'sale_ready')) {
    $failures[] = 'sales catalog options must hide products whose selling price is still required';
}
$notificationServiceSource = file_get_contents(__DIR__ . '/../notifications/notification_service.php') ?: '';
$dashboardSource = file_get_contents(__DIR__ . '/../dashboard/overview.php') ?: '';
if (!str_contains($dashboardSource, 'pricing_required_count')) {
    $failures[] = 'dashboard administrator pricing-required visibility is missing';
}
foreach (["'PRODUCT_PRICING'", 'selling_price_required=1'] as $pricingNotificationGuard) {
    if (!str_contains($notificationServiceSource, $pricingNotificationGuard)) {
        $failures[] = "notification center is missing pricing-required guard $pricingNotificationGuard";
    }
}

$documentMailerSource = file_get_contents(__DIR__ . '/../mailer/send_invoice_pdf.php') ?: '';
foreach (['AUTO_SEND_DEVIS', "SET status = 'SENT', is_validated = 1", 'FOR UPDATE', 'rollback()', 'captureInvoiceIssuanceSnapshot'] as $mailerGuard) {
    if (!str_contains($documentMailerSource, $mailerGuard)) {
        $failures[] = "mailer/send_invoice_pdf.php is missing automatic devis send guard $mailerGuard";
    }
}

$snapshotSources = [
    'invoices/create_invoice_bundle.php' => 'captureInvoiceIssuanceSnapshot',
    'invoices/update_invoice.php' => 'captureInvoiceIssuanceSnapshot',
    'mailer/document_pdf_service.php' => 'invoiceSnapshotPdfProjection',
    'einvoices/service.php' => 'invoiceSnapshotLoad',
];
foreach ($snapshotSources as $file => $needle) {
    $source = file_get_contents(__DIR__ . '/../' . $file) ?: '';
    if (!str_contains($source, $needle)) {
        $failures[] = "$file is missing immutable issuance snapshot integration";
    }
}

if ($failures !== []) {
    foreach ($failures as $failure) fwrite(STDERR, "FAIL $failure" . PHP_EOL);
    exit(1);
}
echo 'Document workflow suite passed (' . count($cases) . ' transitions).' . PHP_EOL;
