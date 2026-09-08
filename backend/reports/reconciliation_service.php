<?php

declare(strict_types=1);

function validateReconciliationPeriod(string $from, string $to): void
{
    if (!preg_match('/^\d{4}-\d{2}-\d{2}$/', $from)
        || !preg_match('/^\d{4}-\d{2}-\d{2}$/', $to)
        || $to < $from) {
        throw new InvalidArgumentException('Invalid reconciliation period.');
    }
}

function reconciliationIssueCount(mysqli $conn, string $sql, string $types, array $args): int
{
    $stmt = $conn->prepare($sql);
    if ($types !== '') $stmt->bind_param($types, ...$args);
    $stmt->execute();
    $count = (int)($stmt->get_result()->fetch_assoc()['n'] ?? 0);
    $stmt->close();
    return $count;
}

/**
 * Run the detailed, read-only accounting integrity checks for one tenant and
 * period. The callback receives integer progress values between 5 and 95.
 */
function runTenantReportReconciliation(
    mysqli $conn,
    int $userId,
    string $from,
    string $to,
    ?callable $onProgress = null
): array {
    if ($userId <= 0) throw new InvalidArgumentException('Invalid reconciliation tenant.');
    validateReconciliationPeriod($from, $to);

    $checks = [
        ['sales_headers_to_lines','Ventes : en-têtes et lignes',"SELECT COUNT(*) n FROM erp_invoices i LEFT JOIN(
            SELECT ii.invoice_id,ROUND(SUM(ii.subtotal_tnd),3) ht,ROUND(SUM(ii.montant_tva*i2.exchange_rate),3) vat,ROUND(SUM(ii.total_tnd),3) total
            FROM erp_invoice_items ii JOIN erp_invoices i2 ON i2.id=ii.invoice_id WHERE i2.user_id=? GROUP BY ii.invoice_id
        )x ON x.invoice_id=i.id WHERE i.user_id=? AND i.invoice_date BETWEEN ? AND ? AND i.invoice_type IN('FACTURE','AVOIR') AND i.is_validated=1 AND(
            ABS(ABS(i.subtotal_tnd)-ABS(COALESCE(x.ht,0)))>0.001 OR ABS(ABS(i.montant_tva*i.exchange_rate)-ABS(COALESCE(x.vat,0)))>0.001 OR ABS(ABS(i.total_tnd-i.timbre*i.exchange_rate)-ABS(COALESCE(x.total,0)))>0.001)",'iiss',[$userId,$userId,$from,$to]],
        ['purchase_headers_to_lines','Achats : en-têtes et lignes',"SELECT COUNT(*) n FROM erp_supplier_invoices si LEFT JOIN(
            SELECT sii.supplier_invoice_id,ROUND(SUM(sii.total_ht_tnd),3) ht,ROUND(SUM(sii.total_tax_tnd),3) tax,ROUND(SUM(sii.total_ttc_tnd),3) total
            FROM erp_supplier_invoice_items sii JOIN erp_supplier_invoices si2 ON si2.id=sii.supplier_invoice_id WHERE si2.user_id=? GROUP BY sii.supplier_invoice_id
        )x ON x.supplier_invoice_id=si.id WHERE si.user_id=? AND si.invoice_date BETWEEN ? AND ? AND si.status IN('VALIDATED','PARTIALLY_PAID','PAID') AND(
            ABS(si.total_ht_tnd-COALESCE(x.ht,0))>0.001 OR ABS(si.total_tax_tnd-COALESCE(x.tax,0))>0.001 OR ABS(si.total_ttc_tnd-si.stamp_duty_tnd-COALESCE(x.total,0))>0.001)",'iiss',[$userId,$userId,$from,$to]],
        ['purchase_vat_buckets','TVA achats : déductible et non déductible',"SELECT COUNT(*) n FROM erp_supplier_invoice_items sii JOIN erp_supplier_invoices si ON si.id=sii.supplier_invoice_id
            WHERE si.user_id=? AND si.invoice_date BETWEEN ? AND ? AND si.status IN('VALIDATED','PARTIALLY_PAID','PAID')
            AND ABS(sii.deductible_vat_tnd+sii.non_deductible_vat_tnd-ROUND(sii.total_vat*si.exchange_rate,3))>0.001",'iss',[$userId,$from,$to]],
        ['customer_settlement_limits','Règlements clients : absence de dépassement',"SELECT COUNT(*) n FROM erp_invoices i
            LEFT JOIN(SELECT invoice_id,SUM(amount) amount FROM erp_invoice_payments WHERE user_id=? AND status='POSTED' AND payment_date<=? GROUP BY invoice_id)p ON p.invoice_id=i.id
            LEFT JOIN(SELECT invoice_id,SUM(withheld_amount) amount FROM erp_invoice_withholdings WHERE user_id=? AND certificate_status IN('RECEIVED','VALIDATED') AND certificate_date<=? GROUP BY invoice_id)w ON w.invoice_id=i.id
            LEFT JOIN(SELECT source_invoice_id,SUM(ABS(total)) amount FROM erp_invoices WHERE user_id=? AND invoice_type='AVOIR' AND is_validated=1 AND invoice_date<=? GROUP BY source_invoice_id)cr ON cr.source_invoice_id=i.id
            WHERE i.user_id=? AND i.invoice_type='FACTURE' AND i.is_validated=1 AND i.invoice_date BETWEEN ? AND ?
            AND COALESCE(p.amount,0)+COALESCE(w.amount,0)+COALESCE(cr.amount,0)-i.total>0.001",'isisisiss',[$userId,$to,$userId,$to,$userId,$to,$userId,$from,$to]],
        ['supplier_settlement_limits','Règlements fournisseurs : absence de dépassement',"SELECT COUNT(*) n FROM erp_supplier_invoices si
            LEFT JOIN(SELECT supplier_invoice_id,SUM(amount) amount FROM erp_supplier_payments WHERE user_id=? AND voided_at IS NULL AND payment_date<=? GROUP BY supplier_invoice_id)p ON p.supplier_invoice_id=si.id
            WHERE si.user_id=? AND si.invoice_date BETWEEN ? AND ? AND si.status IN('VALIDATED','PARTIALLY_PAID','PAID')
            AND COALESCE(p.amount,0)+si.credited_amount-si.total_ttc>0.001",'isiss',[$userId,$to,$userId,$from,$to]],
        ['recognized_expenses','Dépenses comptabilisées : montants valides',"SELECT COUNT(*) n FROM expense_notes WHERE user_id=? AND expense_date BETWEEN ? AND ? AND status IN('APPROVED','REIMBURSED') AND amount<0",'iss',[$userId,$from,$to]],
        ['sales_fodec','FODEC ventes : calcul des lignes',"SELECT COUNT(*) n FROM erp_invoice_items ii JOIN erp_invoices i ON i.id=ii.invoice_id WHERE i.user_id=? AND i.invoice_date BETWEEN ? AND ? AND i.is_validated=1
            AND(ii.fodec_rate NOT BETWEEN 0 AND 100 OR ABS(ii.fodec_amount-ROUND(ii.subtotal*ii.fodec_rate/100,3))>0.001)",'iss',[$userId,$from,$to]],
        ['purchase_fodec','FODEC achats : calcul des lignes',"SELECT COUNT(*) n FROM erp_supplier_invoice_items sii JOIN erp_supplier_invoices si ON si.id=sii.supplier_invoice_id WHERE si.user_id=? AND si.invoice_date BETWEEN ? AND ? AND si.status<>'CANCELLED'
            AND(sii.fodec_rate NOT BETWEEN 0 AND 100 OR ABS(sii.fodec_amount-ROUND(sii.total_ht*sii.fodec_rate/100,3))>0.001)",'iss',[$userId,$from,$to]],
        ['sales_document_tax','Ventes : taxes des documents',"SELECT COUNT(*) n FROM erp_invoices i LEFT JOIN(
            SELECT ii.invoice_id,ROUND(SUM(ii.tax_tnd),3) line_tax FROM erp_invoice_items ii JOIN erp_invoices i2 ON i2.id=ii.invoice_id WHERE i2.user_id=? GROUP BY ii.invoice_id
        )x ON x.invoice_id=i.id WHERE i.user_id=? AND i.invoice_date BETWEEN ? AND ? AND i.is_validated=1 AND ABS(i.tax_total_tnd-COALESCE(x.line_tax,0))>0.001",'iiss',[$userId,$userId,$from,$to]],
        ['purchase_document_tax','Achats : taxes des documents',"SELECT COUNT(*) n FROM erp_supplier_invoices si LEFT JOIN(
            SELECT sii.supplier_invoice_id,ROUND(SUM(sii.total_tax_tnd),3) line_tax FROM erp_supplier_invoice_items sii JOIN erp_supplier_invoices si2 ON si2.id=sii.supplier_invoice_id WHERE si2.user_id=? GROUP BY sii.supplier_invoice_id
        )x ON x.supplier_invoice_id=si.id WHERE si.user_id=? AND si.invoice_date BETWEEN ? AND ? AND si.status<>'CANCELLED' AND ABS(si.total_tax_tnd-COALESCE(x.line_tax,0))>0.001",'iiss',[$userId,$userId,$from,$to]],
        ['sales_stamp_duty','Ventes : droit de timbre et total',"SELECT COUNT(*) n FROM erp_invoices WHERE user_id=? AND invoice_date BETWEEN ? AND ? AND is_validated=1
            AND(timbre<0 OR ABS(total_tnd-ROUND(total*exchange_rate,3))>0.001)",'iss',[$userId,$from,$to]],
        ['purchase_stamp_duty','Achats : droit de timbre et total',"SELECT COUNT(*) n FROM erp_supplier_invoices WHERE user_id=? AND invoice_date BETWEEN ? AND ? AND status<>'CANCELLED'
            AND(stamp_duty<0 OR ABS(stamp_duty_tnd-ROUND(stamp_duty*exchange_rate,3))>0.001)",'iss',[$userId,$from,$to]],
        ['withholding_register','Retenues : formule et certificats',"SELECT COUNT(*) n FROM erp_invoice_withholdings w JOIN erp_invoices i ON i.id=w.invoice_id
            WHERE w.user_id=? AND i.invoice_date BETWEEN ? AND ? AND i.is_validated=1 AND(
              w.rate NOT BETWEEN 0 AND 100 OR w.calculation_base<=0 OR ABS(w.withheld_amount-ROUND(w.calculation_base*w.rate/100,3))>0.001
              OR(w.certificate_status IN('RECEIVED','VALIDATED') AND(w.certificate_number='' OR w.certificate_date IS NULL)))",'iss',[$userId,$from,$to]],
        ['tenant_ownership','Isolation société des sources comptables',"SELECT
            (SELECT COUNT(*) FROM erp_invoice_items ii JOIN erp_invoices i ON i.id=ii.invoice_id JOIN products p ON p.id=ii.product_id WHERE i.user_id=? AND p.user_id<>i.user_id)
            +(SELECT COUNT(*) FROM erp_invoice_payments p JOIN erp_invoices i ON i.id=p.invoice_id WHERE i.user_id=? AND p.user_id<>i.user_id)
            +(SELECT COUNT(*) FROM erp_supplier_payments p JOIN erp_supplier_invoices i ON i.id=p.supplier_invoice_id WHERE i.user_id=? AND p.user_id<>i.user_id) n",'iii',[$userId,$userId,$userId]],
    ];

    $results = [];
    $totalIssues = 0;
    $totalChecks = count($checks);
    foreach ($checks as $index => [$key,$label,$sql,$types,$args]) {
        $issues = reconciliationIssueCount($conn, $sql, $types, $args);
        $totalIssues += $issues;
        $results[] = ['key'=>$key,'label'=>$label,'issues'=>$issues,'matches'=>$issues===0];
        if ($onProgress) $onProgress(5 + (int)floor((($index + 1) / $totalChecks) * 90));
    }
    return [
        'checked_at' => gmdate('Y-m-d\TH:i:s\Z'),
        'checks' => $results,
        'from' => $from,
        'issue_count' => $totalIssues,
        'matches' => $totalIssues === 0,
        'to' => $to,
    ];
}
