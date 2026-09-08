<?php

declare(strict_types=1);

function reportExportTypes(): array
{
    return [
        'sales','purchases','withholding','vat','fodec','stamp-duty','contributions',
        'employer-declaration','fiscal-result','tax-schedules','customer-aging',
        'supplier-aging','expenses','stock','exchange-differences','accountant',
    ];
}

function reportExportSupported(string $report): bool
{
    return in_array(strtolower(trim($report)), reportExportTypes(), true);
}

/**
 * Generate a report CSV from the same definitions used by both the HTTP endpoint
 * and the background worker. The callback receives integer progress values.
 *
 * @return array{row_count:int,row_limit:int,filename:string,size:int,sha256:string}
 */
function generateReportCsv(
    mysqli $conn,
    int $userId,
    string $report,
    string $from,
    string $to,
    string $outputPath,
    ?callable $onProgress = null
): array {
    $report = strtolower(trim($report));
    if(!preg_match('/^\d{4}-\d{2}-\d{2}$/',$from)||!preg_match('/^\d{4}-\d{2}-\d{2}$/',$to)||$to<$from)throw new InvalidArgumentException('Invalid period');
    if(!reportExportSupported($report))throw new InvalidArgumentException('Unsupported export');
    $definitions=[
        'sales'=>["SELECT i.invoice number,i.invoice_date date,i.invoice_type document_type,
            CASE WHEN i.invoice_type='AVOIR' THEN -ABS(i.subtotal) ELSE i.subtotal END subtotal,
            CASE WHEN i.invoice_type='AVOIR' THEN -ABS(i.subtotal_tnd) ELSE i.subtotal_tnd END subtotal_tnd,
            CASE WHEN i.invoice_type='AVOIR' THEN -ABS(i.montant_tva) ELSE i.montant_tva END vat,
            CASE WHEN i.invoice_type='AVOIR' THEN -ABS(i.montant_tva*i.exchange_rate) ELSE i.montant_tva*i.exchange_rate END vat_tnd,
            CASE WHEN i.invoice_type='AVOIR' THEN -ABS(i.total) ELSE i.total END total,
            i.currency,CASE WHEN i.invoice_type='AVOIR' THEN -ABS(i.total_tnd) ELSE i.total_tnd END total_tnd,
            c.name client_name,i.status
            FROM erp_invoices i LEFT JOIN clients c ON c.id=CAST(i.custom_code AS UNSIGNED) AND c.user_id=i.user_id
            WHERE i.user_id=? AND i.invoice_date BETWEEN ? AND ? AND i.invoice_type IN('FACTURE','AVOIR') AND i.is_validated=1
            ORDER BY i.invoice_date,i.id",'iss',[$userId,$from,$to]],
        'purchases'=>["SELECT si.invoice_number number,si.invoice_date date,s.name supplier,si.total_ht_tnd,si.total_tax_tnd,si.stamp_duty_tnd,si.total_ttc,si.currency,si.total_ttc_tnd,si.status FROM erp_supplier_invoices si JOIN suppliers s ON s.id=si.supplier_id AND s.user_id=si.user_id WHERE si.user_id=? AND si.invoice_date BETWEEN ? AND ? AND si.status IN('VALIDATED','PARTIALLY_PAID','PAID') ORDER BY si.invoice_date,si.id",'iss',[$userId,$from,$to]],
        'withholding'=>["SELECT w.id,i.invoice,i.invoice_date,c.name customer,w.withholding_type,w.rate,w.calculation_base,w.withheld_amount,
            w.certificate_number,w.certificate_date,w.expected_certificate_date,w.certificate_status,
            (w.attachment_path IS NOT NULL) has_attachment,w.received_at,w.validated_at,w.cancelled_at,w.validation_notes,w.created_at
            FROM erp_invoice_withholdings w JOIN erp_invoices i ON i.id=w.invoice_id
            LEFT JOIN clients c ON c.id=CAST(i.custom_code AS UNSIGNED) AND c.user_id=i.user_id
            WHERE w.user_id=? AND i.invoice_date BETWEEN ? AND ? AND i.invoice_type='FACTURE' AND i.is_validated=1
            ORDER BY i.invoice_date,i.invoice,w.id",'iss',[$userId,$from,$to]],
        'vat'=>["SELECT CASE ii.tax_regime WHEN 'STANDARD' THEN 'COLLECTED' ELSE ii.tax_regime END classification,ii.tax_regime regime,ii.tva_rate rate,
            ROUND(SUM(CASE WHEN i.invoice_type='AVOIR' THEN -ABS(ii.subtotal_tnd) ELSE ii.subtotal_tnd END),3) taxable_base_tnd,
            ROUND(SUM(CASE WHEN i.invoice_type='AVOIR' THEN -ABS(ii.montant_tva*i.exchange_rate) ELSE ii.montant_tva*i.exchange_rate END),3) vat_tnd
            FROM erp_invoice_items ii JOIN erp_invoices i ON i.id=ii.invoice_id
            WHERE i.user_id=? AND i.invoice_date BETWEEN ? AND ? AND i.invoice_type IN('FACTURE','AVOIR') AND i.is_validated=1
            GROUP BY ii.tax_regime,ii.tva_rate
            UNION ALL
            SELECT 'DEDUCTIBLE' classification,sii.tax_regime regime,sii.vat_rate rate,ROUND(SUM(sii.total_ht_tnd),3) taxable_base_tnd,ROUND(SUM(sii.deductible_vat_tnd),3) vat_tnd
            FROM erp_supplier_invoice_items sii JOIN erp_supplier_invoices si ON si.id=sii.supplier_invoice_id
            WHERE si.user_id=? AND si.invoice_date BETWEEN ? AND ? AND si.status IN('VALIDATED','PARTIALLY_PAID','PAID') GROUP BY sii.tax_regime,sii.vat_rate
            UNION ALL
            SELECT 'NON_DEDUCTIBLE' classification,sii.tax_regime regime,sii.vat_rate rate,ROUND(SUM(sii.total_ht_tnd),3) taxable_base_tnd,ROUND(SUM(sii.non_deductible_vat_tnd),3) vat_tnd
            FROM erp_supplier_invoice_items sii JOIN erp_supplier_invoices si ON si.id=sii.supplier_invoice_id
            WHERE si.user_id=? AND si.invoice_date BETWEEN ? AND ? AND si.status IN('VALIDATED','PARTIALLY_PAID','PAID') GROUP BY sii.tax_regime,sii.vat_rate ORDER BY classification,regime,rate",'issississ',[$userId,$from,$to,$userId,$from,$to,$userId,$from,$to]],
        'fodec'=>["SELECT 'SALES' direction,ii.fodec_rate rate,
            ROUND(SUM(CASE WHEN i.invoice_type='AVOIR' THEN -ABS(ii.subtotal_tnd) ELSE ii.subtotal_tnd END),3) taxable_base_tnd,
            ROUND(SUM(CASE WHEN i.invoice_type='AVOIR' THEN -ABS(ii.fodec_amount*i.exchange_rate) ELSE ii.fodec_amount*i.exchange_rate END),3) fodec_tnd
            FROM erp_invoice_items ii JOIN erp_invoices i ON i.id=ii.invoice_id
            WHERE i.user_id=? AND i.invoice_date BETWEEN ? AND ? AND i.invoice_type IN('FACTURE','AVOIR') AND i.is_validated=1 AND ii.fodec_rate>0
            GROUP BY ii.fodec_rate
            UNION ALL
            SELECT 'PURCHASES' direction,sii.fodec_rate rate,ROUND(SUM(sii.total_ht_tnd),3) taxable_base_tnd,
            ROUND(SUM(sii.fodec_amount*si.exchange_rate),3) fodec_tnd
            FROM erp_supplier_invoice_items sii JOIN erp_supplier_invoices si ON si.id=sii.supplier_invoice_id
            WHERE si.user_id=? AND si.invoice_date BETWEEN ? AND ? AND si.status IN('VALIDATED','PARTIALLY_PAID','PAID') AND sii.fodec_rate>0
            GROUP BY sii.fodec_rate ORDER BY direction,rate",'ississ',[$userId,$from,$to,$userId,$from,$to]],
        'stamp-duty'=>["SELECT 'SALES' direction,i.invoice document_number,i.invoice_date document_date,i.invoice_type document_type,
            i.currency,i.exchange_rate,i.timbre stamp_source,
            ROUND(CASE WHEN i.invoice_type='AVOIR' THEN -ABS(i.timbre*i.exchange_rate) ELSE i.timbre*i.exchange_rate END,3) stamp_tnd
            FROM erp_invoices i WHERE i.user_id=? AND i.invoice_date BETWEEN ? AND ? AND i.invoice_type IN('FACTURE','AVOIR') AND i.is_validated=1 AND i.timbre>0
            UNION ALL
            SELECT 'PURCHASES' direction,si.invoice_number document_number,si.invoice_date document_date,'SUPPLIER_INVOICE' document_type,
            si.currency,si.exchange_rate,si.stamp_duty stamp_source,si.stamp_duty_tnd stamp_tnd
            FROM erp_supplier_invoices si WHERE si.user_id=? AND si.invoice_date BETWEEN ? AND ? AND si.status IN('VALIDATED','PARTIALLY_PAID','PAID') AND si.stamp_duty>0
            ORDER BY document_date,document_number",'ississ',[$userId,$from,$to,$userId,$from,$to]],
        'exchange-differences'=>["SELECT 'CUSTOMER' direction,p.id payment_id,i.invoice document_number,p.payment_date,
            COALESCE(NULLIF(c.name,''),'Client non lié') party,i.currency,p.amount amount_foreign,i.exchange_rate invoice_rate,
            p.exchange_rate settlement_rate,p.exchange_rate_date,ROUND(p.amount*i.exchange_rate,3) carrying_tnd,p.amount_tnd settlement_tnd,
            CASE WHEN p.exchange_rate IS NULL OR p.amount_tnd IS NULL THEN NULL ELSE ROUND(p.amount_tnd-p.amount*i.exchange_rate,3) END exchange_difference_tnd,
            CASE WHEN p.exchange_rate IS NULL OR p.amount_tnd IS NULL THEN 'MISSING_RATE' ELSE 'COMPLETE' END data_status
            FROM erp_invoice_payments p JOIN erp_invoices i ON i.id=p.invoice_id AND i.user_id=p.user_id
            LEFT JOIN clients c ON c.id=CAST(i.custom_code AS UNSIGNED) AND c.user_id=i.user_id
            WHERE p.user_id=? AND p.payment_date BETWEEN ? AND ? AND p.status='POSTED' AND i.currency<>'TND'
            UNION ALL
            SELECT 'SUPPLIER',p.id,si.invoice_number,p.payment_date,COALESCE(NULLIF(s.name,''),'Fournisseur non lié'),si.currency,p.amount,
            si.exchange_rate,p.exchange_rate,p.exchange_rate_date,ROUND(p.amount*si.exchange_rate,3),p.amount_tnd,
            CASE WHEN p.exchange_rate IS NULL OR p.amount_tnd IS NULL THEN NULL ELSE ROUND(p.amount*si.exchange_rate-p.amount_tnd,3) END,
            CASE WHEN p.exchange_rate IS NULL OR p.amount_tnd IS NULL THEN 'MISSING_RATE' ELSE 'COMPLETE' END
            FROM erp_supplier_payments p JOIN erp_supplier_invoices si ON si.id=p.supplier_invoice_id AND si.user_id=p.user_id
            LEFT JOIN suppliers s ON s.id=si.supplier_id AND s.user_id=si.user_id
            WHERE p.user_id=? AND p.payment_date BETWEEN ? AND ? AND p.voided_at IS NULL AND si.currency<>'TND'
            ORDER BY payment_date,payment_id",'ississ',[$userId,$from,$to,$userId,$from,$to]],
        'contributions'=>["SELECT p.contribution,p.period_start,p.period_end,p.basis_kind,p.basis_amount,p.rate,p.calculated_amount,p.status,c.legal_basis,p.notes
            FROM erp_contribution_periods p JOIN erp_contribution_configs c ON c.id=p.config_id
            WHERE p.user_id=? AND p.period_start>=? AND p.period_end<=? ORDER BY p.period_start,p.contribution",'iss',[$userId,$from,$to]],
        'employer-declaration'=>["SELECT d.declaration_year,d.status,l.category,l.beneficiary_name,l.beneficiary_fiscal_id,l.gross_amount,l.withheld_amount,
            l.source_supplier_payment_id,l.notes,l.created_at
            FROM erp_employer_declarations d JOIN erp_employer_declaration_lines l ON l.declaration_id=d.id
            WHERE d.user_id=? AND d.declaration_year=YEAR(?) ORDER BY l.category,l.beneficiary_name,l.id",'is',[$userId,$to]],
        'fiscal-result'=>["SELECT r.fiscal_year,r.status,r.accounting_source,r.accounting_result,a.adjustment_type,a.timing,a.category,a.description,a.amount,a.legal_basis,a.notes,a.created_at
            FROM erp_fiscal_reconciliations r LEFT JOIN erp_fiscal_adjustments a ON a.reconciliation_id=r.id
            WHERE r.user_id=? AND r.fiscal_year=YEAR(?) ORDER BY a.adjustment_type,a.category,a.id",'is',[$userId,$to]],
        'tax-schedules'=>["SELECT fiscal_year,schedule_type,reference,description,event_date,beneficiary,gross_amount,opening_book_value,annual_rate,
            accounting_amount,fiscal_amount,fiscal_addition,fiscal_deduction,closing_book_value,timing,legal_basis,evidence_reference,notes,status
            FROM erp_tax_schedule_entries WHERE user_id=? AND fiscal_year=YEAR(?) AND status<>'CANCELLED'
            ORDER BY schedule_type,event_date,reference",'is',[$userId,$to]],
        'customer-aging'=>["SELECT i.invoice number,i.invoice_date date,i.invoice_due_date due_date,c.name customer,
            i.total_tnd total_tnd,ROUND(COALESCE(p.paid,0)*i.exchange_rate,3) paid_tnd,ROUND(COALESCE(w.withheld,0)*i.exchange_rate,3) withheld_tnd,
            ROUND(COALESCE(cr.credited,0),3) credited_tnd,
            ROUND(i.total_tnd-(COALESCE(p.paid,0)+COALESCE(w.withheld,0))*i.exchange_rate-COALESCE(cr.credited,0),3) balance_tnd,
            GREATEST(DATEDIFF(?,i.invoice_due_date),0) days_overdue,CASE WHEN DATEDIFF(?,i.invoice_due_date)<=0 THEN 'CURRENT' WHEN DATEDIFF(?,i.invoice_due_date)<=30 THEN '1-30' WHEN DATEDIFF(?,i.invoice_due_date)<=60 THEN '31-60' WHEN DATEDIFF(?,i.invoice_due_date)<=90 THEN '61-90' ELSE '90+' END aging_bucket
            FROM erp_invoices i LEFT JOIN clients c ON c.id=CAST(i.custom_code AS UNSIGNED) AND c.user_id=i.user_id
            LEFT JOIN(SELECT invoice_id,SUM(amount) paid FROM erp_invoice_payments WHERE status='POSTED' AND payment_date<=? GROUP BY invoice_id)p ON p.invoice_id=i.id
            LEFT JOIN(SELECT invoice_id,SUM(withheld_amount) withheld FROM erp_invoice_withholdings WHERE certificate_status IN('RECEIVED','VALIDATED') AND certificate_date<=? GROUP BY invoice_id)w ON w.invoice_id=i.id
            LEFT JOIN(SELECT source_invoice_id,SUM(ABS(total_tnd)) credited FROM erp_invoices WHERE invoice_type='AVOIR' AND is_validated=1 AND invoice_date<=? GROUP BY source_invoice_id)cr ON cr.source_invoice_id=i.id
            WHERE i.user_id=? AND i.invoice_type='FACTURE' AND i.is_validated=1 AND i.invoice_date<=?
              AND i.total_tnd-(COALESCE(p.paid,0)+COALESCE(w.withheld,0))*i.exchange_rate-COALESCE(cr.credited,0)>0
            ORDER BY days_overdue DESC,i.invoice_due_date",'ssssssssis',[$to,$to,$to,$to,$to,$to,$to,$to,$userId,$to]],
        'supplier-aging'=>["SELECT si.invoice_number number,si.invoice_date date,si.due_date,s.name supplier,si.total_ttc_tnd total_tnd,ROUND(COALESCE(p.paid,0)*si.exchange_rate,3) paid_tnd,ROUND(si.total_ttc_tnd-(si.credited_amount+COALESCE(p.paid,0))*si.exchange_rate,3) balance_tnd,GREATEST(DATEDIFF(?,si.due_date),0) days_overdue,CASE WHEN DATEDIFF(?,si.due_date)<=0 THEN 'CURRENT' WHEN DATEDIFF(?,si.due_date)<=30 THEN '1-30' WHEN DATEDIFF(?,si.due_date)<=60 THEN '31-60' WHEN DATEDIFF(?,si.due_date)<=90 THEN '61-90' ELSE '90+' END aging_bucket FROM erp_supplier_invoices si JOIN suppliers s ON s.id=si.supplier_id AND s.user_id=si.user_id LEFT JOIN(SELECT supplier_invoice_id,SUM(amount) paid FROM erp_supplier_payments WHERE voided_at IS NULL AND payment_date<=? GROUP BY supplier_invoice_id)p ON p.supplier_invoice_id=si.id WHERE si.user_id=? AND si.invoice_date<=? AND si.status IN('VALIDATED','PARTIALLY_PAID','PAID') AND si.total_ttc_tnd-(si.credited_amount+COALESCE(p.paid,0))*si.exchange_rate>0 ORDER BY days_overdue DESC,si.due_date",'ssssssis',[$to,$to,$to,$to,$to,$to,$userId,$to]],
        'expenses'=>["SELECT expense_date date,title,category,amount,source_document_type,source_document_number,status FROM expense_notes WHERE user_id=? AND expense_date BETWEEN ? AND ? AND status IN('APPROVED','REIMBURSED') ORDER BY expense_date,id",'iss',[$userId,$from,$to]],
        'stock'=>["SELECT 'INVENTORY' source_type,p.code reference,p.name,NULL event_date,p.stock_quantity quantity,p.average_cost unit_cost,ROUND(p.stock_quantity*p.average_cost,3) amount_tnd FROM products p WHERE p.user_id=? AND p.item_type='PRODUCT' UNION ALL SELECT 'COGS',CONCAT(COALESCE(m.reference_type,'STOCK'),' #',COALESCE(m.reference_id,m.id)),p.name,DATE(m.created_at),m.quantity,m.unit_cost,m.cogs_value FROM product_stock_movements m JOIN products p ON p.id=m.product_id AND p.user_id=m.user_id WHERE m.user_id=? AND m.created_at>=? AND m.created_at<DATE_ADD(?,INTERVAL 1 DAY) AND m.cogs_value<>0 ORDER BY source_type,event_date,reference",'iiss',[$userId,$userId,$from,$to]],
        'accountant'=>["SELECT i.invoice journal_number,i.invoice_date journal_date,
            CASE WHEN i.invoice_type='AVOIR' THEN 'AVOIR_VENTE' ELSE 'VENTE' END journal_code,
            CASE WHEN i.invoice_type='AVOIR' THEN -ABS(i.subtotal) ELSE i.subtotal END debit_ht,
            CASE WHEN i.invoice_type='AVOIR' THEN -ABS(i.montant_tva) ELSE i.montant_tva END debit_vat,
            CASE WHEN i.invoice_type='AVOIR' THEN -ABS(i.total) ELSE i.total END credit_customer,
            i.currency,i.exchange_rate,CASE WHEN i.invoice_type='AVOIR' THEN -ABS(i.total_tnd) ELSE i.total_tnd END total_tnd
            FROM erp_invoices i WHERE i.user_id=? AND i.invoice_date BETWEEN ? AND ?
              AND i.invoice_type IN('FACTURE','AVOIR') AND i.is_validated=1 ORDER BY i.invoice_date,i.id",'iss',[$userId,$from,$to]],
    ];
    if(!isset($definitions[$report]))throw new LogicException('Missing report export definition');
    if($onProgress)$onProgress(10);
    [$sql,$types,$args]=$definitions[$report];$exportLimit=10000;$sql="SELECT * FROM ($sql) export_rows LIMIT ?";$types.='i';$args[]=$exportLimit+1;$stmt=$conn->prepare($sql);$stmt->bind_param($types,...$args);$stmt->execute();$result=$stmt->get_result();
    if($result->num_rows>$exportLimit){$stmt->close();throw new LengthException('Export exceeds 10,000 rows. Narrow the date range or filters.');}
    $rowCount=(int)$result->num_rows;if($onProgress)$onProgress(25);
    $out=fopen($outputPath,'wb');if($out===false){$stmt->close();throw new RuntimeException('Could not create the report export file.');}
    try{
        fwrite($out,"\xEF\xBB\xBF");$first=true;$written=0;
        while($row=$result->fetch_assoc()){
            if($first){fputcsv($out,array_keys($row),';');$first=false;}
            fputcsv($out,array_values($row),';');$written++;
            if($onProgress&&$rowCount>0&&($written%250===0||$written===$rowCount))$onProgress(25+(int)floor(($written/$rowCount)*70));
        }
        if($first)fputcsv($out,['no_records'],';');
    }finally{fclose($out);$stmt->close();}
    $size=filesize($outputPath);if($size===false)throw new RuntimeException('Could not inspect the report export file.');
    if($onProgress)$onProgress(95);
    return['row_count'=>$rowCount,'row_limit'=>$exportLimit,'filename'=>$report.'-'.$from.'-'.$to.'.csv','size'=>(int)$size,'sha256'=>hash_file('sha256',$outputPath)];
}

if(realpath((string)($_SERVER['SCRIPT_FILENAME']??''))===realpath(__FILE__)){
    require_once __DIR__.'/../config/db.php';
    require_once __DIR__.'/../config/audit.php';
    require_once __DIR__.'/../auth/auth_required.php';
    require_once __DIR__.'/../auth/role_helper.php';
    $temporaryPath=null;
    try{
        $auth=requireAuth();$userId=authTenantId($auth);$actorId=authActorId($auth);$conn=db();requirePermission($conn,$userId,'reports.view');
        $from=(string)($_GET['from']??date('Y-m-01'));$to=(string)($_GET['to']??date('Y-m-d'));$report=(string)($_GET['report']??'sales');
        $temporaryPath=tempnam(sys_get_temp_dir(),'report-export-');if($temporaryPath===false)throw new RuntimeException('Could not prepare the report export.');
        $metadata=generateReportCsv($conn,$userId,$report,$from,$to,$temporaryPath);
        auditLog($conn,$userId,$actorId,'REPORT.EXPORTED','REPORT',strtolower($report),null,['report'=>strtolower($report),'date_from'=>$from,'date_to'=>$to,'format'=>'CSV','row_count'=>$metadata['row_count']]);
        header('Content-Type: text/csv; charset=utf-8');header('Content-Disposition: attachment; filename="'.$metadata['filename'].'"');header('Content-Length: '.$metadata['size']);header('X-Export-Row-Count: '.$metadata['row_count']);header('X-Export-Row-Limit: '.$metadata['row_limit']);readfile($temporaryPath);
    }catch(LengthException $e){if(!headers_sent()){http_response_code(413);header('Content-Type: application/json');}echo json_encode(['success'=>false,'message'=>'Export exceeds 10,000 rows. Narrow the date range or filters.','error_code'=>'EXPORT_TOO_LARGE']);
    }catch(InvalidArgumentException $e){if(!headers_sent()){http_response_code(422);header('Content-Type: application/json');}echo json_encode(['success'=>false,'message'=>$e->getMessage(),'error_code'=>'REPORT_VALIDATION_FAILED']);
    }catch(Throwable $e){structuredLog('ERROR','REPORT.EXPORT_FAILED',['exception'=>get_class($e),'message'=>$e->getMessage(),'file'=>basename($e->getFile()),'line'=>$e->getLine()]);if(!headers_sent()){http_response_code(500);header('Content-Type: application/json');}echo json_encode(['success'=>false,'message'=>'Could not generate the report export.','error_code'=>'EXPORT_FAILED']);
    }finally{if(is_string($temporaryPath)&&is_file($temporaryPath))@unlink($temporaryPath);}
}
