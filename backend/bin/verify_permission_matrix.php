<?php

if (PHP_SAPI !== 'cli') { http_response_code(404); exit; }
require_once __DIR__.'/../auth/role_helper.php';

$matrix=[
    'ADMINISTRATOR'=>['allow'=>['stock.view','stock.adjust','products.delete','services.delete','orders.confirm','orders.send','deliveries.deliver','deliveries.send','reports.view','users.manage','clients.delete','invoices.validate','payments.void','withholding.edit','expenses.approve','supplierReceptions.confirm'],'deny'=>[]],
    'COMMERCIAL'=>['allow'=>[
        'invoices.manage','clients.view','clients.create','clients.edit','clients.delete',
        'services.view','services.create','services.edit','services.delete',
        'orders.view','orders.create','orders.edit','orders.delete','orders.confirm','orders.cancel','orders.send',
        'deliveries.view','deliveries.create','deliveries.edit','deliveries.delete','deliveries.confirm','deliveries.cancel','deliveries.deliver','deliveries.send',
        'invoices.view','invoices.create','invoices.edit','invoices.delete',
        'devis.view','devis.create','devis.edit','devis.delete','devis.validate','devis.send',
        'avoirs.view',
    ],'deny'=>[
        'stock.view','stock.adjust','products.view','products.create','products.edit','products.delete','reports.view','users.manage','invoices.validate','invoices.send','invoices.credit',
        'avoirs.create','avoirs.edit','avoirs.delete','avoirs.validate','avoirs.send',
        'payments.view','payments.record','payments.void',
        'withholding.view','withholding.record','withholding.edit',
        'expenses.view','expenses.create','expenses.edit','expenses.delete','expenses.approve',
        'suppliers.view','suppliers.create','suppliers.edit','suppliers.delete',
        'supplierOrders.view','supplierOrders.create','supplierOrders.edit','supplierOrders.delete','supplierOrders.send',
        'supplierReceptions.view','supplierReceptions.create','supplierReceptions.edit','supplierReceptions.delete','supplierReceptions.confirm',
        'supplierInvoices.view','supplierInvoices.create','supplierInvoices.validate','supplierInvoices.credit','supplierPayments.record','supplierReturns.confirm',
    ]],
    'STOCK'=>['allow'=>[
        'stock.view','stock.adjust','products.view','products.create','products.edit','products.delete','orders.view',
        'deliveries.view','deliveries.create','deliveries.edit','deliveries.delete','deliveries.confirm','deliveries.cancel','deliveries.deliver','deliveries.send',
        'suppliers.view','suppliers.create','suppliers.edit','suppliers.delete',
        'supplierOrders.view','supplierOrders.create','supplierOrders.edit','supplierOrders.delete','supplierOrders.send',
        'supplierReceptions.view','supplierReceptions.create','supplierReceptions.edit','supplierReceptions.delete','supplierReceptions.confirm',
        'supplierReturns.confirm',
    ],'deny'=>['clients.view','clients.create','clients.edit','clients.delete','services.view','services.create','services.edit','services.delete','orders.create','orders.edit','orders.delete','orders.confirm','orders.cancel','orders.send','invoices.manage','reports.view','users.manage','expenses.view','expenses.create','expenses.edit','expenses.delete','expenses.approve','supplierInvoices.view','supplierInvoices.create','supplierInvoices.validate','supplierInvoices.credit','supplierPayments.record']],
    'ACCOUNTING'=>['allow'=>[
        'reports.view','payments.manage','expenses.view','expenses.create','expenses.edit','expenses.delete','expenses.approve',
        'invoices.view','invoices.create','invoices.edit','invoices.delete','invoices.validate','invoices.send','invoices.credit',
        'avoirs.view','avoirs.create','avoirs.edit','avoirs.delete','avoirs.validate','avoirs.send',
        'payments.view','payments.record','payments.void',
        'withholding.view','withholding.record','withholding.edit',
        'suppliers.view','suppliers.create','suppliers.edit','suppliers.delete','supplierOrders.view',
        'supplierReceptions.view','supplierReceptions.create','supplierReceptions.edit','supplierReceptions.delete','supplierReceptions.confirm',
        'supplierInvoices.view','supplierInvoices.create','supplierInvoices.validate','supplierInvoices.credit','supplierPayments.record','supplierReturns.confirm',
    ],'deny'=>['clients.view','clients.create','clients.edit','clients.delete','stock.view','stock.adjust','products.view','products.create','products.edit','products.delete','services.view','services.create','services.edit','services.delete','orders.view','orders.create','orders.edit','orders.delete','orders.confirm','orders.cancel','orders.send','deliveries.view','deliveries.create','deliveries.edit','deliveries.delete','deliveries.confirm','deliveries.cancel','deliveries.deliver','deliveries.send','users.manage','devis.view','devis.create','devis.edit','devis.delete','devis.validate','devis.send','supplierOrders.create','supplierOrders.edit','supplierOrders.delete','supplierOrders.send']],
    'UNAUTHORIZED'=>['allow'=>[],'deny'=>['dashboard.view','invoices.manage','users.manage']],
];
$failures=[];
foreach($matrix as $role=>$expectations){
    $permissions=rolePermissions()[$role]??[];
    foreach($expectations['allow'] as $permission){
        if(!in_array('*',$permissions,true)&&!in_array($permission,$permissions,true))$failures[]="$role must allow $permission";
    }
    foreach($expectations['deny'] as $permission){
        if(in_array('*',$permissions,true)||in_array($permission,$permissions,true))$failures[]="$role must deny $permission";
    }
}
foreach(rolePermissions() as $role=>$permissions){
    if($role==='ADMINISTRATOR')continue;
    foreach(['suppliers.manage','supplierOrders.manage','expenses.manage','products.manage','services.manage','stock.manage','orders.manage','deliveries.manage'] as $retiredPermission){
        if(in_array($retiredPermission,$permissions,true))$failures[]="$role must not retain retired permission $retiredPermission";
    }
}
foreach(['FACTURE'=>'invoices','DRAFT'=>'invoices','DEVIS'=>'devis','AVOIR'=>'avoirs'] as $type=>$prefix){
    if(invoiceDocumentPermissionPrefix($type)!==$prefix)$failures[]="$type must map to the $prefix permission prefix";
}
try{invoiceDocumentPermission('FACTURE','unsupported');$failures[]='Unsupported document actions must be rejected';}catch(InvalidArgumentException $expected){}
try{invoiceDocumentPermissionPrefix('UNKNOWN');$failures[]='Unsupported document types must be rejected';}catch(InvalidArgumentException $expected){}
$guards=[
    'ai/assistant-stream.php'=>'userHasPermission($conn, $userId, \'assistant.use\')',
    'products/add_stock_movement.php'=>"'stock.adjust'",
    'products/create_stock_adjustment.php'=>"'stock.adjust'",
    'supplier_invoices/save_supplier_invoice.php'=>"'supplierInvoices.create'",
    'dashboard/overview.php'=>"'expenses.view'",
    'taxes/assign_product_tax_profile.php'=>'requireAnyPermission',
    'taxes/save_tax_profile.php'=>'requireAnyPermission',
    'taxes/get_tax_profiles.php'=>'requireAnyPermission',
    'invoice_settlements/get.php'=>"['invoices.view','payments.view','withholding.view']",
    'invoice_settlements/add_payment.php'=>"'payments.record'",
    'invoice_settlements/void_payment.php'=>"'payments.void'",
    'invoice_settlements/add_withholding.php'=>"'withholding.record'",
    'invoice_settlements/update_withholding.php'=>"'withholding.edit'",
    'invoices/recompute_invoice_totals.php'=>'requireInvoiceDocumentPermission',
    'invoices/create_invoice_bundle.php'=>"'validate'",
    'invoices/update_invoice.php'=>'requireInvoiceDocumentPermission',
    'mailer/send_invoice_pdf.php'=>'document_id',
    'einvoices/prepare.php'=>"'invoices.send'",
    'einvoices/retry.php'=>"'invoices.send'",
];
$disabledPublic=['test.php','stress.php','database_inspect.php','mail.php','servertest.php','ai/assistant.php'];
foreach($disabledPublic as $file){
    $path=__DIR__.'/../'.$file;
    if(!is_file($path))continue;
    $source=file_get_contents($path);
    if($source===false||!str_contains($source,'http_response_code(404)')||preg_match('/DB_PASS|mysqli|stress_seed|DEBUG_MODE/',$source))$failures[]="$file must remain a credential-free 404 stub";
}
$databaseConfigSource=file_get_contents(__DIR__.'/../config/db.php')?:'';
if(preg_match('/\$_ENV\[\'DB_(?:HOST|USER|PASS|NAME)\'\]\s*\?\?\s*[\'\"][^\'\"]+[\'\"]/', $databaseConfigSource)){
    $failures[]='config/db.php must not contain literal database credential fallbacks';
}
$dashboardCacheSource=file_get_contents(__DIR__.'/../dashboard/cache.php')?:'';
foreach(["storage/cache/dashboard","hash('sha256'",'chmod($path,0600)'] as $cacheGuard){
    if(!str_contains($dashboardCacheSource,$cacheGuard))$failures[]="dashboard/cache.php is missing private cache guard $cacheGuard";
}
$storageAccessSource=file_get_contents(__DIR__.'/../storage/.htaccess')?:'';
if(!str_contains($storageAccessSource,'Require all denied'))$failures[]='storage/.htaccess must deny direct HTTP access';
$gitignoreSource=file_get_contents(dirname(__DIR__,2).'/.gitignore')?:'';
if(!str_contains($gitignoreSource,'backend/storage/cache/*'))$failures[]='dashboard runtime cache must remain ignored by Git';
foreach($guards as $file=>$needle){
    $path=__DIR__.'/../'.$file;
    if(!is_file($path))continue;
    $source=file_get_contents($path);
    if($source===false||!str_contains($source,$needle))$failures[]="$file is missing guard $needle";
}
$selfServiceAuth=['auth/auth_required.php','auth/change_password.php','auth/confirm_2fa.php','auth/disable_2fa.php','auth/enable_2fa.php','auth/me.php','auth/revoke_all_sessions.php','auth/send_verification_email.php','auth/twofa_status.php','auth/verify_email.php','user/update_account.php'];
$iterator=new RecursiveIteratorIterator(
    new RecursiveDirectoryIterator(dirname(__DIR__), FilesystemIterator::SKIP_DOTS),
    RecursiveIteratorIterator::LEAVES_ONLY,
    RecursiveIteratorIterator::CATCH_GET_CHILD
);
foreach($iterator as $entry){
    if(!$entry->isFile()||$entry->getExtension()!=='php')continue;
    $relative=str_replace('\\','/',substr($entry->getPathname(),strlen(dirname(__DIR__))+1));
    if(str_starts_with($relative,'bin/')||str_starts_with($relative,'vendor/')||in_array($relative,$selfServiceAuth,true))continue;
    $source=file_get_contents($entry->getPathname());
    if(str_contains($source,'requireAuth(')&&!preg_match('/require(?:Any)?Permission\(|requireAdministratorRole\(|requireInvoiceDocumentPermission\(|requireAnyInvoiceDocumentView\(/',$source))$failures[]="$relative authenticates without an endpoint permission guard";
}

$convertedFinanceFiles=[
    'invoices/add_invoice.php','invoices/create_invoice_bundle.php','invoices/delete_invoice.php',
    'invoices/get_invoice_by_id.php','invoices/get_invoices.php','invoices/list_page.php',
    'invoices/options.php','invoices/recompute_invoice_totals.php','invoices/update_invoice.php',
    'invoices/update_invoice_status.php','invoice_items/add_erp_invoice_items.php',
    'invoice_items/add_invoice_item.php','invoice_items/delete_invoice_item.php',
    'invoice_items/get_invoice_items.php','invoice_items/update_invoice_item.php',
    'invoice_settlements/add_payment.php','invoice_settlements/void_payment.php',
    'invoice_settlements/add_withholding.php','invoice_settlements/update_withholding.php',
    'invoice_settlements/get.php','invoice_settlements/download.php',
    'einvoices/get.php','einvoices/prepare.php','einvoices/retry.php',
];
foreach($convertedFinanceFiles as $file){
    $source=file_get_contents(__DIR__.'/../'.$file);
    if($source===false){$failures[]="$file could not be read";continue;}
    if(preg_match("/'(?:invoices|devis|avoirs|payments|withholding)\\.manage'/",$source)){
        $failures[]="$file must not use a broad legacy finance permission";
    }
}
$convertedClientFiles=[
    'clients/add_client.php'=>"'clients.create'",
    'clients/delete_client.php'=>"'clients.delete'",
    'clients/get_client.php'=>"'clients.view'",
    'clients/get_clients.php'=>"'clients.view'",
    'clients/get_clients_all_with_archieved.php'=>"'clients.view'",
    'clients/list_page.php'=>"'clients.view'",
    'clients/options.php'=>"'clients.view'",
    'clients/update_client.php'=>"'clients.edit'",
];
foreach($convertedClientFiles as $file=>$guard){
    $source=file_get_contents(__DIR__.'/../'.$file)?:'';
    if(str_contains($source,"'clients.manage'"))$failures[]="$file must not use the broad clients.manage permission";
    if(!str_contains($source,$guard))$failures[]="$file is missing action-level guard $guard";
}
$convertedExpenseFiles=[
    'expense_notes/add.php'=>"'expenses.create'",
    'expense_notes/delete.php'=>"'expenses.delete'",
    'expense_notes/get.php'=>"'expenses.view'",
    'expense_notes/list.php'=>"'expenses.view'",
    'expense_notes/list_page.php'=>"'expenses.view'",
    'expense_notes/update.php'=>"'expenses.edit'",
    'expense_notes/update_status.php'=>"'expenses.approve'",
];
foreach($convertedExpenseFiles as $file=>$guard){
    $source=file_get_contents(__DIR__.'/../'.$file)?:'';
    if(str_contains($source,"'expenses.manage'"))$failures[]="$file must not use the broad expenses.manage permission";
    if(!str_contains($source,$guard))$failures[]="$file is missing action-level guard $guard";
}
$convertedSupplierFiles=[
    'suppliers/add_supplier.php'=>["'suppliers.create'"],
    'suppliers/delete_supplier.php'=>["'suppliers.delete'"],
    'suppliers/get_supplier.php'=>["'suppliers.view'"],
    'suppliers/get_suppliers.php'=>["'suppliers.view'"],
    'suppliers/list_page.php'=>["'suppliers.view'"],
    'suppliers/options.php'=>["'suppliers.view'"],
    'suppliers/update_supplier.php'=>["'suppliers.edit'"],
    'supplier_orders/delete_supplier_order.php'=>["'supplierOrders.delete'"],
    'supplier_orders/get_supplier_orders.php'=>["'supplierOrders.view'"],
    'supplier_orders/list_page.php'=>["'supplierOrders.view'"],
    'supplier_orders/save_supplier_order.php'=>["'supplierOrders.create'","'supplierOrders.edit'","'supplierOrders.send'"],
    'supplier_receptions/delete_supplier_reception.php'=>["'supplierReceptions.delete'"],
    'supplier_receptions/get_supplier_receptions.php'=>["'supplierReceptions.view'"],
    'supplier_receptions/list_page.php'=>["'supplierReceptions.view'"],
    'supplier_receptions/save_supplier_reception.php'=>["'supplierReceptions.edit'","'supplierReceptions.create'"],
    'supplier_receptions/confirm_supplier_reception.php'=>["'supplierReceptions.confirm'","'expenses.create'"],
    'supplier_receptions/upload_discrepancy_attachment.php'=>["'supplierReceptions.edit'"],
    'supplier_receptions/download_discrepancy_attachment.php'=>["'supplierReceptions.view'"],
    'products/apply_supplier_bill_stock.php'=>["'supplierReceptions.confirm'"],
    'supplier_invoices/save_supplier_invoice.php'=>["'supplierInvoices.create'","'supplierInvoices.validate'"],
    'supplier_invoices/list_page.php'=>["'supplierInvoices.view'"],
    'supplier_invoices/get_supplier_invoice.php'=>["'supplierInvoices.view'"],
    'supplier_invoices/matching_options.php'=>["'supplierInvoices.view'","'supplierInvoices.create'"],
    'supplier_invoices/validate_supplier_invoice.php'=>["'supplierInvoices.validate'"],
    'supplier_invoices/save_supplier_credit_note.php'=>["'supplierInvoices.credit'"],
    'supplier_invoices/add_supplier_payment.php'=>["'supplierPayments.record'"],
    'supplier_returns/confirm_supplier_return.php'=>["'supplierReturns.confirm'"],
];
foreach($convertedSupplierFiles as $file=>$guards){
    $source=file_get_contents(__DIR__.'/../'.$file)?:'';
    if(preg_match("/'(?:suppliers|supplierOrders|expenses|payments)\\.manage'/",$source))$failures[]="$file must not use a broad legacy purchasing permission";
    foreach($guards as $guard){
        if(!str_contains($source,$guard))$failures[]="$file is missing action-level guard $guard";
    }
}
$receptionConfirmationSource=file_get_contents(__DIR__.'/../supplier_receptions/reception_confirmation_service.php')?:'';
foreach(['begin_transaction','recordProductStockMovement','created_expense_id','confirmation_hash','SUPPLIER_RECEPTION.CONFIRMED','erp_supplier_orders SET status'] as $confirmationGuard){
    if(!str_contains($receptionConfirmationSource,$confirmationGuard))$failures[]="Atomic supplier reception confirmation is missing $confirmationGuard";
}
$receptionSaveSource=file_get_contents(__DIR__.'/../supplier_receptions/save_supplier_reception.php')?:'';
if(!str_contains($receptionSaveSource,'Use the supplier reception confirmation action'))$failures[]='Draft reception save must reject direct REVIEWED status writes';
$supplierInvoiceSaveSource=file_get_contents(__DIR__.'/../supplier_invoices/save_supplier_invoice.php')?:'';
foreach(['stock_applied','billed_qty','supplier_order_id','FOR UPDATE','unbilled accepted reception quantity'] as $invoiceMatchGuard){
    if(!str_contains($supplierInvoiceSaveSource,$invoiceMatchGuard))$failures[]="Supplier invoice matching integrity is missing $invoiceMatchGuard";
}
$convertedCatalogFiles=[
    'products/add_product.php'=>["'services.create'","'products.create'"],
    'products/update_product.php'=>["'services.edit'","'products.edit'"],
    'products/delete_product.php'=>["'services.delete'","'products.delete'"],
    'products/get_product.php'=>["'products.view'","'services.view'"],
    'products/get_products.php'=>["'products.view'","'services.view'"],
    'products/list_page.php'=>["'products.view'","'services.view'"],
    'products/options.php'=>["'products.view'","'services.view'"],
    'products/get_product_stock_history.php'=>["'stock.view'"],
    'products/get_stock_valuation.php'=>["'stock.view'"],
    'products/get_cogs.php'=>["'stock.view'"],
    'products/add_stock_movement.php'=>["'stock.adjust'"],
    'products/create_stock_adjustment.php'=>["'stock.adjust'"],
];
$convertedWorkflowFiles=[
    'bon_commandes/list.php'=>["'orders.view'"],
    'bon_commandes/get.php'=>["'orders.view'"],
    'bon_commandes/save.php'=>["'orders.create'","'orders.edit'"],
    'bon_commandes/delete.php'=>["'orders.delete'"],
    'bon_commandes/action.php'=>["'orders.confirm'","'orders.cancel'"],
    'bon_livraisons/list.php'=>["'deliveries.view'"],
    'bon_livraisons/get.php'=>["'deliveries.view'"],
    'bon_livraisons/save.php'=>["'deliveries.create'","'deliveries.edit'"],
    'bon_livraisons/delete.php'=>["'deliveries.delete'"],
    'bon_livraisons/action.php'=>["'deliveries.confirm'","'deliveries.cancel'","'deliveries.deliver'"],
];
foreach([...$convertedCatalogFiles,...$convertedWorkflowFiles] as $file=>$guards){
    $source=file_get_contents(__DIR__.'/../'.$file)?:'';
    if(preg_match("/'(?:products|services|stock|orders|deliveries)\.manage'/",$source))$failures[]="$file must not use a broad legacy catalog/workflow permission";
    foreach($guards as $guard){
        if(!str_contains($source,$guard))$failures[]="$file is missing action-level guard $guard";
    }
}
$settlementSource=file_get_contents(__DIR__.'/../invoice_settlements/get.php')?:'';
if(str_contains($settlementSource,'SELECT p.*')||str_contains($settlementSource,'SELECT w.*')||str_contains($settlementSource,'proof_path path')||str_contains($settlementSource,'attachment_path path')){
    $failures[]='invoice_settlements/get.php must explicitly project safe ledger fields';
}
$invoiceListSource=file_get_contents(__DIR__.'/../invoices/get_invoices.php')?:'';
foreach(['json_finsys','json_return','stat_api','id_extract','id_lettrage'] as $sensitiveField){
    if(str_contains($invoiceListSource,$sensitiveField))$failures[]="invoices/get_invoices.php must not expose $sensitiveField";
}
$mailerSource=file_get_contents(__DIR__.'/../mailer/send_invoice_pdf.php')?:'';
foreach(['document_id','createServerDocumentPdf',"array_key_exists('pdf'",'SERVER_DATABASE'] as $mailerGuard){
    if(!str_contains($mailerSource,$mailerGuard))$failures[]="mailer/send_invoice_pdf.php is missing trusted document guard $mailerGuard";
}
if(!str_contains($mailerSource,"'supplierOrders.send'"))$failures[]='Purchase-order email must require supplierOrders.send';
if(!str_contains($mailerSource,"'orders.send'"))$failures[]='Sales-order email must require orders.send';
if(!str_contains($mailerSource,"'deliveries.send'"))$failures[]='Delivery-note email must require deliveries.send';
if(str_contains($mailerSource,"'supplierOrders.manage'"))$failures[]='Purchase-order email must not use supplierOrders.manage';
$pdfDownloadSource=file_get_contents(__DIR__.'/../mailer/download_document_pdf.php')?:'';
foreach(['authTenantId($auth)','authActorId($auth)',"'orders.view'", "'deliveries.view'", "'supplierOrders.view'",'requireInvoiceDocumentPermission','createServerDocumentPdf','DOCUMENT_PDF.DOWNLOADED',"'Content-Type: application/pdf'"] as $pdfDownloadGuard){
    if(!str_contains($pdfDownloadSource,$pdfDownloadGuard))$failures[]="mailer/download_document_pdf.php is missing trusted download guard $pdfDownloadGuard";
}
foreach(["'orders.send'", "'deliveries.send'", "'supplierOrders.send'"] as $mutationPermission){
    if(str_contains($pdfDownloadSource,$mutationPermission))$failures[]="PDF preview must use view permission, not mutation permission $mutationPermission";
}
$dashboardSource=file_get_contents(__DIR__.'/../dashboard/overview.php')?:'';
foreach(["'suppliers.view'","'supplierOrders.view'","'expenses.view'"] as $dashboardPermission){
    if(!str_contains($dashboardSource,$dashboardPermission))$failures[]="dashboard/overview.php is missing granular capability $dashboardPermission";
}
$notificationListSource=file_get_contents(__DIR__.'/../notifications/list.php')?:'';
$notificationMarkSource=file_get_contents(__DIR__.'/../notifications/mark_read.php')?:'';
$notificationServiceSource=file_get_contents(__DIR__.'/../notifications/notification_service.php')?:'';
foreach (['authTenantId($auth)','authActorId($auth)',"'dashboard.view'",'currentOperationalNotifications'] as $notificationGuard) {
    if (!str_contains($notificationListSource, $notificationGuard)) $failures[]="notifications/list.php is missing guard $notificationGuard";
    if (!str_contains($notificationMarkSource, $notificationGuard)) $failures[]="notifications/mark_read.php is missing guard $notificationGuard";
}
foreach (['array_fill_keys','isset($allowed[$key])','NOTIFICATION.'] as $notificationMutationGuard) {
    if (!str_contains($notificationMarkSource, $notificationMutationGuard)) $failures[]="notifications/mark_read.php is missing mutation guard $notificationMutationGuard";
}
foreach (["user_id=?", 'userHasPermission($conn, $actorId'] as $notificationScopeGuard) {
    if (!str_contains($notificationServiceSource, $notificationScopeGuard)) $failures[]="notification service is missing tenant/role scope $notificationScopeGuard";
}
if (str_contains($notificationServiceSource, 'SELECT *')) $failures[]='notification service must explicitly project safe fields';
$mobileAccountingSource=file_get_contents(__DIR__.'/../accounting/mobile_review.php')?:'';
foreach (['authTenantId($auth)','authActorId($auth)','requireAnyPermission','userHasPermission($conn, $actorId','user_id=?',"LIMIT 30"] as $accountingGuard) {
    if (!str_contains($mobileAccountingSource, $accountingGuard)) $failures[]="accounting/mobile_review.php is missing guard $accountingGuard";
}
if (str_contains($mobileAccountingSource, 'supplierInvoiceHeaderSelect')) $failures[]='accounting/mobile_review.php must not run the unbounded supplier matching projection';
if (str_contains($mobileAccountingSource, 'requireAuth()->id')) $failures[]='accounting/mobile_review.php must separate actor and tenant identity';
foreach (['proof_path','attachment_path','created_by','recorded_by'] as $sensitiveAccountingField) {
    if (str_contains($mobileAccountingSource, "'$sensitiveAccountingField'=>")) $failures[]="accounting/mobile_review.php must not return $sensitiveAccountingField";
}
$pdfServiceSource=file_get_contents(__DIR__.'/../mailer/document_pdf_service.php')?:'';
foreach(['is_validated','i.user_id = ?','o.user_id = ?','d.user_id = ?','Only a confirmed','Only a sent supplier order'] as $pdfGuard){
    if(!str_contains($pdfServiceSource,$pdfGuard))$failures[]="mailer/document_pdf_service.php is missing trusted database guard $pdfGuard";
}
$safeErrorResponseFiles=['mailer/send_invoice_pdf.php','user/invite_member.php','auth/send_verification_email.php','dashboard/overview.php'];
foreach($safeErrorResponseFiles as $file){
    $source=file_get_contents(__DIR__.'/../'.$file)?:'';
    if(str_contains($source,"'debug' =>"))$failures[]="$file must not expose exception debug details in API responses";
}
$protectedReportErrorFiles=[
    'reports/audit_entity_timeline.php','reports/contribution_periods.php','reports/drilldown.php',
    'reports/employer_declaration.php','reports/filing_archives.php','reports/fiscal_reconciliation.php',
    'reports/overview.php','reports/presets/save.php','reports/queue_export.php',
    'reports/queue_reconciliation.php','reports/reopen_vat_period.php','reports/save_contribution_config.php',
    'reports/save_contribution_period.php','reports/save_employer_declaration_line.php',
    'reports/save_fiscal_adjustment.php','reports/save_tax_schedule_entry.php','reports/save_vat_period.php',
    'reports/tax_schedules.php','reports/vat_periods.php',
];
foreach($protectedReportErrorFiles as $file){
    $source=file_get_contents(__DIR__.'/../'.$file)?:'';
    if(!str_contains($source,'reportFailureResponse'))$failures[]="$file must use the safe report error boundary";
    if(preg_match('/[\'\"]message[\'\"]\s*=>\s*\$[A-Za-z_][A-Za-z0-9_]*->getMessage\(\)/',$source)){
        $failures[]="$file must not return exception messages directly";
    }
}
$reportErrorSource=file_get_contents(__DIR__.'/../reports/report_error.php')?:'';
foreach(['InvalidArgumentException','OutOfBoundsException','DomainException','structuredLog',"'REPORT.ENDPOINT_FAILED'"] as $reportErrorGuard){
    if(!str_contains($reportErrorSource,$reportErrorGuard))$failures[]="reports/report_error.php is missing guard $reportErrorGuard";
}
$reportExportSource=file_get_contents(__DIR__.'/../reports/export.php')?:'';
foreach(['REPORT.EXPORT_FAILED','Could not generate the report export.','http_response_code(500)'] as $reportExportGuard){
    if(!str_contains($reportExportSource,$reportExportGuard))$failures[]="reports/export.php is missing safe failure guard $reportExportGuard";
}
$aiInvoiceSource=file_get_contents(__DIR__.'/../ai/actions/create_invoice.php')?:'';
if(!str_contains($aiInvoiceSource,'AI_INVOICE_ACTION_DISABLED'))$failures[]='AI invoice creation must remain fail-closed while deferred';
$aiBootstrapSource=file_get_contents(__DIR__.'/../ai/actions/_bootstrap.php')?:'';
foreach(['create_client.php','update_client.php','delete_client.php','create_product.php','update_product.php','delete_product.php','create_invoice.php'] as $mutationScript){
    if(!str_contains($aiBootstrapSource,$mutationScript))$failures[]="AI mutation gate is missing $mutationScript";
}
if(!str_contains($aiBootstrapSource,'AI_MUTATION_ACTIONS_DISABLED'))$failures[]='AI mutations must remain centrally fail-closed while deferred';
$bundleSource=file_get_contents(__DIR__.'/../invoices/create_invoice_bundle.php')?:'';
$bundleAssertions=[
    "\$invoice_type !== 'FACTURE'"=>'FACTURE-only contract',
    "\$status !== 'UNPAID'"=>'initial UNPAID status',
    "?, ?, 1, 'F', ?"=>'persisted validation flag',
    'authActorId($authUser)'=>'actor-aware authentication',
    "auditLog(\$conn, \$user_id, \$actorId, 'INVOICE.ISSUED'"=>'actor-aware issue audit',
    "'invoice.bundle.create'"=>'backward-compatible idempotency namespace',
    'applyIssuedBundleStock'=>'atomic stock application',
    "LIMIT 1 FOR UPDATE"=>'concurrency lock',
    'Create catalog products before issuing the invoice'=>'no implicit catalog mutation',
];
foreach($bundleAssertions as $needle=>$label){
    if(!str_contains($bundleSource,$needle))$failures[]="invoices/create_invoice_bundle.php is missing $label";
}
if(substr_count($bundleSource,"'invoice.bundle.create'")<2)$failures[]='Invoice bundle claim and completion must share the legacy idempotency namespace';
foreach($failures as $failure)echo "FAIL $failure\n";
if(!$failures)echo "PASS role expectations and sensitive endpoint guards\n";
exit($failures?1:0);
