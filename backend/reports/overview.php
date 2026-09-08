<?php

header('Content-Type: application/json');
require_once __DIR__.'/../config/response.php';
require_once __DIR__.'/../config/db.php';
require_once __DIR__.'/../auth/auth_required.php';
require_once __DIR__.'/../auth/role_helper.php';
require_once __DIR__.'/vat_period_service.php';
require_once __DIR__.'/fiscal_result_service.php';
require_once __DIR__.'/report_error.php';

function reportOne(mysqli $conn,string $sql,string $types,array $args):array{
    $stmt=$conn->prepare($sql);$stmt->bind_param($types,...$args);$stmt->execute();
    $row=$stmt->get_result()->fetch_assoc()?:[];$stmt->close();return $row;
}
function reportRows(mysqli $conn,string $sql,string $types,array $args):array{
    $stmt=$conn->prepare($sql);$stmt->bind_param($types,...$args);$stmt->execute();
    $rows=$stmt->get_result()->fetch_all(MYSQLI_ASSOC);$stmt->close();return $rows;
}
function reportComparisonSnapshot(mysqli $conn,int $userId,string $from,string $to):array{
    $args=[$userId,$from,$to];
    $sales=reportOne($conn,"SELECT COUNT(*) documents,ROUND(COALESCE(SUM(CASE WHEN invoice_type='AVOIR' THEN -ABS(total_tnd) ELSE total_tnd END),0),3) sales_ttc,ROUND(COALESCE(SUM(CASE WHEN invoice_type='AVOIR' THEN -ABS(subtotal_tnd) ELSE subtotal_tnd END),0),3) revenue_ht FROM erp_invoices WHERE user_id=? AND invoice_date BETWEEN ? AND ? AND invoice_type IN('FACTURE','AVOIR') AND is_validated=1",'iss',$args);
    $purchases=reportOne($conn,"SELECT ROUND(COALESCE(SUM(total_ttc_tnd),0),3) purchases_ttc FROM erp_supplier_invoices WHERE user_id=? AND invoice_date BETWEEN ? AND ? AND status IN('VALIDATED','PARTIALLY_PAID','PAID')",'iss',$args);
    $expenses=reportOne($conn,"SELECT ROUND(COALESCE(SUM(amount),0),3) expenses FROM expense_notes WHERE user_id=? AND expense_date BETWEEN ? AND ? AND status IN('APPROVED','REIMBURSED')",'iss',$args);
    $collections=reportOne($conn,"SELECT ROUND(COALESCE(SUM(COALESCE(p.amount_tnd,p.amount*i.exchange_rate)),0),3) collections FROM erp_invoice_payments p JOIN erp_invoices i ON i.id=p.invoice_id AND i.user_id=p.user_id WHERE p.user_id=? AND p.payment_date BETWEEN ? AND ? AND p.status='POSTED'",'iss',$args);
    $cogs=reportOne($conn,"SELECT ROUND(COALESCE(SUM(cogs_value),0),3) cogs FROM product_stock_movements WHERE user_id=? AND created_at>=? AND created_at<DATE_ADD(?,INTERVAL 1 DAY)",'iss',$args);
    $revenue=(float)($sales['revenue_ht']??0);$cost=(float)($cogs['cogs']??0);$charges=(float)($expenses['expenses']??0);
    return ['from'=>$from,'to'=>$to,'documents'=>(int)($sales['documents']??0),'sales_ttc'=>(float)($sales['sales_ttc']??0),'revenue_ht'=>$revenue,'purchases_ttc'=>(float)($purchases['purchases_ttc']??0),'expenses'=>$charges,'collections'=>(float)($collections['collections']??0),'gross_profit'=>round($revenue-$cost,3),'operating_result'=>round($revenue-$cost-$charges,3)];
}

try{
    if($_SERVER['REQUEST_METHOD']!=='GET')jsonResponse(['success'=>false,'message'=>'Method not allowed'],405);
    $userId=(int)requireAuth()->id;$conn=db();requirePermission($conn,$userId,'reports.view');
    $from=(string)($_GET['from']??date('Y-m-01'));$to=(string)($_GET['to']??date('Y-m-d'));
    if(!preg_match('/^\d{4}-\d{2}-\d{2}$/',$from)||!preg_match('/^\d{4}-\d{2}-\d{2}$/',$to)||$to<$from)throw new InvalidArgumentException('Invalid report period');
    $period=[$userId,$from,$to];
    $fromDate=new DateTimeImmutable($from);$toDate=new DateTimeImmutable($to);$periodDays=(int)$fromDate->diff($toDate)->format('%a')+1;
    $previousTo=$fromDate->sub(new DateInterval('P1D'));$previousFrom=$previousTo->sub(new DateInterval('P'.($periodDays-1).'D'));
    $priorYearFrom=$fromDate->sub(new DateInterval('P1Y'));$priorYearTo=$toDate->sub(new DateInterval('P1Y'));
    $comparison=['current'=>reportComparisonSnapshot($conn,$userId,$from,$to),'previous'=>reportComparisonSnapshot($conn,$userId,$previousFrom->format('Y-m-d'),$previousTo->format('Y-m-d')),'prior_year'=>reportComparisonSnapshot($conn,$userId,$priorYearFrom->format('Y-m-d'),$priorYearTo->format('Y-m-d'))];

    $sales=reportOne($conn,"SELECT COUNT(*) documents,
        SUM(invoice_type='FACTURE') invoices,SUM(invoice_type='AVOIR') credit_notes,
        ROUND(COALESCE(SUM(CASE WHEN invoice_type='AVOIR' THEN -ABS(total_tnd) ELSE total_tnd END),0),3) total,
        ROUND(COALESCE(SUM(CASE WHEN invoice_type='AVOIR' THEN -ABS(subtotal_tnd) ELSE subtotal_tnd END),0),3) revenue_ht
        FROM erp_invoices WHERE user_id=? AND invoice_date BETWEEN ? AND ?
          AND invoice_type IN('FACTURE','AVOIR') AND is_validated=1",'iss',$period);
    $purchases=reportOne($conn,"SELECT COUNT(*) documents,ROUND(COALESCE(SUM(total_ttc_tnd),0),3) total FROM erp_supplier_invoices WHERE user_id=? AND invoice_date BETWEEN ? AND ? AND status IN('VALIDATED','PARTIALLY_PAID','PAID')",'iss',$period);
    $vatCollected=reportRows($conn,"SELECT ii.tax_regime regime,ii.tva_rate rate,
        ROUND(SUM(CASE WHEN i.invoice_type='AVOIR' THEN -ABS(ii.subtotal_tnd) ELSE ii.subtotal_tnd END),3) taxable_base_tnd,
        ROUND(SUM(CASE WHEN i.invoice_type='AVOIR' THEN -ABS(ii.montant_tva*i.exchange_rate) ELSE ii.montant_tva*i.exchange_rate END),3) amount
        FROM erp_invoice_items ii JOIN erp_invoices i ON i.id=ii.invoice_id
        WHERE i.user_id=? AND i.invoice_date BETWEEN ? AND ? AND i.invoice_type IN('FACTURE','AVOIR') AND i.is_validated=1
        GROUP BY ii.tax_regime,ii.tva_rate ORDER BY ii.tax_regime,ii.tva_rate",'iss',$period);
    $vatPurchases=reportRows($conn,"SELECT sii.tax_regime regime,sii.vat_rate rate,
        ROUND(COALESCE(SUM(sii.total_ht_tnd),0),3) taxable_base_tnd,
        ROUND(COALESCE(SUM(sii.deductible_vat_tnd),0),3) deductible_amount,
        ROUND(COALESCE(SUM(sii.non_deductible_vat_tnd),0),3) non_deductible_amount
        FROM erp_supplier_invoice_items sii JOIN erp_supplier_invoices si ON si.id=sii.supplier_invoice_id
        WHERE si.user_id=? AND si.invoice_date BETWEEN ? AND ? AND si.status IN('VALIDATED','PARTIALLY_PAID','PAID')
        GROUP BY sii.tax_regime,sii.vat_rate ORDER BY sii.tax_regime,sii.vat_rate",'iss',$period);
    $vatDeductible=array_map(static fn(array $row):array=>['regime'=>$row['regime'],'rate'=>$row['rate'],'amount'=>$row['deductible_amount']],$vatPurchases);
    $vatNonDeductible=array_map(static fn(array $row):array=>['regime'=>$row['regime'],'rate'=>$row['rate'],'amount'=>$row['non_deductible_amount']],$vatPurchases);
    $fodecSales=reportRows($conn,"SELECT ii.fodec_rate rate,
        ROUND(SUM(CASE WHEN i.invoice_type='AVOIR' THEN -ABS(ii.subtotal_tnd) ELSE ii.subtotal_tnd END),3) taxable_base_tnd,
        ROUND(SUM(CASE WHEN i.invoice_type='AVOIR' THEN -ABS(ii.fodec_amount*i.exchange_rate) ELSE ii.fodec_amount*i.exchange_rate END),3) amount_tnd
        FROM erp_invoice_items ii JOIN erp_invoices i ON i.id=ii.invoice_id
        WHERE i.user_id=? AND i.invoice_date BETWEEN ? AND ? AND i.invoice_type IN('FACTURE','AVOIR') AND i.is_validated=1 AND ii.fodec_rate>0
        GROUP BY ii.fodec_rate ORDER BY ii.fodec_rate",'iss',$period);
    $fodecPurchases=reportRows($conn,"SELECT sii.fodec_rate rate,ROUND(SUM(sii.total_ht_tnd),3) taxable_base_tnd,
        ROUND(SUM(sii.fodec_amount*si.exchange_rate),3) amount_tnd
        FROM erp_supplier_invoice_items sii JOIN erp_supplier_invoices si ON si.id=sii.supplier_invoice_id
        WHERE si.user_id=? AND si.invoice_date BETWEEN ? AND ? AND si.status IN('VALIDATED','PARTIALLY_PAID','PAID') AND sii.fodec_rate>0
        GROUP BY sii.fodec_rate ORDER BY sii.fodec_rate",'iss',$period);
    $fodecChecks=reportOne($conn,"SELECT
        (SELECT COUNT(*) FROM erp_invoice_items ii JOIN erp_invoices i ON i.id=ii.invoice_id WHERE i.user_id=? AND i.invoice_date BETWEEN ? AND ? AND i.invoice_type IN('FACTURE','AVOIR') AND i.is_validated=1 AND ABS(ii.fodec_amount-ROUND(ii.subtotal*ii.fodec_rate/100,3))>0.001) sales_line_mismatches,
        (SELECT COUNT(*) FROM erp_supplier_invoice_items sii JOIN erp_supplier_invoices si ON si.id=sii.supplier_invoice_id WHERE si.user_id=? AND si.invoice_date BETWEEN ? AND ? AND si.status<>'CANCELLED' AND ABS(sii.fodec_amount-ROUND(sii.total_ht*sii.fodec_rate/100,3))>0.001) purchase_line_mismatches,
        (SELECT COUNT(*) FROM erp_invoices i JOIN(SELECT invoice_id,ROUND(SUM(tax_tnd),3) line_tax_tnd FROM erp_invoice_items GROUP BY invoice_id)x ON x.invoice_id=i.id WHERE i.user_id=? AND i.invoice_date BETWEEN ? AND ? AND i.invoice_type IN('FACTURE','AVOIR') AND i.is_validated=1 AND ABS(i.tax_total_tnd-x.line_tax_tnd)>0.001) sales_document_mismatches,
        (SELECT COUNT(*) FROM erp_supplier_invoices si JOIN(SELECT supplier_invoice_id,ROUND(SUM(total_tax_tnd),3) line_tax_tnd FROM erp_supplier_invoice_items GROUP BY supplier_invoice_id)x ON x.supplier_invoice_id=si.id WHERE si.user_id=? AND si.invoice_date BETWEEN ? AND ? AND si.status<>'CANCELLED' AND ABS(si.total_tax_tnd-x.line_tax_tnd)>0.001) purchase_document_mismatches",'ississississ',[$userId,$from,$to,$userId,$from,$to,$userId,$from,$to,$userId,$from,$to]);
    $stampSales=reportOne($conn,"SELECT
        SUM(invoice_type='FACTURE' AND timbre>0) issued_documents,SUM(invoice_type='AVOIR' AND timbre>0) credited_documents,
        ROUND(COALESCE(SUM(CASE WHEN invoice_type='AVOIR' THEN -ABS(timbre*exchange_rate) ELSE timbre*exchange_rate END),0),3) net_tnd
        FROM erp_invoices WHERE user_id=? AND invoice_date BETWEEN ? AND ? AND invoice_type IN('FACTURE','AVOIR') AND is_validated=1",'iss',$period);
    $stampPurchases=reportOne($conn,"SELECT SUM(stamp_duty>0) documents,ROUND(COALESCE(SUM(stamp_duty_tnd),0),3) amount_tnd
        FROM erp_supplier_invoices WHERE user_id=? AND invoice_date BETWEEN ? AND ? AND status IN('VALIDATED','PARTIALLY_PAID','PAID')",'iss',$period);
    $stampChecks=reportOne($conn,"SELECT
        (SELECT COUNT(*) FROM erp_invoices WHERE user_id=? AND invoice_date BETWEEN ? AND ? AND invoice_type IN('FACTURE','AVOIR') AND is_validated=1 AND (timbre<0 OR ABS(total_tnd-total*exchange_rate)>0.001)) sales_mismatches,
        (SELECT COUNT(*) FROM erp_supplier_invoices WHERE user_id=? AND invoice_date BETWEEN ? AND ? AND status<>'CANCELLED' AND (stamp_duty<0 OR ABS(stamp_duty_tnd-ROUND(stamp_duty*exchange_rate,3))>0.001)) purchase_mismatches",'ississ',[$userId,$from,$to,$userId,$from,$to]);
    $contributions=reportRows($conn,"SELECT contribution,basis_kind,ROUND(SUM(basis_amount),3) basis_amount,
        ROUND(SUM(calculated_amount),3) calculated_amount,COUNT(*) periods,
        SUM(status='DRAFT') drafts,SUM(status='REVIEWED') reviewed,SUM(status IN('LOCKED','FILED')) finalized
        FROM erp_contribution_periods WHERE user_id=? AND period_start>=? AND period_end<=?
        GROUP BY contribution,basis_kind ORDER BY contribution,basis_kind",'iss',$period);
    $contributionChecks=reportOne($conn,"SELECT COUNT(*) mismatches FROM erp_contribution_periods
        WHERE user_id=? AND period_start>=? AND period_end<=? AND ABS(calculated_amount-ROUND(basis_amount*rate/100,3))>0.001",'iss',$period);
    $declarationYear=(int)substr($to,0,4);
    $employerDeclaration=reportOne($conn,"SELECT d.id,d.status,COUNT(l.id) line_count,
        ROUND(COALESCE(SUM(l.gross_amount),0),3) gross_amount,ROUND(COALESCE(SUM(l.withheld_amount),0),3) withheld_amount,
        SUM(l.beneficiary_fiscal_id IS NULL OR l.beneficiary_fiscal_id='') missing_fiscal_ids
        FROM erp_employer_declarations d LEFT JOIN erp_employer_declaration_lines l ON l.declaration_id=d.id
        WHERE d.user_id=? AND d.declaration_year=? GROUP BY d.id,d.status",'ii',[$userId,$declarationYear]);
    $employerByCategory=reportRows($conn,"SELECT l.category,COUNT(*) line_count,ROUND(SUM(l.gross_amount),3) gross_amount,ROUND(SUM(l.withheld_amount),3) withheld_amount
        FROM erp_employer_declaration_lines l JOIN erp_employer_declarations d ON d.id=l.declaration_id
        WHERE d.user_id=? AND d.declaration_year=? GROUP BY l.category ORDER BY l.category",'ii',[$userId,$declarationYear]);
    $supplierCoverage=reportOne($conn,"SELECT COUNT(*) payments,ROUND(COALESCE(SUM(COALESCE(sp.amount_tnd,sp.amount*si.exchange_rate)),0),3) amount
        FROM erp_supplier_payments sp JOIN erp_supplier_invoices si ON si.id=sp.supplier_invoice_id AND si.user_id=sp.user_id LEFT JOIN erp_employer_declaration_lines l ON l.source_supplier_payment_id=sp.id AND l.user_id=sp.user_id
        WHERE sp.user_id=? AND YEAR(sp.payment_date)=? AND sp.voided_at IS NULL AND l.id IS NULL",'ii',[$userId,$declarationYear]);
    $currentFiscalResult=operationalAccountingResult($conn,$userId,$declarationYear);
    $fiscalResult=reportOne($conn,"SELECT r.id,r.status,r.accounting_source,r.accounting_result,
        ROUND(COALESCE(SUM(CASE WHEN a.adjustment_type='ADDITION' THEN a.amount ELSE 0 END),0),3) additions,
        ROUND(COALESCE(SUM(CASE WHEN a.adjustment_type='DEDUCTION' THEN a.amount ELSE 0 END),0),3) deductions,COUNT(a.id) adjustments,
        SUM(a.legal_basis='') missing_legal_basis
        FROM erp_fiscal_reconciliations r LEFT JOIN erp_fiscal_adjustments a ON a.reconciliation_id=r.id
        WHERE r.user_id=? AND r.fiscal_year=? GROUP BY r.id",'ii',[$userId,$declarationYear]);
    $fiscalAccounting=(float)($fiscalResult['accounting_result']??$currentFiscalResult['result']);$fiscalAdd=(float)($fiscalResult['additions']??0);$fiscalDed=(float)($fiscalResult['deductions']??0);
    $taxSchedules=reportRows($conn,"SELECT schedule_type,COUNT(*) entries,ROUND(SUM(gross_amount),3) gross_amount,
        ROUND(SUM(accounting_amount),3) accounting_amount,ROUND(SUM(fiscal_amount),3) fiscal_amount,
        ROUND(SUM(fiscal_addition),3) fiscal_addition,ROUND(SUM(fiscal_deduction),3) fiscal_deduction,
        SUM(status='DRAFT') drafts,SUM(legal_basis='' OR evidence_reference IS NULL OR evidence_reference='') evidence_to_review
        FROM erp_tax_schedule_entries WHERE user_id=? AND fiscal_year=? AND status<>'CANCELLED'
        GROUP BY schedule_type ORDER BY schedule_type",'ii',[$userId,$declarationYear]);
    $taxScheduleTotals=array_reduce($taxSchedules,static function(array $out,array $row):array{foreach(['entries','fiscal_addition','fiscal_deduction','drafts','evidence_to_review'] as $key)$out[$key]=($out[$key]??0)+(float)($row[$key]??0);return $out;},[]);
    $filingArchives=reportOne($conn,"SELECT COUNT(*) archives,COALESCE(SUM(source_row_count),0) source_rows,MAX(captured_at) latest_capture FROM erp_filing_archives WHERE user_id=?",'i',[$userId]);
    $reviews=reportOne($conn,"SELECT COUNT(*) events,SUM(action='APPROVE') approvals,SUM(action='REQUEST_CHANGES') change_requests,SUM(action='REJECT') rejections,MAX(created_at) latest_review FROM erp_accountant_review_events WHERE user_id=?",'i',[$userId]);
    $reopenings=reportOne($conn,"SELECT COUNT(*) reopenings,SUM(previous_status='FILED') filed_reopenings,MAX(reopened_at) latest_reopening FROM erp_period_reopenings WHERE user_id=?",'i',[$userId]);
    $customer=reportOne($conn,"SELECT COUNT(*) documents,ROUND(COALESCE(SUM(balance),0),3) balance,
        ROUND(COALESCE(SUM(CASE WHEN days_overdue<=0 THEN balance ELSE 0 END),0),3) current,
        ROUND(COALESCE(SUM(CASE WHEN days_overdue BETWEEN 1 AND 30 THEN balance ELSE 0 END),0),3) days_1_30,
        ROUND(COALESCE(SUM(CASE WHEN days_overdue BETWEEN 31 AND 60 THEN balance ELSE 0 END),0),3) days_31_60,
        ROUND(COALESCE(SUM(CASE WHEN days_overdue BETWEEN 61 AND 90 THEN balance ELSE 0 END),0),3) days_61_90,
        ROUND(COALESCE(SUM(CASE WHEN days_overdue>90 THEN balance ELSE 0 END),0),3) days_90_plus FROM(
        SELECT i.invoice_due_date,DATEDIFF(?,i.invoice_due_date) days_overdue,
          i.total_tnd-(COALESCE(p.paid,0)+COALESCE(w.withheld,0))*i.exchange_rate-COALESCE(cr.credited,0) balance
        FROM erp_invoices i
        LEFT JOIN(SELECT invoice_id,SUM(amount) paid FROM erp_invoice_payments WHERE status='POSTED' AND payment_date<=? GROUP BY invoice_id)p ON p.invoice_id=i.id
        LEFT JOIN(SELECT invoice_id,SUM(withheld_amount) withheld FROM erp_invoice_withholdings WHERE certificate_status IN('RECEIVED','VALIDATED') AND certificate_date<=? GROUP BY invoice_id)w ON w.invoice_id=i.id
        LEFT JOIN(SELECT source_invoice_id,SUM(ABS(total_tnd)) credited FROM erp_invoices WHERE invoice_type='AVOIR' AND is_validated=1 AND invoice_date<=? GROUP BY source_invoice_id)cr ON cr.source_invoice_id=i.id
        WHERE i.user_id=? AND i.invoice_type='FACTURE' AND i.is_validated=1 AND i.invoice_date<=?) aging
        WHERE balance>0",'ssssis',[$to,$to,$to,$to,$userId,$to]);
    $supplier=reportOne($conn,"SELECT COUNT(*) documents,ROUND(COALESCE(SUM(balance),0),3) balance,
        ROUND(COALESCE(SUM(CASE WHEN days_overdue<=0 THEN balance ELSE 0 END),0),3) current,
        ROUND(COALESCE(SUM(CASE WHEN days_overdue BETWEEN 1 AND 30 THEN balance ELSE 0 END),0),3) days_1_30,
        ROUND(COALESCE(SUM(CASE WHEN days_overdue BETWEEN 31 AND 60 THEN balance ELSE 0 END),0),3) days_31_60,
        ROUND(COALESCE(SUM(CASE WHEN days_overdue BETWEEN 61 AND 90 THEN balance ELSE 0 END),0),3) days_61_90,
        ROUND(COALESCE(SUM(CASE WHEN days_overdue>90 THEN balance ELSE 0 END),0),3) days_90_plus FROM(
        SELECT DATEDIFF(?,si.due_date) days_overdue,si.total_ttc_tnd-(si.credited_amount+COALESCE(p.paid,0))*si.exchange_rate balance
        FROM erp_supplier_invoices si LEFT JOIN(SELECT supplier_invoice_id,SUM(amount) paid FROM erp_supplier_payments WHERE voided_at IS NULL AND payment_date<=? GROUP BY supplier_invoice_id)p ON p.supplier_invoice_id=si.id
        WHERE si.user_id=? AND si.invoice_date<=? AND si.status IN('VALIDATED','PARTIALLY_PAID','PAID')) aging WHERE balance>0",'ssis',[$to,$to,$userId,$to]);
    $cash=reportRows($conn,"SELECT p.method,ROUND(SUM(COALESCE(p.amount_tnd,p.amount*i.exchange_rate)),3) amount FROM erp_invoice_payments p JOIN erp_invoices i ON i.id=p.invoice_id AND i.user_id=p.user_id WHERE p.user_id=? AND p.payment_date BETWEEN ? AND ? AND p.status='POSTED' GROUP BY p.method ORDER BY p.method",'iss',$period);
    $withholding=reportOne($conn,"SELECT COUNT(*) records,
        SUM(w.certificate_status IN('RECEIVED','VALIDATED')) accepted_certificates,
        ROUND(COALESCE(SUM(CASE WHEN w.certificate_status IN('RECEIVED','VALIDATED') THEN w.withheld_amount ELSE 0 END),0),3) amount,
        SUM(w.certificate_status='PENDING') pending_certificates,
        SUM(w.certificate_status='PENDING' AND w.expected_certificate_date IS NOT NULL AND w.expected_certificate_date<?) overdue_certificates,
        SUM(w.certificate_status IN('RECEIVED','VALIDATED') AND w.attachment_path IS NULL) missing_attachments,
        SUM(ABS(w.withheld_amount-ROUND(w.calculation_base*w.rate/100,3))>0.001) amount_mismatches
        FROM erp_invoice_withholdings w JOIN erp_invoices i ON i.id=w.invoice_id
        WHERE w.user_id=? AND i.invoice_date BETWEEN ? AND ? AND i.invoice_type='FACTURE' AND i.is_validated=1",'siss',[$to,$userId,$from,$to]);
    $withholdingByStatus=reportRows($conn,"SELECT w.certificate_status status,COUNT(*) records,ROUND(SUM(w.withheld_amount),3) amount
        FROM erp_invoice_withholdings w JOIN erp_invoices i ON i.id=w.invoice_id
        WHERE w.user_id=? AND i.invoice_date BETWEEN ? AND ? AND i.invoice_type='FACTURE' AND i.is_validated=1
        GROUP BY w.certificate_status ORDER BY w.certificate_status",'iss',$period);
    $withholdingByType=reportRows($conn,"SELECT w.withholding_type type,COUNT(*) records,ROUND(SUM(CASE WHEN w.certificate_status IN('RECEIVED','VALIDATED') THEN w.withheld_amount ELSE 0 END),3) accepted_amount
        FROM erp_invoice_withholdings w JOIN erp_invoices i ON i.id=w.invoice_id
        WHERE w.user_id=? AND i.invoice_date BETWEEN ? AND ? AND i.invoice_type='FACTURE' AND i.is_validated=1
        GROUP BY w.withholding_type ORDER BY w.withholding_type",'iss',$period);
    $withholdingDuplicates=reportOne($conn,"SELECT COUNT(*) duplicate_numbers FROM(SELECT certificate_number FROM erp_invoice_withholdings WHERE user_id=? AND certificate_number<>'' AND certificate_status<>'CANCELLED' GROUP BY certificate_number HAVING COUNT(*)>1)x",'i',[$userId]);
    $expenses=reportOne($conn,"SELECT COUNT(*) documents,ROUND(COALESCE(SUM(amount),0),3) total FROM expense_notes WHERE user_id=? AND expense_date BETWEEN ? AND ? AND status IN('APPROVED','REIMBURSED')",'iss',$period);
    $stock=reportOne($conn,"SELECT COUNT(*) products,ROUND(COALESCE(SUM(stock_quantity*average_cost),0),3) valuation FROM products WHERE user_id=? AND item_type='PRODUCT'",'i',[$userId]);
    $cogs=reportOne($conn,"SELECT ROUND(COALESCE(SUM(cogs_value),0),3) cogs FROM product_stock_movements WHERE user_id=? AND created_at>=? AND created_at<DATE_ADD(?,INTERVAL 1 DAY)",'iss',$period);
    $periods=reportOne($conn,"SELECT COUNT(*) periods,SUM(status='DRAFT') drafts,SUM(status='REVIEWED') reviewed,SUM(status='LOCKED') locked,SUM(status='FILED') filed FROM erp_accounting_periods WHERE user_id=?",'i',[$userId]);
    $gaps=reportOne($conn,"SELECT COUNT(*) gaps FROM(SELECT n,LAG(n) OVER(PARTITION BY prefix,yr ORDER BY n) previous_n FROM(SELECT SUBSTRING_INDEX(invoice,'-',1) prefix,SUBSTRING_INDEX(SUBSTRING_INDEX(invoice,'-',2),'-',-1) yr,CAST(SUBSTRING_INDEX(invoice,'-',-1) AS UNSIGNED)n FROM erp_invoices WHERE user_id=? AND invoice REGEXP '^[A-Z]+-[0-9]{4}-[0-9]+$' AND is_validated=1)x)y WHERE previous_n IS NOT NULL AND n>previous_n+1",'i',[$userId]);
    $vatPeriod=calculateVatPeriod($conn,$userId,$from,$to,0);
    $savedStmt=$conn->prepare('SELECT opening_credit,vat_collected,vat_deductible,vat_payable,closing_credit,status,source_period_id FROM erp_vat_periods WHERE user_id=? AND period_start=? AND period_end=? LIMIT 1');
    $savedStmt->bind_param('iss',$userId,$from,$to);$savedStmt->execute();$savedVat=$savedStmt->get_result()->fetch_assoc();$savedStmt->close();
    if($savedVat)$vatPeriod=array_merge($vatPeriod,$savedVat);
    $revenue=(float)($sales['revenue_ht']??0);$cogsTotal=(float)($cogs['cogs']??0);$expenseTotal=(float)($expenses['total']??0);
    $collectedTotal=array_reduce($vatCollected,static fn(float $sum,array $row):float=>$sum+(float)($row['amount']??0),0.0);
    $deductibleTotal=array_reduce($vatDeductible,static fn(float $sum,array $row):float=>$sum+(float)($row['amount']??0),0.0);
    $agingKeys=['current','days_1_30','days_31_60','days_61_90','days_90_plus'];
    $customerBuckets=array_reduce($agingKeys,static fn(float $sum,string $key):float=>$sum+(float)($customer[$key]??0),0.0);
    $supplierBuckets=array_reduce($agingKeys,static fn(float $sum,string $key):float=>$sum+(float)($supplier[$key]??0),0.0);
    $check=static function(string $label,float $reported,float $sources):array{$difference=round($reported-$sources,3);return['label'=>$label,'reported'=>round($reported,3),'sources'=>round($sources,3),'difference'=>$difference,'matches'=>abs($difference)<=0.001];};
    $reconciliation=[
        $check('Échéancier clients',(float)($customer['balance']??0),$customerBuckets),
        $check('Échéancier fournisseurs',(float)($supplier['balance']??0),$supplierBuckets),
        $check('TVA collectée',(float)($vatPeriod['vat_collected']??0),$collectedTotal),
        $check('TVA déductible',(float)($vatPeriod['vat_deductible']??0),$deductibleTotal),
        $check('Marge brute',$revenue-$cogsTotal,$revenue-$cogsTotal),
        $check('Résultat opérationnel',$revenue-$cogsTotal-$expenseTotal,($revenue-$cogsTotal)-$expenseTotal),
    ];
    jsonResponse(['success'=>true,'period'=>['from'=>$from,'to'=>$to],'comparison'=>$comparison,'reconciliation'=>$reconciliation,'sign_policy'=>'FACTURE=+1; AVOIR=-1',
        'sales_journal'=>$sales,'purchase_journal'=>$purchases,
        'vat'=>['collected'=>$vatCollected,'deductible'=>$vatDeductible,'non_deductible'=>$vatNonDeductible,'purchases'=>$vatPurchases,
            'regime_bases'=>array_values(array_reduce($vatCollected,static function(array $out,array $row):array{$regime=$row['regime']??'STANDARD';$out[$regime]=['regime'=>$regime,'taxable_base_tnd'=>round((float)($out[$regime]['taxable_base_tnd']??0)+(float)$row['taxable_base_tnd'],3)];return $out;},[]))],
        'fodec'=>['sales'=>$fodecSales,'purchases'=>$fodecPurchases,'reconciliation'=>['sales_line_mismatches'=>(int)($fodecChecks['sales_line_mismatches']??0),'purchase_line_mismatches'=>(int)($fodecChecks['purchase_line_mismatches']??0),'sales_document_mismatches'=>(int)($fodecChecks['sales_document_mismatches']??0),'purchase_document_mismatches'=>(int)($fodecChecks['purchase_document_mismatches']??0)]],
        'stamp_duty'=>['sales'=>['issued_documents'=>(int)($stampSales['issued_documents']??0),'credited_documents'=>(int)($stampSales['credited_documents']??0),'net_tnd'=>(float)($stampSales['net_tnd']??0)],'purchases'=>['documents'=>(int)($stampPurchases['documents']??0),'amount_tnd'=>(float)($stampPurchases['amount_tnd']??0)],'reconciliation'=>['sales_mismatches'=>(int)($stampChecks['sales_mismatches']??0),'purchase_mismatches'=>(int)($stampChecks['purchase_mismatches']??0)]],
        'contributions'=>['schedules'=>$contributions,'reconciliation'=>['mismatches'=>(int)($contributionChecks['mismatches']??0)],'filing_ready'=>false],
        'employer_declaration'=>['year'=>$declarationYear,'status'=>$employerDeclaration['status']??'NOT_STARTED','lines'=>(int)($employerDeclaration['line_count']??0),'gross_amount'=>(float)($employerDeclaration['gross_amount']??0),'withheld_amount'=>(float)($employerDeclaration['withheld_amount']??0),'missing_fiscal_ids'=>(int)($employerDeclaration['missing_fiscal_ids']??0),'by_category'=>$employerByCategory,'unlinked_supplier_payments'=>(int)($supplierCoverage['payments']??0),'unlinked_supplier_amount'=>(float)($supplierCoverage['amount']??0),'filing_ready'=>false],
        'fiscal_result'=>['year'=>$declarationYear,'status'=>$fiscalResult['status']??'NOT_STARTED','accounting_source'=>$fiscalResult['accounting_source']??'OPERATIONAL_LEDGER','accounting_result'=>$fiscalAccounting,'current_operational_result'=>(float)$currentFiscalResult['result'],'snapshot_difference'=>round((float)$currentFiscalResult['result']-$fiscalAccounting,3),'additions'=>$fiscalAdd,'deductions'=>$fiscalDed,'taxable_result'=>round($fiscalAccounting+$fiscalAdd-$fiscalDed,3),'adjustments'=>(int)($fiscalResult['adjustments']??0),'missing_legal_basis'=>(int)($fiscalResult['missing_legal_basis']??0),'filing_ready'=>false],
        'tax_schedules'=>['year'=>$declarationYear,'by_type'=>$taxSchedules,'entries'=>(int)($taxScheduleTotals['entries']??0),'fiscal_addition'=>(float)($taxScheduleTotals['fiscal_addition']??0),'fiscal_deduction'=>(float)($taxScheduleTotals['fiscal_deduction']??0),'drafts'=>(int)($taxScheduleTotals['drafts']??0),'evidence_to_review'=>(int)($taxScheduleTotals['evidence_to_review']??0),'filing_ready'=>false],
        'filing_archives'=>['archives'=>(int)($filingArchives['archives']??0),'source_rows'=>(int)($filingArchives['source_rows']??0),'latest_capture'=>$filingArchives['latest_capture']??null],
        'accountant_reviews'=>['events'=>(int)($reviews['events']??0),'approvals'=>(int)($reviews['approvals']??0),'change_requests'=>(int)($reviews['change_requests']??0),'rejections'=>(int)($reviews['rejections']??0),'latest_review'=>$reviews['latest_review']??null],
        'period_reopenings'=>['reopenings'=>(int)($reopenings['reopenings']??0),'filed_reopenings'=>(int)($reopenings['filed_reopenings']??0),'latest_reopening'=>$reopenings['latest_reopening']??null],
        'monthly_tax'=>['opening_vat_credit'=>(float)$vatPeriod['opening_credit'],'vat_collected'=>(float)$vatPeriod['vat_collected'],
            'vat_deductible'=>(float)$vatPeriod['vat_deductible'],'available_vat_credit'=>(float)$vatPeriod['opening_credit']+(float)$vatPeriod['vat_deductible'],
            'vat_payable'=>(float)$vatPeriod['vat_payable'],'closing_vat_credit'=>(float)$vatPeriod['closing_credit'],
            'status'=>$vatPeriod['status']??'PREVIEW','source_period_id'=>$vatPeriod['source_period_id']??null,
            'withholding'=>(float)($withholding['amount']??0)],
        'profitability'=>['revenue'=>$revenue,'cogs'=>$cogsTotal,'expenses'=>$expenseTotal,'gross_profit'=>$revenue-$cogsTotal,'operating_result'=>$revenue-$cogsTotal-$expenseTotal],
        'expenses'=>$expenses,'customer_aging'=>$customer,'supplier_aging'=>$supplier,'cash_bank'=>$cash,'withholding'=>$withholding+['certificates'=>(int)($withholding['accepted_certificates']??0),'by_status'=>$withholdingByStatus,'by_type'=>$withholdingByType,'duplicate_numbers'=>(int)($withholdingDuplicates['duplicate_numbers']??0)],
        'stock'=>['products'=>(int)($stock['products']??0),'valuation'=>(float)($stock['valuation']??0),'cogs'=>$cogsTotal],
        'numbering_gaps'=>$gaps,'accounting_periods'=>$periods]);
}catch(Throwable $e){reportFailureResponse($e,'Could not load the reports overview.','REPORTS_FAILED');}
