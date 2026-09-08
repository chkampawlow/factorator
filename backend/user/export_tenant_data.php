<?php

require_once __DIR__ . '/../config/response.php';
require_once __DIR__ . '/../config/db.php';
require_once __DIR__ . '/../config/audit.php';
require_once __DIR__ . '/../auth/auth_required.php';
require_once __DIR__ . '/../auth/role_helper.php';

function exportRows(mysqli $conn,string $sql,int $userId):array{
    $stmt=$conn->prepare($sql);$stmt->bind_param('i',$userId);$stmt->execute();
    $rows=$stmt->get_result()->fetch_all(MYSQLI_ASSOC);$stmt->close();
    $excluded=['password_hash','google2fa_secret','token_hash','request_hash','idempotency_key','proof_path','attachment_path'];
    foreach($rows as &$row)foreach($excluded as $field)unset($row[$field]);
    return $rows;
}

try{
    if($_SERVER['REQUEST_METHOD']!=='GET')jsonResponse(['success'=>false,'message'=>'Method not allowed'],405);
    if(!class_exists('ZipArchive'))throw new Exception('ZIP support is unavailable');
    $userId=(int)requireAuth()->id;$conn=db();requireAdministratorRole($conn,$userId);
    $datasets=[
        'company'=>"SELECT id,email,organization_name,fiscal_id,phone,address,role,account_status,email_verified_at,created_at FROM users WHERE id=?",
        'clients'=>"SELECT * FROM clients WHERE user_id=?",
        'suppliers'=>"SELECT * FROM suppliers WHERE user_id=?",
        'products'=>"SELECT * FROM products WHERE user_id=?",
        'invoices'=>"SELECT * FROM erp_invoices WHERE user_id=?",
        'invoice_items'=>"SELECT ii.* FROM erp_invoice_items ii JOIN erp_invoices i ON i.id=ii.invoice_id WHERE i.user_id=?",
        'invoice_payments'=>"SELECT id,invoice_id,user_id,amount,exchange_rate,exchange_rate_date,amount_tnd,payment_date,method,account_name,reference_number,proof_name,proof_mime,status,recorded_by,created_at,voided_by,voided_at,void_reason FROM erp_invoice_payments WHERE user_id=?",
        'invoice_withholdings'=>"SELECT id,invoice_id,user_id,withholding_type,rate,calculation_base,withheld_amount,certificate_number,certificate_date,certificate_status,attachment_name,attachment_mime,recorded_by,created_at FROM erp_invoice_withholdings WHERE user_id=?",
        'sales_orders'=>"SELECT * FROM erp_sales_orders WHERE user_id=?",
        'sales_order_items'=>"SELECT oi.* FROM erp_sales_order_items oi JOIN erp_sales_orders o ON o.id=oi.sales_order_id WHERE o.user_id=?",
        'delivery_notes'=>"SELECT * FROM erp_delivery_notes WHERE user_id=?",
        'delivery_note_items'=>"SELECT di.* FROM erp_delivery_note_items di JOIN erp_delivery_notes d ON d.id=di.delivery_note_id WHERE d.user_id=?",
        'supplier_orders'=>"SELECT * FROM erp_supplier_orders WHERE user_id=?",
        'supplier_order_items'=>"SELECT oi.* FROM erp_supplier_order_items oi JOIN erp_supplier_orders o ON o.id=oi.supplier_order_id WHERE o.user_id=?",
        'supplier_receptions'=>"SELECT * FROM erp_supplier_receptions WHERE user_id=?",
        'supplier_reception_items'=>"SELECT ri.* FROM erp_supplier_reception_items ri JOIN erp_supplier_receptions r ON r.id=ri.supplier_reception_id WHERE r.user_id=?",
        'supplier_invoices'=>"SELECT * FROM erp_supplier_invoices WHERE user_id=?",
        'supplier_invoice_items'=>"SELECT ii.* FROM erp_supplier_invoice_items ii JOIN erp_supplier_invoices i ON i.id=ii.supplier_invoice_id WHERE i.user_id=?",
        'supplier_payments'=>"SELECT id,user_id,supplier_invoice_id,amount,exchange_rate,exchange_rate_date,amount_tnd,payment_date,method,account,reference_number,recorded_by,created_at,voided_at FROM erp_supplier_payments WHERE user_id=?",
        'supplier_credit_notes'=>"SELECT * FROM erp_supplier_credit_notes WHERE user_id=?",
        'supplier_returns'=>"SELECT * FROM erp_supplier_returns WHERE user_id=?",
        'supplier_return_items'=>"SELECT ri.* FROM erp_supplier_return_items ri JOIN erp_supplier_returns r ON r.id=ri.supplier_return_id WHERE r.user_id=?",
        'expenses'=>"SELECT * FROM expense_notes WHERE user_id=?",
        'stock_movements'=>"SELECT * FROM product_stock_movements WHERE user_id=?",
        'inventory_adjustments'=>"SELECT * FROM erp_inventory_adjustments WHERE user_id=?",
        'tax_profiles'=>"SELECT * FROM erp_tax_profiles WHERE user_id=?",
        'accounting_periods'=>"SELECT * FROM erp_accounting_periods WHERE user_id=?",
        'electronic_invoice_outbox'=>"SELECT id,invoice_id,user_id,format_version,payload_json,payload_sha256,status,certificate_thumbprint,provider_identifier,attempt_count,last_attempt_at,last_error_code,last_error_message,created_at,updated_at FROM erp_einvoice_outbox WHERE user_id=?",
        'document_sequences'=>"SELECT * FROM erp_document_number_sequences WHERE user_id=?",
        'audit_log'=>"SELECT id,tenant_id,actor_id,action,entity_type,entity_id,before_values,after_values,request_id,source,created_at FROM app_audit_log WHERE tenant_id=?",
    ];
    $zipPath=tempnam(sys_get_temp_dir(),'el-fatoura-export-');if($zipPath===false)throw new Exception('Could not create export');
    $zip=new ZipArchive();if($zip->open($zipPath,ZipArchive::OVERWRITE)!==true)throw new Exception('Could not open export archive');
    $counts=[];foreach($datasets as $name=>$sql){$rows=exportRows($conn,$sql,$userId);$counts[$name]=count($rows);$zip->addFromString($name.'.json',json_encode($rows,JSON_PRETTY_PRINT|JSON_UNESCAPED_UNICODE|JSON_UNESCAPED_SLASHES|JSON_INVALID_UTF8_SUBSTITUTE));}
    $attachmentRoot=dirname(__DIR__).'/storage/accounting/'.$userId;
    if(is_dir($attachmentRoot)){$iterator=new RecursiveIteratorIterator(new RecursiveDirectoryIterator($attachmentRoot,FilesystemIterator::SKIP_DOTS));foreach($iterator as $file)if($file->isFile())$zip->addFile($file->getPathname(),'attachments/'.$iterator->getSubPathName());}
    $manifest=['format'=>'EL_FATOURA_TENANT_EXPORT_V1','exported_at'=>gmdate(DATE_ATOM),'tenant_id'=>$userId,'datasets'=>$counts];
    $zip->addFromString('manifest.json',json_encode($manifest,JSON_PRETTY_PRINT|JSON_UNESCAPED_SLASHES));$zip->close();
    auditLog($conn,$userId,$userId,'TENANT.DATA_EXPORTED','TENANT',$userId,null,['datasets'=>$counts,'attachments_included'=>is_dir($attachmentRoot)]);
    header('Content-Type: application/zip');header('Content-Disposition: attachment; filename="el-fatoura-company-export-'.gmdate('Ymd-His').'.zip"');header('Content-Length: '.filesize($zipPath));header('Cache-Control: no-store');readfile($zipPath);unlink($zipPath);exit;
}catch(Throwable $e){if(isset($zipPath)&&is_file($zipPath))unlink($zipPath);structuredLog('ERROR','TENANT.DATA_EXPORT_FAILED',['exception'=>get_class($e),'message'=>$e->getMessage()]);jsonResponse(['success'=>false,'message'=>'Could not create company data export.'],500);}
