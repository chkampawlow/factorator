<?php

declare(strict_types=1);

final class NotificationReadStateUnavailable extends RuntimeException
{
}

function notificationReadStateAvailable(mysqli $conn): bool
{
    static $availability = [];
    $connectionId = spl_object_id($conn);
    if (array_key_exists($connectionId, $availability)) {
        return $availability[$connectionId];
    }

    $table = 'erp_notification_reads';
    $stmt = $conn->prepare("SELECT COUNT(*) total
        FROM information_schema.tables
        WHERE table_schema=DATABASE() AND table_name=?");
    $stmt->bind_param('s', $table);
    $stmt->execute();
    $available = (int)($stmt->get_result()->fetch_assoc()['total'] ?? 0) > 0;
    $stmt->close();
    $availability[$connectionId] = $available;

    if (!$available) {
        structuredLog('WARNING', 'NOTIFICATION.READ_STATE_SCHEMA_MISSING', [
            'missing_table' => $table,
            'required_migration' => '2026-09-05-notification-read-state.sql',
        ]);
    }

    return $available;
}

function notificationRows(mysqli $conn, string $sql, string $types, array $args): array
{
    $stmt = $conn->prepare($sql);
    if (!$stmt) throw new RuntimeException('Could not prepare notification query.');
    if ($types !== '') $stmt->bind_param($types, ...$args);
    $stmt->execute();
    $rows = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);
    $stmt->close();
    return $rows;
}

function notificationItem(
    string $key,
    string $type,
    string $category,
    string $title,
    string $body,
    string $severity,
    string $occurredAt,
    string $entityType,
    int $entityId,
    string $entityNumber,
    string $status,
    array $filters = []
): array {
    return [
        'key' => mb_substr($key, 0, 191),
        'type' => $type,
        'category' => $category,
        'title' => $title,
        'body' => $body,
        'severity' => in_array($severity, ['INFO', 'WARNING', 'CRITICAL'], true) ? $severity : 'INFO',
        'occurredAt' => $occurredAt,
        'entityType' => $entityType,
        'entityId' => $entityId,
        'entityNumber' => $entityNumber,
        'status' => $status,
        'filters' => (object)$filters,
        'isRead' => false,
        'readAt' => '',
    ];
}

function currentOperationalNotifications(mysqli $conn, int $tenantId, int $actorId): array
{
    $items = [];
    $now = date('Y-m-d H:i:s');

    if (userHasPermission($conn, $actorId, 'invoices.view')) {
        $rows = notificationRows($conn, "SELECT i.id,i.invoice,i.invoice_due_date,i.status,i.total,c.name client_name
            FROM erp_invoices i
            LEFT JOIN clients c ON c.id=CAST(i.custom_code AS UNSIGNED) AND c.user_id=i.user_id
            WHERE i.user_id=? AND UPPER(i.invoice_type)='FACTURE' AND i.is_validated=1
              AND UPPER(i.status) NOT IN('PAID','PAYED','PAID_IN_FULL','CANCELLED')
              AND i.invoice_due_date<CURDATE()
            ORDER BY i.invoice_due_date ASC,i.id DESC LIMIT 30", 'i', [$tenantId]);
        foreach ($rows as $row) {
            $days = max(1, (int)((time() - strtotime((string)$row['invoice_due_date'])) / 86400));
            $number = (string)$row['invoice'];
            $party = trim((string)($row['client_name'] ?? ''));
            $items[] = notificationItem(
                'OVERDUE_INVOICE:' . (int)$row['id'], 'OVERDUE_INVOICE', 'SALES',
                "Invoice $number is overdue",
                ($party !== '' ? "$party · " : '') . "$days day" . ($days === 1 ? '' : 's') . ' overdue',
                $days >= 30 ? 'CRITICAL' : 'WARNING', (string)$row['invoice_due_date'],
                'INVOICE', (int)$row['id'], $number, (string)$row['status'], ['status' => 'OVERDUE']
            );
        }
    }

    if (userHasPermission($conn, $actorId, 'devis.view')) {
        $rows = notificationRows($conn, "SELECT i.id,i.invoice,i.invoice_date,i.status,c.name client_name
            FROM erp_invoices i
            LEFT JOIN clients c ON c.id=CAST(i.custom_code AS UNSIGNED) AND c.user_id=i.user_id
            WHERE i.user_id=? AND UPPER(i.invoice_type)='DEVIS' AND UPPER(i.status)='SENT'
              AND i.invoice_date<=DATE_SUB(CURDATE(),INTERVAL 7 DAY)
            ORDER BY i.invoice_date ASC,i.id DESC LIMIT 20", 'i', [$tenantId]);
        foreach ($rows as $row) {
            $number = (string)$row['invoice'];
            $party = trim((string)($row['client_name'] ?? ''));
            $items[] = notificationItem(
                'QUOTATION_FOLLOWUP:' . (int)$row['id'], 'QUOTATION_FOLLOWUP', 'SALES',
                "Follow up quotation $number", $party !== '' ? $party : 'Quotation sent more than 7 days ago',
                'INFO', (string)$row['invoice_date'], 'QUOTATION', (int)$row['id'], $number,
                (string)$row['status'], ['status' => 'SENT']
            );
        }
    }

    if (userHasPermission($conn, $actorId, 'orders.view')) {
        $rows = notificationRows($conn, "SELECT so.id,so.order_number,so.status,so.updated_at,c.name client_name
            FROM erp_sales_orders so
            LEFT JOIN clients c ON c.id=so.client_id AND c.user_id=so.user_id
            WHERE so.user_id=? AND so.status='CONFIRMED'
            ORDER BY so.updated_at DESC,so.id DESC LIMIT 20", 'i', [$tenantId]);
        foreach ($rows as $row) {
            $number = (string)$row['order_number'];
            $items[] = notificationItem(
                'ORDER_READY:' . (int)$row['id'], 'ORDER_READY', 'SALES',
                "Sales order $number is ready", trim((string)($row['client_name'] ?? '')),
                'INFO', (string)$row['updated_at'], 'SALES_ORDER', (int)$row['id'], $number,
                (string)$row['status'], ['status' => 'CONFIRMED']
            );
        }
    }

    if (userHasPermission($conn, $actorId, 'products.view') || userHasPermission($conn, $actorId, 'stock.view')) {
        $rows = notificationRows($conn, "SELECT id,code,name,stock_quantity,reorder_point
            FROM products WHERE user_id=? AND item_type='PRODUCT' AND reorder_point>0
              AND stock_quantity<=reorder_point ORDER BY (stock_quantity<=0) DESC,stock_quantity ASC,id DESC LIMIT 30", 'i', [$tenantId]);
        foreach ($rows as $row) {
            $id = (int)$row['id'];
            $stock = round((float)$row['stock_quantity'], 3);
            $reorder = round((float)$row['reorder_point'], 3);
            $items[] = notificationItem(
                "LOW_STOCK:$id:$stock:$reorder", 'LOW_STOCK', 'STOCK',
                (string)$row['name'] . ($stock <= 0 ? ' is out of stock' : ' is below reorder point'),
                "Available $stock · Reorder point $reorder", $stock <= 0 ? 'CRITICAL' : 'WARNING',
                $now, 'PRODUCT', $id, (string)($row['code'] ?? ''), 'LOW', ['attention' => 'low']
            );
        }

        $rows = notificationRows($conn, "SELECT id,code,name FROM products
            WHERE user_id=? AND item_type='PRODUCT' AND selling_price_required=1
            ORDER BY id DESC LIMIT 30", 'i', [$tenantId]);
        foreach ($rows as $row) {
            $id = (int)$row['id'];
            $items[] = notificationItem(
                "PRODUCT_PRICING:$id", 'PRODUCT_PRICING', 'STOCK',
                (string)$row['name'] . ' needs a selling price', 'Complete pricing before this item is sold.',
                'WARNING', $now, 'PRODUCT', $id, (string)($row['code'] ?? ''), 'PRICING_REQUIRED',
                ['attention' => 'pricing']
            );
        }
    }

    if (userHasPermission($conn, $actorId, 'deliveries.view')) {
        $rows = notificationRows($conn, "SELECT dn.id,dn.delivery_number,dn.status,dn.delivery_date,dn.updated_at,c.name client_name
            FROM erp_delivery_notes dn
            LEFT JOIN clients c ON c.id=dn.client_id AND c.user_id=dn.user_id
            WHERE dn.user_id=? AND dn.document_type='DELIVERY' AND dn.status IN('DRAFT','CONFIRMED')
            ORDER BY dn.delivery_date ASC,dn.id DESC LIMIT 30", 'i', [$tenantId]);
        foreach ($rows as $row) {
            $number = (string)$row['delivery_number'];
            $status = (string)$row['status'];
            $items[] = notificationItem(
                'DELIVERY_PENDING:' . (int)$row['id'] . ':' . $status, 'DELIVERY_PENDING', 'LOGISTICS',
                $status === 'DRAFT' ? "Delivery $number needs confirmation" : "Delivery $number is ready to dispatch",
                trim((string)($row['client_name'] ?? '')), $status === 'DRAFT' ? 'WARNING' : 'INFO',
                (string)($row['updated_at'] ?? $row['delivery_date']), 'DELIVERY_NOTE', (int)$row['id'], $number,
                $status, ['status' => $status]
            );
        }
    }

    if (userHasPermission($conn, $actorId, 'supplierOrders.view')) {
        $rows = notificationRows($conn, "SELECT so.id,so.order_number,so.expected_date,so.status,so.created_at,s.name supplier_name
            FROM erp_supplier_orders so JOIN suppliers s ON s.id=so.supplier_id AND s.user_id=so.user_id
            WHERE so.user_id=? AND so.status IN('SENT','PARTIALLY_RECEIVED')
              AND (so.expected_date IS NULL OR so.expected_date<=DATE_ADD(CURDATE(),INTERVAL 7 DAY))
            ORDER BY COALESCE(so.expected_date,DATE(so.created_at)) ASC,so.id DESC LIMIT 30", 'i', [$tenantId]);
        foreach ($rows as $row) {
            $number = (string)$row['order_number'];
            $expected = trim((string)($row['expected_date'] ?? ''));
            $overdue = $expected !== '' && $expected < date('Y-m-d');
            $items[] = notificationItem(
                'SUPPLIER_ORDER_EXPECTED:' . (int)$row['id'] . ':' . (string)$row['status'],
                'SUPPLIER_ORDER_EXPECTED', 'PURCHASING',
                $overdue ? "Supplier order $number is late" : "Supplier order $number is expected soon",
                trim((string)$row['supplier_name']) . ($expected !== '' ? " · $expected" : ''),
                $overdue ? 'WARNING' : 'INFO', $expected !== '' ? $expected : (string)$row['created_at'],
                'SUPPLIER_ORDER', (int)$row['id'], $number, (string)$row['status'], []
            );
        }
    }

    if (userHasPermission($conn, $actorId, 'supplierReceptions.view')) {
        $rows = notificationRows($conn, "SELECT sr.id,sr.invoice_number,sr.supplier_delivery_note_number,sr.status,
                sr.exception_type,sr.received_date,sr.created_at,s.name supplier_name,
                EXISTS(SELECT 1 FROM erp_supplier_reception_items sri WHERE sri.supplier_reception_id=sr.id AND (sri.damaged_qty>0 OR sri.rejected_qty>0)) has_line_discrepancy
            FROM erp_supplier_receptions sr JOIN suppliers s ON s.id=sr.supplier_id AND s.user_id=sr.user_id
            WHERE sr.user_id=? AND (sr.status='DRAFT' OR sr.exception_type<>'NONE'
                OR EXISTS(SELECT 1 FROM erp_supplier_reception_items sri WHERE sri.supplier_reception_id=sr.id AND (sri.damaged_qty>0 OR sri.rejected_qty>0)))
            ORDER BY sr.id DESC LIMIT 30", 'i', [$tenantId]);
        foreach ($rows as $row) {
            $number = trim((string)($row['supplier_delivery_note_number'] ?? '')) ?: trim((string)($row['invoice_number'] ?? '')) ?: '#' . (int)$row['id'];
            $discrepancy = (string)$row['exception_type'] !== 'NONE' || (int)$row['has_line_discrepancy'] === 1;
            $type = $discrepancy ? 'RECEPTION_DISCREPANCY' : 'RECEPTION_PENDING';
            $items[] = notificationItem(
                $type . ':' . (int)$row['id'] . ':' . (string)$row['status'], $type, 'LOGISTICS',
                $discrepancy ? "Reception $number has a discrepancy" : "Reception $number needs confirmation",
                trim((string)$row['supplier_name']), $discrepancy ? 'WARNING' : 'INFO',
                (string)($row['received_date'] ?? $row['created_at']), 'SUPPLIER_RECEPTION', (int)$row['id'], $number,
                (string)$row['status'], ['status' => (string)$row['status']]
            );
        }
    }

    if (userHasPermission($conn, $actorId, 'expenses.view')) {
        $rows = notificationRows($conn, "SELECT id,title,category,amount,status,expense_date,created_at
            FROM expense_notes WHERE user_id=? AND status='PENDING'
            ORDER BY expense_date ASC,id DESC LIMIT 30", 'i', [$tenantId]);
        foreach ($rows as $row) {
            $items[] = notificationItem(
                'EXPENSE_REVIEW:' . (int)$row['id'], 'EXPENSE_REVIEW', 'ACCOUNTING',
                'Expense awaiting review: ' . (string)$row['title'],
                (string)$row['category'] . ' · ' . number_format((float)$row['amount'], 3, '.', ' ') . ' TND',
                'WARNING', (string)($row['expense_date'] ?? $row['created_at']), 'EXPENSE', (int)$row['id'],
                (string)$row['title'], (string)$row['status'], ['status' => 'PENDING']
            );
        }
    }

    if (userHasPermission($conn, $actorId, 'supplierInvoices.view')) {
        $rows = notificationRows($conn, "SELECT si.id,si.invoice_number,si.due_date,si.status,si.total_ttc,si.created_at,s.name supplier_name
            FROM erp_supplier_invoices si JOIN suppliers s ON s.id=si.supplier_id AND s.user_id=si.user_id
            WHERE si.user_id=? AND si.status IN('VALIDATED','PARTIALLY_PAID')
              AND si.due_date<=DATE_ADD(CURDATE(),INTERVAL 7 DAY)
            ORDER BY si.due_date ASC,si.id DESC LIMIT 30", 'i', [$tenantId]);
        foreach ($rows as $row) {
            $number = (string)$row['invoice_number'];
            $overdue = (string)$row['due_date'] < date('Y-m-d');
            $items[] = notificationItem(
                'SUPPLIER_INVOICE_DUE:' . (int)$row['id'] . ':' . (string)$row['status'],
                'SUPPLIER_INVOICE_DUE', 'ACCOUNTING',
                $overdue ? "Supplier invoice $number is overdue" : "Supplier invoice $number is due soon",
                trim((string)$row['supplier_name']) . ' · ' . number_format((float)$row['total_ttc'], 3, '.', ' ') . ' TND',
                $overdue ? 'CRITICAL' : 'WARNING', (string)$row['due_date'], 'SUPPLIER_INVOICE', (int)$row['id'],
                $number, (string)$row['status'], []
            );
        }
    }

    $priority = ['CRITICAL' => 0, 'WARNING' => 1, 'INFO' => 2];
    usort($items, static function (array $a, array $b) use ($priority): int {
        $severity = ($priority[$a['severity']] ?? 9) <=> ($priority[$b['severity']] ?? 9);
        if ($severity !== 0) return $severity;
        return strcmp((string)$b['occurredAt'], (string)$a['occurredAt']);
    });
    return $items;
}

function attachNotificationReadState(mysqli $conn, int $tenantId, int $actorId, array $items): array
{
    if (!$items) return [];
    if (!notificationReadStateAvailable($conn)) return $items;
    $keys = array_values(array_unique(array_column($items, 'key')));
    $placeholders = implode(',', array_fill(0, count($keys), '?'));
    $types = 'ii' . str_repeat('s', count($keys));
    $args = [$tenantId, $actorId, ...$keys];
    $rows = notificationRows($conn, "SELECT notification_key,read_at FROM erp_notification_reads
        WHERE tenant_id=? AND actor_id=? AND notification_key IN($placeholders)", $types, $args);
    $read = [];
    foreach ($rows as $row) $read[(string)$row['notification_key']] = (string)$row['read_at'];
    foreach ($items as &$item) {
        $item['isRead'] = isset($read[$item['key']]);
        $item['readAt'] = $read[$item['key']] ?? '';
    }
    unset($item);
    return $items;
}

function setNotificationReadState(mysqli $conn, int $tenantId, int $actorId, array $keys, bool $read): int
{
    $keys = array_values(array_unique(array_filter(array_map(static fn($key): string => mb_substr(trim((string)$key), 0, 191), $keys))));
    if (!$keys) return 0;
    if (!notificationReadStateAvailable($conn)) {
        throw new NotificationReadStateUnavailable('Notification read-state migration is pending.');
    }
    if ($read) {
        $stmt = $conn->prepare('INSERT INTO erp_notification_reads (tenant_id,actor_id,notification_key,read_at)
            VALUES (?,?,?,NOW()) ON DUPLICATE KEY UPDATE read_at=NOW(),updated_at=NOW()');
        foreach ($keys as $key) {
            $stmt->bind_param('iis', $tenantId, $actorId, $key);
            $stmt->execute();
        }
        $stmt->close();
        return count($keys);
    }
    $placeholders = implode(',', array_fill(0, count($keys), '?'));
    $types = 'ii' . str_repeat('s', count($keys));
    $args = [$tenantId, $actorId, ...$keys];
    $stmt = $conn->prepare("DELETE FROM erp_notification_reads WHERE tenant_id=? AND actor_id=? AND notification_key IN($placeholders)");
    $stmt->bind_param($types, ...$args);
    $stmt->execute();
    $count = $stmt->affected_rows;
    $stmt->close();
    return $count;
}
