<?php

declare(strict_types=1);

header('Content-Type: application/json; charset=utf-8');
header('Cache-Control: no-store, private');
require_once __DIR__ . '/../config/response.php';
require_once __DIR__ . '/../config/db.php';
require_once __DIR__ . '/../auth/auth_required.php';
require_once __DIR__ . '/../auth/role_helper.php';

function mobileAccountingRows(mysqli $conn, string $sql, string $types, array $args): array
{
    $stmt = $conn->prepare($sql);
    if (!$stmt) throw new RuntimeException('Could not prepare accounting review query.');
    if ($types !== '') $stmt->bind_param($types, ...$args);
    $stmt->execute();
    $rows = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);
    $stmt->close();
    return $rows;
}

function mobileAccountingOne(mysqli $conn, string $sql, string $types, array $args): array
{
    return mobileAccountingRows($conn, $sql, $types, $args)[0] ?? [];
}

function mobileAccountingEntry(
    string $kind,
    int $id,
    string $title,
    string $party,
    string $documentNumber,
    string $date,
    string $dueDate,
    string $status,
    float $amountTnd,
    string $entityType,
    int $entityId,
    string $matchStatus = ''
): array {
    return [
        'kind' => $kind,
        'id' => $id,
        'title' => $title,
        'party' => $party,
        'documentNumber' => $documentNumber,
        'date' => $date,
        'dueDate' => $dueDate,
        'status' => $status,
        'amountTnd' => round($amountTnd, 3),
        'entityType' => $entityType,
        'entityId' => $entityId,
        'matchStatus' => $matchStatus,
    ];
}

try {
    if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'GET') {
        jsonResponse(['success'=>false,'message'=>'Method not allowed. Use GET.'], 405);
    }

    $auth = requireAuth();
    $tenantId = authTenantId($auth);
    $actorId = authActorId($auth);
    $conn = db();
    requireAnyPermission($conn, $actorId, [
        'invoices.view', 'supplierInvoices.view', 'expenses.view',
        'payments.view', 'withholding.view', 'reports.view',
    ]);

    $canReceivables = userHasPermission($conn, $actorId, 'invoices.view');
    $canCustomerPayments = userHasPermission($conn, $actorId, 'payments.view');
    $canWithholding = userHasPermission($conn, $actorId, 'withholding.view');
    $canPayables = userHasPermission($conn, $actorId, 'supplierInvoices.view');
    $canExpenses = userHasPermission($conn, $actorId, 'expenses.view');
    $canCustomerCredits = userHasPermission($conn, $actorId, 'avoirs.view');
    $canSupplierReturns = userHasPermission($conn, $actorId, 'supplierReceptions.view');

    $summary = [
        'receivableCount'=>0, 'receivableBalanceTnd'=>0.0,
        'overdueReceivableCount'=>0, 'overdueReceivableTnd'=>0.0,
        'payableCount'=>0, 'payableBalanceTnd'=>0.0,
        'overduePayableCount'=>0, 'overduePayableTnd'=>0.0,
        'matchingIssueCount'=>0,
        'pendingExpenseCount'=>0, 'pendingExpenseTnd'=>0.0,
        'pendingWithholdingCount'=>0, 'pendingWithholdingTnd'=>0.0,
        'customerPaymentCount30d'=>0, 'customerPaymentTnd30d'=>0.0,
        'supplierPaymentCount30d'=>0, 'supplierPaymentTnd30d'=>0.0,
        'customerCreditCount30d'=>0, 'supplierCreditCount30d'=>0,
        'supplierReturnCount30d'=>0,
    ];
    $receivables = [];
    $payables = [];
    $expenses = [];
    $activity = [];

    if ($canReceivables) {
        $balanceExpression = "GREATEST(i.total_tnd
            - COALESCE((SELECT SUM(COALESCE(p.amount_tnd,p.amount*COALESCE(p.exchange_rate,i.exchange_rate,1))) FROM erp_invoice_payments p WHERE p.invoice_id=i.id AND p.user_id=i.user_id AND p.status='POSTED'),0)
            - COALESCE((SELECT SUM(w.withheld_amount*COALESCE(i.exchange_rate,1)) FROM erp_invoice_withholdings w WHERE w.invoice_id=i.id AND w.user_id=i.user_id AND w.certificate_status IN('RECEIVED','VALIDATED')),0)
            - COALESCE((SELECT SUM(ABS(c.total_tnd)) FROM erp_invoices c WHERE c.source_invoice_id=i.id AND c.user_id=i.user_id AND c.invoice_type='AVOIR' AND c.is_validated=1 AND UPPER(c.status)<>'CANCELLED'),0),0)";
        $receivableSource = "SELECT i.id,i.invoice document_number,i.invoice_date document_date,i.invoice_due_date due_date,
                i.total_tnd,c.name party_name,$balanceExpression balance_tnd
            FROM erp_invoices i
            LEFT JOIN clients c ON c.id=CAST(i.custom_code AS UNSIGNED) AND c.user_id=i.user_id
            WHERE i.user_id=? AND UPPER(i.invoice_type)='FACTURE' AND i.is_validated=1 AND UPPER(i.status)<>'CANCELLED'";
        $totals = mobileAccountingOne($conn, "SELECT COUNT(*) receivable_count,
                ROUND(COALESCE(SUM(balance_tnd),0),3) receivable_balance_tnd,
                SUM(due_date<CURDATE()) overdue_count,
                ROUND(COALESCE(SUM(CASE WHEN due_date<CURDATE() THEN balance_tnd ELSE 0 END),0),3) overdue_tnd
            FROM ($receivableSource) open_receivables WHERE balance_tnd>0.0005", 'i', [$tenantId]);
        $summary['receivableCount'] = (int)($totals['receivable_count'] ?? 0);
        $summary['receivableBalanceTnd'] = (float)($totals['receivable_balance_tnd'] ?? 0);
        $summary['overdueReceivableCount'] = (int)($totals['overdue_count'] ?? 0);
        $summary['overdueReceivableTnd'] = (float)($totals['overdue_tnd'] ?? 0);
        $rows = mobileAccountingRows($conn, "$receivableSource HAVING balance_tnd>0.0005
            ORDER BY (due_date<CURDATE()) DESC,due_date ASC,i.id DESC LIMIT 30", 'i', [$tenantId]);
        foreach ($rows as $row) {
            $overdue = (string)$row['due_date'] < date('Y-m-d');
            $receivables[] = mobileAccountingEntry(
                'RECEIVABLE', (int)$row['id'], $overdue ? 'Overdue customer invoice' : 'Customer invoice due',
                (string)($row['party_name'] ?? ''), (string)$row['document_number'], (string)$row['document_date'],
                (string)$row['due_date'], $overdue ? 'OVERDUE' : 'UNPAID', (float)$row['balance_tnd'],
                'INVOICE', (int)$row['id']
            );
        }
    }

    if ($canPayables) {
        $payableBalance = "GREATEST(si.total_ttc_tnd
            - COALESCE(si.credited_amount*si.exchange_rate,0)
            - COALESCE((SELECT SUM(COALESCE(sp.amount_tnd,sp.amount*COALESCE(sp.exchange_rate,si.exchange_rate,1))) FROM erp_supplier_payments sp WHERE sp.supplier_invoice_id=si.id AND sp.user_id=si.user_id AND sp.voided_at IS NULL),0),0)";
        $payableSource = "SELECT si.id,si.invoice_number,si.invoice_date,si.due_date,si.status,si.currency,
                si.total_ttc_tnd,s.name supplier_name,$payableBalance balance_tnd
            FROM erp_supplier_invoices si
            JOIN suppliers s ON s.id=si.supplier_id AND s.user_id=si.user_id
            WHERE si.user_id=? AND si.status IN('VALIDATED','PARTIALLY_PAID')";
        $totals = mobileAccountingOne($conn, "SELECT COUNT(*) payable_count,
                ROUND(COALESCE(SUM(balance_tnd),0),3) payable_balance_tnd,
                SUM(due_date<CURDATE()) overdue_count,
                ROUND(COALESCE(SUM(CASE WHEN due_date<CURDATE() THEN balance_tnd ELSE 0 END),0),3) overdue_tnd
            FROM ($payableSource) open_payables WHERE balance_tnd>0.0005", 'i', [$tenantId]);
        $summary['payableCount'] = (int)($totals['payable_count'] ?? 0);
        $summary['payableBalanceTnd'] = (float)($totals['payable_balance_tnd'] ?? 0);
        $summary['overduePayableCount'] = (int)($totals['overdue_count'] ?? 0);
        $summary['overduePayableTnd'] = (float)($totals['overdue_tnd'] ?? 0);

        // The full supplier-invoice projection performs deep three-way matching
        // subqueries for every invoice and can exceed the mobile HTTP timeout.
        // The review overview only needs the count of invoices that have no lines
        // or at least one line that is not linked to a reception. Price/quantity
        // variance remains available in the dedicated supplier invoice screen.
        $matching = mobileAccountingOne($conn, "SELECT COUNT(*) matching_issues
            FROM erp_supplier_invoices si
            WHERE si.user_id=? AND si.status<>'CANCELLED'
              AND (
                NOT EXISTS (
                    SELECT 1 FROM erp_supplier_invoice_items sii
                    WHERE sii.supplier_invoice_id=si.id
                )
                OR EXISTS (
                    SELECT 1 FROM erp_supplier_invoice_items sii
                    WHERE sii.supplier_invoice_id=si.id
                      AND sii.supplier_reception_item_id IS NULL
                )
              )", 'i', [$tenantId]);
        $summary['matchingIssueCount'] = (int)($matching['matching_issues'] ?? 0);

        $rawPayables = mobileAccountingRows($conn, "SELECT
                si.id,si.invoice_number,si.invoice_date,si.due_date,si.status,
                s.name supplier_name,$payableBalance balance_tnd,
                CASE
                    WHEN NOT EXISTS (
                        SELECT 1 FROM erp_supplier_invoice_items sii
                        WHERE sii.supplier_invoice_id=si.id
                    ) OR EXISTS (
                        SELECT 1 FROM erp_supplier_invoice_items sii
                        WHERE sii.supplier_invoice_id=si.id
                          AND sii.supplier_reception_item_id IS NULL
                    ) THEN 'UNMATCHED'
                    ELSE 'MATCHED'
                END match_status
            FROM erp_supplier_invoices si
            JOIN suppliers s ON s.id=si.supplier_id AND s.user_id=si.user_id
            WHERE si.user_id=? AND si.status<>'CANCELLED'
            HAVING balance_tnd>0.0005 OR match_status<>'MATCHED'
            ORDER BY (si.due_date<CURDATE()) DESC,si.due_date ASC,si.id DESC
            LIMIT 30", 'i', [$tenantId]);
        foreach ($rawPayables as $row) {
            $balanceTnd = (float)$row['balance_tnd'];
            $matchStatus = (string)$row['match_status'];
            if ($balanceTnd <= 0.0005 && $matchStatus === 'MATCHED') continue;
            $overdue = (string)$row['due_date'] < date('Y-m-d') && $balanceTnd > 0.0005;
            $payables[] = mobileAccountingEntry(
                'PAYABLE', (int)$row['id'], $matchStatus === 'MATCHED' ? ($overdue ? 'Overdue supplier invoice' : 'Supplier invoice due') : 'Supplier invoice needs matching review',
                (string)$row['supplier_name'], (string)$row['invoice_number'], (string)$row['invoice_date'], (string)$row['due_date'],
                $overdue ? 'OVERDUE' : (string)$row['status'], $balanceTnd, 'SUPPLIER_INVOICE', (int)$row['id'], $matchStatus
            );
        }
    }

    if ($canExpenses) {
        $totals = mobileAccountingOne($conn, "SELECT COUNT(*) pending_count,ROUND(COALESCE(SUM(amount),0),3) pending_tnd
            FROM expense_notes WHERE user_id=? AND status='PENDING'", 'i', [$tenantId]);
        $summary['pendingExpenseCount'] = (int)($totals['pending_count'] ?? 0);
        $summary['pendingExpenseTnd'] = (float)($totals['pending_tnd'] ?? 0);
        $rows = mobileAccountingRows($conn, "SELECT e.id,e.title,e.category,e.amount,e.expense_date,e.status,s.name supplier_name
            FROM expense_notes e LEFT JOIN suppliers s ON s.id=e.supplier_id AND s.user_id=e.user_id
            WHERE e.user_id=? AND e.status='PENDING' ORDER BY e.expense_date ASC,e.id DESC LIMIT 30", 'i', [$tenantId]);
        foreach ($rows as $row) {
            $expenses[] = mobileAccountingEntry(
                'EXPENSE', (int)$row['id'], (string)$row['title'], (string)($row['supplier_name'] ?? $row['category']),
                (string)$row['title'], (string)$row['expense_date'], '', (string)$row['status'], (float)$row['amount'],
                'EXPENSE', (int)$row['id']
            );
        }
    }

    if ($canWithholding) {
        $totals = mobileAccountingOne($conn, "SELECT COUNT(*) pending_count,
                ROUND(COALESCE(SUM(w.withheld_amount*i.exchange_rate),0),3) pending_tnd
            FROM erp_invoice_withholdings w JOIN erp_invoices i ON i.id=w.invoice_id AND i.user_id=w.user_id
            WHERE w.user_id=? AND w.certificate_status='PENDING'", 'i', [$tenantId]);
        $summary['pendingWithholdingCount'] = (int)($totals['pending_count'] ?? 0);
        $summary['pendingWithholdingTnd'] = (float)($totals['pending_tnd'] ?? 0);
        $rows = mobileAccountingRows($conn, "SELECT w.id,w.invoice_id,w.withheld_amount*i.exchange_rate amount_tnd,
                w.expected_certificate_date activity_date,w.certificate_status,i.invoice,c.name party_name
            FROM erp_invoice_withholdings w JOIN erp_invoices i ON i.id=w.invoice_id AND i.user_id=w.user_id
            LEFT JOIN clients c ON c.id=CAST(i.custom_code AS UNSIGNED) AND c.user_id=i.user_id
            WHERE w.user_id=? AND w.certificate_status='PENDING'
            ORDER BY COALESCE(w.expected_certificate_date,DATE(w.created_at)),w.id LIMIT 15", 'i', [$tenantId]);
        foreach ($rows as $row) {
            $activity[] = mobileAccountingEntry(
                'WITHHOLDING', (int)$row['id'], 'Withholding certificate pending', (string)($row['party_name'] ?? ''),
                (string)$row['invoice'], (string)($row['activity_date'] ?? ''), '', (string)$row['certificate_status'],
                (float)$row['amount_tnd'], 'INVOICE', (int)$row['invoice_id']
            );
        }
    }

    if ($canCustomerPayments) {
        $totals = mobileAccountingOne($conn, "SELECT COUNT(*) payment_count,
                ROUND(COALESCE(SUM(COALESCE(p.amount_tnd,p.amount*i.exchange_rate)),0),3) payment_tnd
            FROM erp_invoice_payments p JOIN erp_invoices i ON i.id=p.invoice_id AND i.user_id=p.user_id
            WHERE p.user_id=? AND p.status='POSTED' AND p.payment_date>=DATE_SUB(CURDATE(),INTERVAL 30 DAY)", 'i', [$tenantId]);
        $summary['customerPaymentCount30d'] = (int)($totals['payment_count'] ?? 0);
        $summary['customerPaymentTnd30d'] = (float)($totals['payment_tnd'] ?? 0);
        $rows = mobileAccountingRows($conn, "SELECT p.id,p.invoice_id,p.payment_date,p.method,p.reference_number,
                COALESCE(p.amount_tnd,p.amount*i.exchange_rate) amount_tnd,i.invoice,c.name party_name
            FROM erp_invoice_payments p JOIN erp_invoices i ON i.id=p.invoice_id AND i.user_id=p.user_id
            LEFT JOIN clients c ON c.id=CAST(i.custom_code AS UNSIGNED) AND c.user_id=i.user_id
            WHERE p.user_id=? AND p.status='POSTED' ORDER BY p.payment_date DESC,p.id DESC LIMIT 12", 'i', [$tenantId]);
        foreach ($rows as $row) {
            $activity[] = mobileAccountingEntry(
                'CUSTOMER_PAYMENT', (int)$row['id'], 'Customer payment · ' . (string)$row['method'],
                (string)($row['party_name'] ?? ''), (string)$row['invoice'], (string)$row['payment_date'], '', 'POSTED',
                (float)$row['amount_tnd'], 'INVOICE', (int)$row['invoice_id']
            );
        }
    }

    if ($canPayables) {
        $totals = mobileAccountingOne($conn, "SELECT COUNT(*) payment_count,
                ROUND(COALESCE(SUM(COALESCE(sp.amount_tnd,sp.amount*si.exchange_rate)),0),3) payment_tnd
            FROM erp_supplier_payments sp JOIN erp_supplier_invoices si ON si.id=sp.supplier_invoice_id AND si.user_id=sp.user_id
            WHERE sp.user_id=? AND sp.voided_at IS NULL AND sp.payment_date>=DATE_SUB(CURDATE(),INTERVAL 30 DAY)", 'i', [$tenantId]);
        $summary['supplierPaymentCount30d'] = (int)($totals['payment_count'] ?? 0);
        $summary['supplierPaymentTnd30d'] = (float)($totals['payment_tnd'] ?? 0);
        $rows = mobileAccountingRows($conn, "SELECT sp.id,sp.supplier_invoice_id,sp.payment_date,sp.method,
                COALESCE(sp.amount_tnd,sp.amount*si.exchange_rate) amount_tnd,si.invoice_number,s.name supplier_name
            FROM erp_supplier_payments sp JOIN erp_supplier_invoices si ON si.id=sp.supplier_invoice_id AND si.user_id=sp.user_id
            JOIN suppliers s ON s.id=si.supplier_id AND s.user_id=si.user_id
            WHERE sp.user_id=? AND sp.voided_at IS NULL ORDER BY sp.payment_date DESC,sp.id DESC LIMIT 12", 'i', [$tenantId]);
        foreach ($rows as $row) {
            $activity[] = mobileAccountingEntry(
                'SUPPLIER_PAYMENT', (int)$row['id'], 'Supplier payment · ' . (string)$row['method'],
                (string)$row['supplier_name'], (string)$row['invoice_number'], (string)$row['payment_date'], '', 'POSTED',
                (float)$row['amount_tnd'], 'SUPPLIER_INVOICE', (int)$row['supplier_invoice_id']
            );
        }

        $supplierCreditTotals = mobileAccountingOne($conn, "SELECT COUNT(*) credit_count
            FROM erp_supplier_credit_notes sc
            WHERE sc.user_id=? AND sc.status='VALIDATED' AND sc.credit_date>=DATE_SUB(CURDATE(),INTERVAL 30 DAY)", 'i', [$tenantId]);
        $summary['supplierCreditCount30d'] = (int)($supplierCreditTotals['credit_count'] ?? 0);
        $supplierCredits = mobileAccountingRows($conn, "SELECT sc.id,sc.supplier_invoice_id,sc.credit_number,sc.credit_date,
                sc.amount*si.exchange_rate amount_tnd,si.invoice_number,s.name supplier_name
            FROM erp_supplier_credit_notes sc JOIN erp_supplier_invoices si ON si.id=sc.supplier_invoice_id AND si.user_id=sc.user_id
            JOIN suppliers s ON s.id=si.supplier_id AND s.user_id=si.user_id
            WHERE sc.user_id=? AND sc.status='VALIDATED' AND sc.credit_date>=DATE_SUB(CURDATE(),INTERVAL 30 DAY)
            ORDER BY sc.credit_date DESC,sc.id DESC LIMIT 12", 'i', [$tenantId]);
        foreach ($supplierCredits as $row) {
            $activity[] = mobileAccountingEntry(
                'SUPPLIER_CREDIT', (int)$row['id'], 'Supplier credit · ' . (string)$row['credit_number'],
                (string)$row['supplier_name'], (string)$row['invoice_number'], (string)$row['credit_date'], '', 'VALIDATED',
                (float)$row['amount_tnd'], 'SUPPLIER_INVOICE', (int)$row['supplier_invoice_id']
            );
        }
    }

    if ($canCustomerCredits) {
        $customerCreditTotals = mobileAccountingOne($conn, "SELECT COUNT(*) credit_count
            FROM erp_invoices cr WHERE cr.user_id=? AND cr.invoice_type='AVOIR' AND cr.is_validated=1
              AND UPPER(cr.status)<>'CANCELLED' AND cr.invoice_date>=DATE_SUB(CURDATE(),INTERVAL 30 DAY)", 'i', [$tenantId]);
        $summary['customerCreditCount30d'] = (int)($customerCreditTotals['credit_count'] ?? 0);
        $rows = mobileAccountingRows($conn, "SELECT cr.id,cr.invoice,cr.invoice_date,ABS(cr.total_tnd) amount_tnd,
                cr.status,c.name party_name
            FROM erp_invoices cr LEFT JOIN clients c ON c.id=CAST(cr.custom_code AS UNSIGNED) AND c.user_id=cr.user_id
            WHERE cr.user_id=? AND cr.invoice_type='AVOIR' AND cr.is_validated=1 AND UPPER(cr.status)<>'CANCELLED'
              AND cr.invoice_date>=DATE_SUB(CURDATE(),INTERVAL 30 DAY)
            ORDER BY cr.invoice_date DESC,cr.id DESC LIMIT 12", 'i', [$tenantId]);
        foreach ($rows as $row) {
            $activity[] = mobileAccountingEntry(
                'CUSTOMER_CREDIT', (int)$row['id'], 'Customer credit note', (string)($row['party_name'] ?? ''),
                (string)$row['invoice'], (string)$row['invoice_date'], '', (string)$row['status'], (float)$row['amount_tnd'],
                'CREDIT_NOTE', (int)$row['id']
            );
        }
    }

    if ($canSupplierReturns) {
        $supplierReturnTotals = mobileAccountingOne($conn, "SELECT COUNT(*) return_count
            FROM erp_supplier_returns r WHERE r.user_id=? AND r.status='CONFIRMED'
              AND r.return_date>=DATE_SUB(CURDATE(),INTERVAL 30 DAY)", 'i', [$tenantId]);
        $summary['supplierReturnCount30d'] = (int)($supplierReturnTotals['return_count'] ?? 0);
        $rows = mobileAccountingRows($conn, "SELECT r.id,r.supplier_reception_id,r.return_date,r.status,r.reason,s.name supplier_name,
                ROUND(COALESCE(SUM(ri.quantity*ri.unit_cost),0),3) amount_tnd
            FROM erp_supplier_returns r JOIN suppliers s ON s.id=r.supplier_id AND s.user_id=r.user_id
            JOIN erp_supplier_return_items ri ON ri.supplier_return_id=r.id
            WHERE r.user_id=? AND r.status='CONFIRMED' AND r.return_date>=DATE_SUB(CURDATE(),INTERVAL 30 DAY)
            GROUP BY r.id,r.supplier_reception_id,r.return_date,r.status,r.reason,s.name
            ORDER BY r.return_date DESC,r.id DESC LIMIT 12", 'i', [$tenantId]);
        foreach ($rows as $row) {
            $activity[] = mobileAccountingEntry(
                'SUPPLIER_RETURN', (int)$row['id'], 'Supplier return · ' . (string)$row['reason'],
                (string)$row['supplier_name'], '#' . (int)$row['supplier_reception_id'], (string)$row['return_date'], '',
                (string)$row['status'], (float)$row['amount_tnd'], 'SUPPLIER_RECEPTION', (int)$row['supplier_reception_id']
            );
        }
    }

    usort($activity, static fn(array $a, array $b): int => strcmp((string)$b['date'], (string)$a['date']));
    $activity = array_slice($activity, 0, 30);

    jsonResponse([
        'success'=>true,
        'generatedAt'=>date(DATE_ATOM),
        'currency'=>'TND',
        'capabilities'=>[
            'receivables'=>$canReceivables,
            'customerPayments'=>$canCustomerPayments,
            'withholding'=>$canWithholding,
            'payables'=>$canPayables,
            'expenses'=>$canExpenses,
            'expenseApproval'=>userHasPermission($conn, $actorId, 'expenses.approve'),
            'supplierPayments'=>userHasPermission($conn, $actorId, 'supplierPayments.record'),
            'supplierCredits'=>userHasPermission($conn, $actorId, 'supplierInvoices.credit'),
            'supplierReturns'=>userHasPermission($conn, $actorId, 'supplierReturns.confirm'),
            'reports'=>userHasPermission($conn, $actorId, 'reports.view'),
        ],
        'summary'=>$summary,
        'receivables'=>$receivables,
        'payables'=>$payables,
        'expenses'=>$expenses,
        'activity'=>$activity,
    ]);
} catch (Throwable $error) {
    structuredLog('ERROR', 'ACCOUNTING.MOBILE_REVIEW_FAILED', [
        'exception'=>get_class($error),
        'message'=>$error->getMessage(),
    ]);
    jsonResponse([
        'success'=>false,
        'message'=>'Could not load the accounting review workspace.',
        'error_code'=>'ACCOUNTING_MOBILE_REVIEW_FAILED',
    ], 500);
}
