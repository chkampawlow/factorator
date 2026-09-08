<?php

declare(strict_types=1);

if (PHP_SAPI !== 'cli') {
    http_response_code(404);
    exit;
}

require_once __DIR__ . '/../auth/role_helper.php';
require_once __DIR__ . '/../config/field_projection.php';

$failures = [];
function projectionCheck(bool $condition, string $label, array &$failures): void
{
    echo ($condition ? 'PASS ' : 'FAIL ') . $label . PHP_EOL;
    if (!$condition) $failures[] = $label;
}

$client = ['id'=>7,'type'=>'company','name'=>'Client','email'=>'c@example.test','phone'=>'1','address'=>'Tunis','fiscalId'=>'SECRET-FISCAL','cin'=>'SECRET-CIN','payment_terms_days'=>60];
$stockClient = projectClientFields($client, 'STOCK');
$commercialClient = projectClientFields($client, 'COMMERCIAL');
projectionCheck(!isset($stockClient['fiscalId'],$stockClient['cin'],$stockClient['payment_terms_days']) && $stockClient['name']==='Client', 'STOCK receives delivery contact but no fiscal/CIN/payment-term identity', $failures);
projectionCheck(($commercialClient['fiscalId']??'')==='SECRET-FISCAL' && ($commercialClient['payment_terms_days']??0)===60, 'COMMERCIAL retains fields required for customer documents', $failures);

$product = ['id'=>9,'code'=>'P-9','name'=>'Product','price'=>'150','stock_quantity'=>'4','last_purchase_price'=>'100','average_cost'=>'90','reorder_point'=>'3','stock_value'=>'360'];
$commercialProduct = projectProductFields($product, 'COMMERCIAL');
$stockProduct = projectProductFields($product, 'STOCK');
projectionCheck(!isset($commercialProduct['last_purchase_price'],$commercialProduct['average_cost'],$commercialProduct['reorder_point'],$commercialProduct['stock_value']), 'COMMERCIAL cannot receive purchasing cost, valuation or reorder policy fields', $failures);
projectionCheck(($stockProduct['average_cost']??'')==='90' && ($stockProduct['reorder_point']??'')==='3', 'STOCK retains inventory cost and replenishment fields', $failures);

$invoice = ['id'=>12,'invoice'=>'FAC-12','total'=>'120','payment_method'=>'TRANSFER','tx_retenue'=>'1','user_id'=>4,'idempotency_key'=>'internal'];
$commercialInvoice = projectInvoiceFields($invoice, 'COMMERCIAL');
$accountingInvoice = projectInvoiceFields($invoice, 'ACCOUNTING');
projectionCheck(!isset($commercialInvoice['payment_method'],$commercialInvoice['tx_retenue'],$commercialInvoice['user_id'],$commercialInvoice['idempotency_key']), 'COMMERCIAL document projection excludes settlement and infrastructure fields', $failures);
projectionCheck(($accountingInvoice['payment_method']??'')==='TRANSFER' && !isset($accountingInvoice['user_id']), 'ACCOUNTING retains settlement data without infrastructure identifiers', $failures);

$stockDashboard = projectDashboardFields(['success'=>true,'sales'=>['revenue_total'=>10],'accounting'=>['monthly_expenses'=>2],'inventory'=>['product_count'=>3],'administration'=>['active_members'=>4],'recent_invoices'=>[['id'=>1]]], 'STOCK');
projectionCheck(isset($stockDashboard['inventory']) && !isset($stockDashboard['sales'],$stockDashboard['accounting'],$stockDashboard['administration'],$stockDashboard['recent_invoices']), 'STOCK dashboard contains inventory workspace only', $failures);
projectionCheck(array_keys(projectNotificationCounts(['unpaid_count'=>2,'low_stock_count'=>3,'client_count'=>4,'product_count'=>5], 'ACCOUNTING'))===['unpaid_count'], 'ACCOUNTING notification response excludes catalog and client counts', $failures);

$endpointChecks = [
    'clients/options.php', 'clients/get_client.php', 'clients/get_clients.php', 'clients/list_page.php',
    'products/options.php', 'products/get_product.php', 'products/get_products.php', 'products/list_page.php',
    'invoices/get_invoice_by_id.php', 'invoices/get_invoices.php', 'invoices/list_page.php', 'invoices/options.php',
    'dashboard/overview.php', 'notifications/overview.php',
    'bon_commandes/get.php', 'bon_commandes/list.php', 'bon_livraisons/get.php', 'bon_livraisons/list.php',
];
foreach ($endpointChecks as $file) {
    $source = file_get_contents(__DIR__ . '/../' . $file) ?: '';
    if (!str_contains($source, 'field_projection.php')) $failures[] = "$file is missing role field projection";
}

$notificationServiceSource = file_get_contents(__DIR__ . '/../notifications/notification_service.php') ?: '';
foreach (['notificationItem(', 'currentOperationalNotifications(', 'authTenantId', 'authActorId'] as $guard) {
    $sources = $guard === 'authTenantId' || $guard === 'authActorId'
        ? (file_get_contents(__DIR__ . '/../notifications/list.php') ?: '') . (file_get_contents(__DIR__ . '/../notifications/overview.php') ?: '')
        : $notificationServiceSource;
    if (!str_contains($sources, $guard)) $failures[] = "notification feed is missing safe projection guard $guard";
}
if (str_contains($notificationServiceSource, 'SELECT *')) {
    $failures[] = 'notification feed must explicitly project safe fields';
}

if ($failures !== []) {
    foreach ($failures as $failure) fwrite(STDERR, "FAIL $failure" . PHP_EOL);
    exit(1);
}
echo 'Role field projection verification passed.' . PHP_EOL;
