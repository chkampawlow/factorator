<?php

header('Content-Type: application/json');

require_once __DIR__ . '/../config/response.php';
require_once __DIR__ . '/../config/db.php';
require_once __DIR__ . '/../config/pagination.php';
require_once __DIR__ . '/../auth/auth_required.php';
require_once __DIR__ . '/../auth/role_helper.php';
require_once __DIR__ . '/../config/field_projection.php';

try {
    $userId = (int)requireAuth()->id;
    $conn = db();
    $visibleDocumentTypes = requireAnyInvoiceDocumentView($conn, $userId);

    [$page, $pageSize, $offset] = paginationInput($_GET);
    $search = trim((string)($_GET['search'] ?? ''));
    $documentType = strtoupper(trim((string)($_GET['invoice_type'] ?? '')));
    $status = strtoupper(trim((string)($_GET['status'] ?? '')));
    $from = trim((string)($_GET['date_from'] ?? ''));
    $to = trim((string)($_GET['date_to'] ?? ''));
    $where = ['i.user_id=?', 'UPPER(i.invoice_type) IN (' . implode(',', array_fill(0, count($visibleDocumentTypes), '?')) . ')'];
    $types = 'i' . str_repeat('s', count($visibleDocumentTypes));
    $args = [$userId, ...$visibleDocumentTypes];

    if ($search !== '') {
        $where[] = "CONCAT_WS(' ',i.invoice,c.name,c.email,i.salesperson_name,i.status) LIKE ?";
        $types .= 's';
        $args[] = '%' . $search . '%';
    }
    if ($documentType === 'INVOICE') {
        requirePermission($conn, $userId, 'invoices.view');
        $where[] = "UPPER(i.invoice_type) NOT IN('DEVIS','AVOIR')";
    } elseif (in_array($documentType, ['DEVIS', 'AVOIR'], true)) {
        requireInvoiceDocumentPermission($conn, $userId, $documentType, 'view');
        $where[] = 'UPPER(i.invoice_type)=?';
        $types .= 's';
        $args[] = $documentType;
    }

    if ($status !== '') {
        if ($documentType === 'INVOICE' && $status === 'DRAFT') {
            $where[] = "UPPER(i.status)<>'CANCELLED' AND (i.is_validated=0 OR UPPER(i.invoice_type)='DRAFT' OR UPPER(i.status)='DRAFT')";
        } elseif ($documentType === 'INVOICE' && $status === 'OVERDUE') {
            $where[] = "i.is_validated=1 AND UPPER(i.invoice_type)='FACTURE' AND UPPER(i.status) NOT IN('PAID','PAYED','PAID_IN_FULL','CANCELLED') AND i.invoice_due_date<CURDATE()";
        } elseif ($documentType === 'INVOICE' && $status === 'UNPAID') {
            $where[] = "i.is_validated=1 AND UPPER(i.invoice_type)='FACTURE' AND UPPER(i.status) NOT IN('PAID','PAYED','PAID_IN_FULL','CANCELLED') AND i.invoice_due_date>=CURDATE()";
        } elseif ($documentType === 'AVOIR' && $status === 'DRAFT') {
            $where[] = "i.is_validated=0 AND UPPER(i.status)<>'CANCELLED'";
        } elseif ($documentType === 'AVOIR' && $status === 'AVOIR') {
            $where[] = "i.is_validated=1 AND UPPER(i.status)<>'CANCELLED'";
        } else {
            $where[] = 'UPPER(i.status)=?';
            $types .= 's';
            $args[] = $status;
        }
    }
    if ($from !== '') {
        $where[] = 'i.invoice_date>=?';
        $types .= 's';
        $args[] = $from;
    }
    if ($to !== '') {
        $where[] = 'i.invoice_date<=?';
        $types .= 's';
        $args[] = $to;
    }

    $whereSql = implode(' AND ', $where);
    $joins = " FROM erp_invoices i
        LEFT JOIN clients c ON c.id=CAST(i.custom_code AS UNSIGNED) AND c.user_id=i.user_id";
    $aggregateStmt = $conn->prepare("SELECT COUNT(*) total,ROUND(COALESCE(SUM(i.total_tnd),0),3) amount $joins WHERE $whereSql");
    $aggregateStmt->bind_param($types, ...$args);
    $aggregateStmt->execute();
    $pageAggregates = $aggregateStmt->get_result()->fetch_assoc() ?: [];
    $aggregateStmt->close();

    $workflowStmt = $conn->prepare("SELECT
        COALESCE(SUM(invoice_type='DEVIS' AND status='DRAFT'),0) devis_drafts,
        COALESCE(SUM(invoice_type='DEVIS' AND status='SENT'),0) devis_sent,
        COALESCE(SUM(invoice_type='DEVIS' AND status='ACCEPTED' AND transformation_status NOT IN('FULLY_ORDERED','FULLY_TRANSFORMED')),0) devis_ready,
        COALESCE(SUM(invoice_type='AVOIR' AND is_validated=0 AND status<>'CANCELLED'),0) credit_drafts,
        COALESCE(SUM(invoice_type='AVOIR' AND is_validated=1 AND status<>'CANCELLED'),0) credit_validated,
        COALESCE(SUM(invoice_type='AVOIR' AND status='CANCELLED'),0) credit_cancelled,
        COALESCE(SUM(invoice_type NOT IN('DEVIS','AVOIR') AND status<>'CANCELLED' AND (is_validated=0 OR invoice_type='DRAFT' OR status='DRAFT')),0) invoice_drafts,
        COALESCE(SUM(UPPER(invoice_type)='FACTURE' AND is_validated=1 AND UPPER(status) NOT IN('PAID','PAYED','PAID_IN_FULL','CANCELLED') AND invoice_due_date<CURDATE()),0) invoice_overdue,
        COALESCE(SUM(UPPER(invoice_type)='FACTURE' AND is_validated=1 AND UPPER(status) NOT IN('PAID','PAYED','PAID_IN_FULL','CANCELLED') AND invoice_due_date>=CURDATE()),0) invoice_unpaid
        FROM erp_invoices WHERE user_id=? AND UPPER(invoice_type) IN (" . implode(',', array_fill(0, count($visibleDocumentTypes), '?')) . ")");
    $workflowTypes = 'i' . str_repeat('s', count($visibleDocumentTypes));
    $workflowArgs = [$userId, ...$visibleDocumentTypes];
    $workflowStmt->bind_param($workflowTypes, ...$workflowArgs);
    $workflowStmt->execute();
    $workflowAggregates = $workflowStmt->get_result()->fetch_assoc() ?: [];
    $workflowStmt->close();
    foreach ($workflowAggregates as $key => $value) $workflowAggregates[$key] = (int)$value;

    $order = paginationSort($_GET, [
        'number' => 'i.invoice',
        'date' => 'i.invoice_date',
        'due' => 'i.invoice_due_date',
        'total' => 'i.total_tnd',
        'created' => 'i.id',
    ], 'created');
    $sql = "SELECT i.id,i.invoice,i.custom_email,i.custom_code,i.salesperson_name,
            i.sales_order_id,i.delivery_note_id,i.source_invoice_id,i.source_flow,
            c.name client_name,c.email client_email,i.invoice_date,i.invoice_due_date,
            i.subtotal,i.montant_tva,i.total,i.total_tnd,i.currency,i.exchange_rate,
            i.notes,i.invoice_type,i.status,i.transformation_status,i.is_validated,
            i.payment_method,i.timbre
        $joins WHERE $whereSql ORDER BY $order LIMIT ? OFFSET ?";
    $stmt = $conn->prepare($sql);
    $queryTypes = $types . 'ii';
    $queryArgs = [...$args, $pageSize, $offset];
    $stmt->bind_param($queryTypes, ...$queryArgs);
    $stmt->execute();
    $rows = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);
    $stmt->close();
    $role = currentUserRole($conn, $userId);
    $rows = projectRows($rows, static fn(array $row): array => projectInvoiceFields($row, $role));

    $total = (int)($pageAggregates['total'] ?? 0);
    $aggregates = ['amount' => (string)($pageAggregates['amount'] ?? '0.000')] + $workflowAggregates;
    paginatedResponse($rows, $page, $pageSize, $total, $aggregates);
} catch (Throwable $e) {
    jsonResponse(['success' => false, 'message' => 'Could not load documents.', 'error_code' => 'INVOICE_LIST_FAILED'], 500);
}
