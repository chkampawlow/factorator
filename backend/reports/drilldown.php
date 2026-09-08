<?php

require_once __DIR__.'/../config/response.php';
require_once __DIR__.'/../config/db.php';
require_once __DIR__.'/../auth/auth_required.php';
require_once __DIR__.'/../auth/role_helper.php';
require_once __DIR__.'/report_error.php';

try {
    $userId=(int)requireAuth()->id;
    $conn=db();
    requirePermission($conn,$userId,'reports.view');
    $metric=strtolower(trim((string)($_GET['metric']??'')));
    $from=(string)($_GET['from']??date('Y-m-01'));
    $to=(string)($_GET['to']??date('Y-m-d'));
    if(!preg_match('/^\d{4}-\d{2}-\d{2}$/',$from)||!preg_match('/^\d{4}-\d{2}-\d{2}$/',$to)||$to<$from)throw new InvalidArgumentException('Invalid period');

    $definitions=[
        'sales'=>["SELECT i.id,i.invoice document_number,i.invoice_date document_date,i.invoice_type,c.name party,
            ROUND(CASE WHEN i.invoice_type='AVOIR' THEN -ABS(i.subtotal) ELSE i.subtotal END,3) amount_ht,
            ROUND(CASE WHEN i.invoice_type='AVOIR' THEN -ABS(i.montant_tva) ELSE i.montant_tva END,3) vat,
            ROUND(CASE WHEN i.invoice_type='AVOIR' THEN -ABS(i.total_tnd) ELSE i.total_tnd END,3) total_tnd,i.status
            FROM erp_invoices i LEFT JOIN clients c ON c.id=CAST(i.custom_code AS UNSIGNED) AND c.user_id=i.user_id
            WHERE i.user_id=? AND i.invoice_date BETWEEN ? AND ? AND i.invoice_type IN('FACTURE','AVOIR') AND i.is_validated=1
            ORDER BY i.invoice_date DESC,i.id DESC LIMIT 500",'iss',[$userId,$from,$to]],
        'purchases'=>["SELECT si.id,si.invoice_number document_number,si.invoice_date document_date,s.name party,
            si.total_ht_tnd amount_ht,si.total_tax_tnd vat,si.total_ttc_tnd,si.status
            FROM erp_supplier_invoices si JOIN suppliers s ON s.id=si.supplier_id AND s.user_id=si.user_id
            WHERE si.user_id=? AND si.invoice_date BETWEEN ? AND ? AND si.status IN('VALIDATED','PARTIALLY_PAID','PAID')
            ORDER BY si.invoice_date DESC,si.id DESC LIMIT 500",'iss',[$userId,$from,$to]],
        'vat'=>["SELECT 'SALE' direction,i.id document_id,i.invoice document_number,i.invoice_date document_date,
            ii.tax_regime,ii.tva_rate rate,
            ROUND(CASE WHEN i.invoice_type='AVOIR' THEN -ABS(ii.subtotal_tnd) ELSE ii.subtotal_tnd END,3) taxable_base_tnd,
            ROUND(CASE WHEN i.invoice_type='AVOIR' THEN -ABS(ii.montant_tva*i.exchange_rate) ELSE ii.montant_tva*i.exchange_rate END,3) vat_tnd
            FROM erp_invoice_items ii JOIN erp_invoices i ON i.id=ii.invoice_id
            WHERE i.user_id=? AND i.invoice_date BETWEEN ? AND ? AND i.invoice_type IN('FACTURE','AVOIR') AND i.is_validated=1
            UNION ALL
            SELECT 'PURCHASE',si.id,si.invoice_number,si.invoice_date,sii.tax_regime,sii.vat_rate,sii.total_ht_tnd,sii.deductible_vat_tnd
            FROM erp_supplier_invoice_items sii JOIN erp_supplier_invoices si ON si.id=sii.supplier_invoice_id
            WHERE si.user_id=? AND si.invoice_date BETWEEN ? AND ? AND si.status IN('VALIDATED','PARTIALLY_PAID','PAID')
            ORDER BY document_date DESC,document_id DESC LIMIT 500",'ississ',[$userId,$from,$to,$userId,$from,$to]],
        'monthly-tax'=>["SELECT * FROM(
            SELECT 'OPENING_VAT_CREDIT' source_type,p.id source_id,CONCAT(p.period_start,' → ',p.period_end) reference,p.period_end event_date,0 taxable_base_tnd,p.closing_credit amount_tnd,p.status
            FROM erp_vat_periods p WHERE p.user_id=? AND p.period_end<? AND p.status IN('REVIEWED','LOCKED','FILED') ORDER BY p.period_end DESC,p.id DESC LIMIT 1
        ) opening UNION ALL
            SELECT 'VAT_COLLECTED',i.id,i.invoice,i.invoice_date,CASE WHEN i.invoice_type='AVOIR' THEN -ABS(ii.subtotal_tnd) ELSE ii.subtotal_tnd END,CASE WHEN i.invoice_type='AVOIR' THEN -ABS(ii.montant_tva*i.exchange_rate) ELSE ii.montant_tva*i.exchange_rate END,i.status
            FROM erp_invoice_items ii JOIN erp_invoices i ON i.id=ii.invoice_id WHERE i.user_id=? AND i.invoice_date BETWEEN ? AND ? AND i.invoice_type IN('FACTURE','AVOIR') AND i.is_validated=1
        UNION ALL SELECT 'VAT_DEDUCTIBLE',si.id,si.invoice_number,si.invoice_date,sii.total_ht_tnd,sii.deductible_vat_tnd,si.status
            FROM erp_supplier_invoice_items sii JOIN erp_supplier_invoices si ON si.id=sii.supplier_invoice_id WHERE si.user_id=? AND si.invoice_date BETWEEN ? AND ? AND si.status IN('VALIDATED','PARTIALLY_PAID','PAID')
        UNION ALL SELECT 'WITHHOLDING',w.id,i.invoice,COALESCE(w.certificate_date,i.invoice_date),w.calculation_base,w.withheld_amount,w.certificate_status
            FROM erp_invoice_withholdings w JOIN erp_invoices i ON i.id=w.invoice_id WHERE w.user_id=? AND i.invoice_date BETWEEN ? AND ? AND w.certificate_status IN('RECEIVED','VALIDATED')
        ORDER BY event_date DESC,source_id DESC LIMIT 500",'isissississ',[$userId,$from,$userId,$from,$to,$userId,$from,$to,$userId,$from,$to]],
        'expenses'=>["SELECT id,expense_date document_date,title,category,amount,source_document_type,source_document_number,status
            FROM expense_notes WHERE user_id=? AND expense_date BETWEEN ? AND ? AND status IN('APPROVED','REIMBURSED')
            ORDER BY expense_date DESC,id DESC LIMIT 500",'iss',[$userId,$from,$to]],
        'customer-aging'=>["SELECT i.id,i.invoice document_number,i.invoice_date document_date,i.invoice_due_date due_date,c.name party,
            i.total_tnd,ROUND(COALESCE(p.paid,0)*i.exchange_rate,3) paid_tnd,ROUND(COALESCE(w.withheld,0)*i.exchange_rate,3) withheld_tnd,
            ROUND(i.total_tnd-(COALESCE(p.paid,0)+COALESCE(w.withheld,0))*i.exchange_rate-COALESCE(cr.credited,0),3) balance_tnd,
            GREATEST(DATEDIFF(?,i.invoice_due_date),0) days_overdue
            FROM erp_invoices i LEFT JOIN clients c ON c.id=CAST(i.custom_code AS UNSIGNED) AND c.user_id=i.user_id
            LEFT JOIN(SELECT invoice_id,SUM(amount) paid FROM erp_invoice_payments WHERE status='POSTED' AND payment_date<=? GROUP BY invoice_id)p ON p.invoice_id=i.id
            LEFT JOIN(SELECT invoice_id,SUM(withheld_amount) withheld FROM erp_invoice_withholdings WHERE certificate_status IN('RECEIVED','VALIDATED') AND certificate_date<=? GROUP BY invoice_id)w ON w.invoice_id=i.id
            LEFT JOIN(SELECT source_invoice_id,SUM(ABS(total_tnd)) credited FROM erp_invoices WHERE invoice_type='AVOIR' AND is_validated=1 AND invoice_date<=? GROUP BY source_invoice_id)cr ON cr.source_invoice_id=i.id
            WHERE i.user_id=? AND i.invoice_type='FACTURE' AND i.is_validated=1 AND i.invoice_date<=?
            AND i.total_tnd-(COALESCE(p.paid,0)+COALESCE(w.withheld,0))*i.exchange_rate-COALESCE(cr.credited,0)>0
            ORDER BY days_overdue DESC,i.invoice_due_date LIMIT 500",'ssssis',[$to,$to,$to,$to,$userId,$to]],
        'supplier-aging'=>["SELECT si.id,si.invoice_number document_number,si.invoice_date document_date,si.due_date,s.name party,
            si.total_ttc_tnd,ROUND(COALESCE(p.paid,0)*si.exchange_rate,3) paid_tnd,
            ROUND(si.total_ttc_tnd-(si.credited_amount+COALESCE(p.paid,0))*si.exchange_rate,3) balance_tnd,GREATEST(DATEDIFF(?,si.due_date),0) days_overdue
            FROM erp_supplier_invoices si JOIN suppliers s ON s.id=si.supplier_id AND s.user_id=si.user_id
            LEFT JOIN(SELECT supplier_invoice_id,SUM(amount) paid FROM erp_supplier_payments WHERE voided_at IS NULL AND payment_date<=? GROUP BY supplier_invoice_id)p ON p.supplier_invoice_id=si.id
            WHERE si.user_id=? AND si.invoice_date<=? AND si.status IN('VALIDATED','PARTIALLY_PAID','PAID')
            AND si.total_ttc_tnd-(si.credited_amount+COALESCE(p.paid,0))*si.exchange_rate>0
            ORDER BY days_overdue DESC,si.due_date LIMIT 500",'ssis',[$to,$to,$userId,$to]],
        'cash-bank'=>["SELECT p.id,p.payment_date document_date,i.invoice document_number,c.name party,p.method,p.account_name account,
            p.reference_number,ROUND(COALESCE(p.amount_tnd,p.amount*i.exchange_rate),3) amount_tnd
            FROM erp_invoice_payments p JOIN erp_invoices i ON i.id=p.invoice_id
            LEFT JOIN clients c ON c.id=CAST(i.custom_code AS UNSIGNED) AND c.user_id=i.user_id
            WHERE p.user_id=? AND p.payment_date BETWEEN ? AND ? AND p.status='POSTED'
            ORDER BY p.payment_date DESC,p.id DESC LIMIT 500",'iss',[$userId,$from,$to]],
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
            ORDER BY payment_date DESC,payment_id DESC LIMIT 500",'ississ',[$userId,$from,$to,$userId,$from,$to]],
        'withholding'=>["SELECT w.id,i.invoice document_number,i.invoice_date document_date,c.name party,w.withholding_type,w.rate,
            w.calculation_base,w.withheld_amount,w.certificate_number,w.certificate_status,w.expected_certificate_date
            FROM erp_invoice_withholdings w JOIN erp_invoices i ON i.id=w.invoice_id
            LEFT JOIN clients c ON c.id=CAST(i.custom_code AS UNSIGNED) AND c.user_id=i.user_id
            WHERE w.user_id=? AND i.invoice_date BETWEEN ? AND ? AND i.invoice_type='FACTURE' AND i.is_validated=1
            ORDER BY i.invoice_date DESC,w.id DESC LIMIT 500",'iss',[$userId,$from,$to]],
        'fodec'=>["SELECT 'SALE' direction,i.id document_id,i.invoice document_number,i.invoice_date document_date,ii.fodec_rate rate,
            ii.subtotal_tnd taxable_base_tnd,ROUND(ii.fodec_amount*i.exchange_rate,3) amount_tnd
            FROM erp_invoice_items ii JOIN erp_invoices i ON i.id=ii.invoice_id
            WHERE i.user_id=? AND i.invoice_date BETWEEN ? AND ? AND i.is_validated=1 AND ii.fodec_rate>0
            UNION ALL SELECT 'PURCHASE',si.id,si.invoice_number,si.invoice_date,sii.fodec_rate,sii.total_ht_tnd,ROUND(sii.fodec_amount*si.exchange_rate,3)
            FROM erp_supplier_invoice_items sii JOIN erp_supplier_invoices si ON si.id=sii.supplier_invoice_id
            WHERE si.user_id=? AND si.invoice_date BETWEEN ? AND ? AND si.status IN('VALIDATED','PARTIALLY_PAID','PAID') AND sii.fodec_rate>0
            ORDER BY document_date DESC LIMIT 500",'ississ',[$userId,$from,$to,$userId,$from,$to]],
        'stamp-duty'=>["SELECT 'SALE' direction,i.id document_id,i.invoice document_number,i.invoice_date document_date,i.invoice_type,
            ROUND(CASE WHEN i.invoice_type='AVOIR' THEN -ABS(i.timbre*i.exchange_rate) ELSE i.timbre*i.exchange_rate END,3) amount_tnd
            FROM erp_invoices i WHERE i.user_id=? AND i.invoice_date BETWEEN ? AND ? AND i.is_validated=1 AND i.timbre>0
            UNION ALL SELECT 'PURCHASE',si.id,si.invoice_number,si.invoice_date,'SUPPLIER_INVOICE',si.stamp_duty_tnd
            FROM erp_supplier_invoices si WHERE si.user_id=? AND si.invoice_date BETWEEN ? AND ? AND si.status IN('VALIDATED','PARTIALLY_PAID','PAID') AND si.stamp_duty>0
            ORDER BY document_date DESC LIMIT 500",'ississ',[$userId,$from,$to,$userId,$from,$to]],
        'contributions'=>["SELECT p.id,p.contribution,p.period_start,p.period_end,p.basis_kind,p.basis_amount,p.rate,p.calculated_amount,p.status,c.legal_basis
            FROM erp_contribution_periods p JOIN erp_contribution_configs c ON c.id=p.config_id
            WHERE p.user_id=? AND p.period_start>=? AND p.period_end<=? ORDER BY p.period_start DESC,p.contribution LIMIT 500",'iss',[$userId,$from,$to]],
        'employer-declaration'=>["SELECT l.id,d.declaration_year,d.status,l.category,l.beneficiary_name,l.beneficiary_fiscal_id,l.gross_amount,l.withheld_amount,l.source_supplier_payment_id
            FROM erp_employer_declarations d JOIN erp_employer_declaration_lines l ON l.declaration_id=d.id
            WHERE d.user_id=? AND d.declaration_year=YEAR(?) ORDER BY l.category,l.beneficiary_name LIMIT 500",'is',[$userId,$to]],
        'fiscal-result'=>["SELECT a.id,r.fiscal_year,r.status,r.accounting_source,r.accounting_result,a.adjustment_type,a.timing,a.category,a.description,a.amount,a.legal_basis
            FROM erp_fiscal_reconciliations r LEFT JOIN erp_fiscal_adjustments a ON a.reconciliation_id=r.id
            WHERE r.user_id=? AND r.fiscal_year=YEAR(?) ORDER BY a.adjustment_type,a.category LIMIT 500",'is',[$userId,$to]],
        'tax-schedules'=>["SELECT id,fiscal_year,schedule_type,reference,description,event_date,beneficiary,gross_amount,accounting_amount,fiscal_amount,
            fiscal_addition,fiscal_deduction,timing,legal_basis,evidence_reference,status
            FROM erp_tax_schedule_entries WHERE user_id=? AND fiscal_year=YEAR(?) AND status<>'CANCELLED'
            ORDER BY schedule_type,event_date DESC,reference LIMIT 500",'is',[$userId,$to]],
        'filing-archives'=>["SELECT id,declaration_type,source_entity_id,filing_sequence,period_start,period_end,report_version,source_row_count,archive_sha256,captured_at
            FROM erp_filing_archives WHERE user_id=? ORDER BY captured_at DESC,id DESC LIMIT 500",'i',[$userId]],
        'accountant-reviews'=>["SELECT id,entity_type,entity_id,action,note,actor_id,actor_role,event_hash,created_at
            FROM erp_accountant_review_events WHERE user_id=? ORDER BY created_at DESC,id DESC LIMIT 500",'i',[$userId]],
        'period-reopenings'=>["SELECT id,period_type,period_id,previous_status,reopened_status,reason,prior_snapshot_sha256,prior_filing_archive_id,reopened_by,reopened_by_role,reopened_at
            FROM erp_period_reopenings WHERE user_id=? ORDER BY reopened_at DESC,id DESC LIMIT 500",'i',[$userId]],
        'profitability'=>["SELECT 'REVENUE' source_type,i.id source_id,i.invoice reference,i.invoice_date event_date,
            CASE WHEN i.invoice_type='AVOIR' THEN -ABS(i.subtotal*i.exchange_rate) ELSE i.subtotal*i.exchange_rate END amount_tnd
            FROM erp_invoices i WHERE i.user_id=? AND i.invoice_date BETWEEN ? AND ? AND i.is_validated=1 AND i.invoice_type IN('FACTURE','AVOIR')
            UNION ALL SELECT 'COGS',m.id,COALESCE(m.reference_type,'STOCK'),DATE(m.created_at),-ABS(m.cogs_value)
            FROM product_stock_movements m WHERE m.user_id=? AND m.created_at>=? AND m.created_at<DATE_ADD(?,INTERVAL 1 DAY) AND m.cogs_value<>0
            UNION ALL SELECT 'EXPENSE',e.id,e.title,e.expense_date,-ABS(e.amount)
            FROM expense_notes e WHERE e.user_id=? AND e.expense_date BETWEEN ? AND ? AND e.status IN('APPROVED','REIMBURSED')
            ORDER BY event_date DESC LIMIT 500",'issississ',[$userId,$from,$to,$userId,$from,$to,$userId,$from,$to]],
        'numbering-gaps'=>["SELECT prefix,yr year,previous_n+1 missing_from,n-1 missing_to,n-previous_n-1 missing_count
            FROM(SELECT prefix,yr,n,LAG(n) OVER(PARTITION BY prefix,yr ORDER BY n) previous_n FROM(
            SELECT SUBSTRING_INDEX(invoice,'-',1) prefix,SUBSTRING_INDEX(SUBSTRING_INDEX(invoice,'-',2),'-',-1) yr,
            CAST(SUBSTRING_INDEX(invoice,'-',-1) AS UNSIGNED)n FROM erp_invoices
            WHERE user_id=? AND invoice REGEXP '^[A-Z]+-[0-9]{4}-[0-9]+$' AND is_validated=1)x)y
            WHERE previous_n IS NOT NULL AND n>previous_n+1 ORDER BY yr DESC,prefix,missing_from LIMIT 500",'i',[$userId]],
        'accounting-periods'=>["SELECT id,period_start,period_end,status,reviewed_at,locked_at,filed_at,created_at,updated_at
            FROM erp_accounting_periods WHERE user_id=? ORDER BY period_end DESC,id DESC LIMIT 500",'i',[$userId]],
        'stock'=>["SELECT 'INVENTORY' source_type,p.id source_id,p.code reference,p.name,NULL event_date,p.stock_quantity quantity,p.average_cost unit_cost,ROUND(p.stock_quantity*p.average_cost,3) amount_tnd
            FROM products p WHERE p.user_id=? AND p.item_type='PRODUCT'
            UNION ALL SELECT 'COGS',m.id,CONCAT(COALESCE(m.reference_type,'STOCK'),' #',COALESCE(m.reference_id,m.id)),p.name,DATE(m.created_at),m.quantity,m.unit_cost,m.cogs_value
            FROM product_stock_movements m JOIN products p ON p.id=m.product_id AND p.user_id=m.user_id WHERE m.user_id=? AND m.created_at>=? AND m.created_at<DATE_ADD(?,INTERVAL 1 DAY) AND m.cogs_value<>0
            ORDER BY source_type,event_date DESC,source_id DESC LIMIT 500",'iiss',[$userId,$userId,$from,$to]],
    ];
    if(!isset($definitions[$metric]))throw new InvalidArgumentException('Unsupported drill-down metric');
    [$sql,$types,$values]=$definitions[$metric];
    $stmt=$conn->prepare($sql);
    $stmt->bind_param($types,...$values);
    $stmt->execute();
    $rows=$stmt->get_result()->fetch_all(MYSQLI_ASSOC);
    $stmt->close();
    jsonResponse(['success'=>true,'metric'=>$metric,'period'=>['from'=>$from,'to'=>$to],'rows'=>$rows,'columns'=>$rows?array_keys($rows[0]):[],'limit'=>500,'truncated'=>count($rows)===500]);
} catch(Throwable $e) {
    reportFailureResponse($e,'Could not load the report drill-down.','REPORT_DRILLDOWN_FAILED');
}
