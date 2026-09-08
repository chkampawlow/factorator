<?php

header('Content-Type: application/json');

require_once __DIR__ . '/../config/response.php';
require_once __DIR__ . '/../config/db.php';
require_once __DIR__ . '/../auth/auth_required.php';
require_once __DIR__ . '/../auth/role_helper.php';
require_once __DIR__ . '/../config/field_projection.php';

try {
    $userId = (int)requireAuth()->id;
    $conn = db();
    $visibleDocumentTypes = requireAnyInvoiceDocumentView($conn, $userId);

    $where = [
        'i.user_id=?',
        'UPPER(i.invoice_type) IN (' . implode(',', array_fill(0, count($visibleDocumentTypes), '?')) . ')',
    ];
    $types = 'i' . str_repeat('s', count($visibleDocumentTypes));
    $args = [$userId, ...$visibleDocumentTypes];

    foreach (['sales_order_id', 'delivery_note_id', 'source_invoice_id'] as $field) {
        $value = (int)($_GET[$field] ?? 0);
        if ($value > 0) {
            $where[] = "i.$field=?";
            $types .= 'i';
            $args[] = $value;
        }
    }

    $documentType = strtoupper(trim((string)($_GET['invoice_type'] ?? '')));
    if ($documentType !== '') {
        requireInvoiceDocumentPermission($conn, $userId, $documentType, 'view');
        $where[] = 'UPPER(i.invoice_type)=?';
        $types .= 's';
        $args[] = $documentType;
    }

    $notes = trim((string)($_GET['notes_contains'] ?? ''));
    if ($notes !== '') {
        $where[] = 'i.notes LIKE ?';
        $types .= 's';
        $args[] = '%' . $notes . '%';
    }
    $search = trim((string)($_GET['search'] ?? ''));
    if ($search !== '') {
        $where[] = "CONCAT_WS(' ',i.invoice,i.custom_email,i.status) LIKE ?";
        $types .= 's';
        $args[] = '%' . $search . '%';
    }
    $excludeId = (int)($_GET['exclude_id'] ?? 0);
    if ($excludeId > 0) {
        $where[] = 'i.id<>?';
        $types .= 'i';
        $args[] = $excludeId;
    }

    $limit = min(100, max(1, (int)($_GET['limit'] ?? 50)));
    $types .= 'i';
    $args[] = $limit;
    $sql = "SELECT i.id,i.invoice,i.invoice_date,i.invoice_due_date,i.invoice_type,
                   i.status,i.is_validated,i.sales_order_id,i.delivery_note_id,
                   i.source_invoice_id,i.notes,i.total
            FROM erp_invoices i
            WHERE " . implode(' AND ', $where) . '
            ORDER BY i.id DESC LIMIT ?';
    $stmt = $conn->prepare($sql);
    $stmt->bind_param($types, ...$args);
    $stmt->execute();
    $rows = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);
    $stmt->close();
    $role = currentUserRole($conn, $userId);
    $rows = projectRows($rows, static fn(array $row): array => projectInvoiceFields($row, $role));
    jsonResponse(['success' => true, 'data' => $rows]);
} catch (Throwable $e) {
    jsonResponse([
        'success' => false,
        'message' => 'Could not load document options.',
        'error_code' => 'INVOICE_OPTIONS_FAILED',
    ], resourceExceptionStatus($e));
}
