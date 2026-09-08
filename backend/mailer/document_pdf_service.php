<?php

declare(strict_types=1);

require_once __DIR__ . '/../vendor/autoload.php';
require_once __DIR__ . '/../invoices/issuance_snapshot_service.php';

use Dompdf\Dompdf;
use Dompdf\Options;

function documentPdfEscape(mixed $value): string
{
    return htmlspecialchars((string)($value ?? ''), ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
}

function documentPdfNumber(mixed $value): string
{
    return number_format((float)($value ?? 0), 3, '.', ' ');
}

function documentPdfCopy(string $language): array
{
    return match ($language) {
        'en' => [
            'date' => 'Date', 'due' => 'Due date', 'expected' => 'Expected date',
            'status' => 'Status', 'party' => 'Customer / Supplier', 'fiscal' => 'Fiscal ID',
            'address' => 'Address', 'email' => 'Email', 'code' => 'Code',
            'description' => 'Description', 'qty' => 'Quantity', 'unit_price' => 'Unit price',
            'discount' => 'Discount', 'vat' => 'VAT', 'total' => 'Total',
            'subtotal' => 'Subtotal', 'tax_total' => 'VAT total', 'stamp' => 'Stamp duty',
            'notes' => 'Notes', 'currency' => 'Currency', 'invoice' => 'Invoice',
            'devis' => 'Quotation', 'credit_note' => 'Credit note', 'sales_order' => 'Sales order',
            'delivery_note' => 'Delivery note', 'purchase_order' => 'Purchase order',
        ],
        'ar' => [
            'date' => 'التاريخ', 'due' => 'تاريخ الاستحقاق', 'expected' => 'التاريخ المتوقع',
            'status' => 'الحالة', 'party' => 'الحريف / المزود', 'fiscal' => 'المعرف الجبائي',
            'address' => 'العنوان', 'email' => 'البريد الإلكتروني', 'code' => 'الرمز',
            'description' => 'الوصف', 'qty' => 'الكمية', 'unit_price' => 'سعر الوحدة',
            'discount' => 'التخفيض', 'vat' => 'الأداء', 'total' => 'المجموع',
            'subtotal' => 'المجموع دون أداء', 'tax_total' => 'مجموع الأداء', 'stamp' => 'الطابع الجبائي',
            'notes' => 'ملاحظات', 'currency' => 'العملة', 'invoice' => 'فاتورة',
            'devis' => 'عرض سعر', 'credit_note' => 'إشعار دائن', 'sales_order' => 'طلب حريف',
            'delivery_note' => 'وصل تسليم', 'purchase_order' => 'طلب شراء',
        ],
        default => [
            'date' => 'Date', 'due' => 'Date d’échéance', 'expected' => 'Date prévue',
            'status' => 'Statut', 'party' => 'Client / Fournisseur', 'fiscal' => 'Matricule fiscal',
            'address' => 'Adresse', 'email' => 'E-mail', 'code' => 'Code',
            'description' => 'Désignation', 'qty' => 'Quantité', 'unit_price' => 'Prix unitaire',
            'discount' => 'Remise', 'vat' => 'TVA', 'total' => 'Total',
            'subtotal' => 'Total HT', 'tax_total' => 'Total TVA', 'stamp' => 'Timbre fiscal',
            'notes' => 'Notes', 'currency' => 'Devise', 'invoice' => 'Facture',
            'devis' => 'Devis', 'credit_note' => 'Avoir', 'sales_order' => 'Bon de commande',
            'delivery_note' => 'Bon de livraison', 'purchase_order' => 'Bon de commande fournisseur',
        ],
    };
}

function documentPdfCompany(mysqli $conn, int $tenantId): array
{
    $stmt = $conn->prepare('SELECT organization_name, fiscal_id, phone, fax, address, website FROM companies WHERE id = ? AND status = \'ACTIVE\' LIMIT 1');
    $stmt->bind_param('i', $tenantId);
    $stmt->execute();
    $company = $stmt->get_result()->fetch_assoc();
    $stmt->close();
    if (!$company) {
        throw new RuntimeException('Active company profile not found.');
    }
    return $company;
}

function documentPdfFetchItems(mysqli $conn, string $sql, int $documentId): array
{
    $stmt = $conn->prepare($sql);
    $stmt->bind_param('i', $documentId);
    $stmt->execute();
    $items = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);
    $stmt->close();
    if (!$items) {
        throw new RuntimeException('The saved document has no line items.');
    }
    return $items;
}

function documentPdfLoad(mysqli $conn, int $tenantId, string $documentType, int $documentId): array
{
    if ($documentId <= 0) {
        throw new InvalidArgumentException('A saved document is required before sending.');
    }

    if (in_array($documentType, ['invoice', 'devis', 'credit_note'], true)) {
        $stmt = $conn->prepare("SELECT i.*, c.name party_name, c.email party_email, c.phone party_phone,
            c.address party_address, c.fiscalId party_fiscal_id
            FROM erp_invoices i
            LEFT JOIN clients c ON c.id = CAST(i.custom_code AS UNSIGNED) AND c.user_id = i.user_id
            WHERE i.id = ? AND i.user_id = ? LIMIT 1");
        $stmt->bind_param('ii', $documentId, $tenantId);
        $stmt->execute();
        $header = $stmt->get_result()->fetch_assoc();
        $stmt->close();
        if (!$header) throw new RuntimeException('Document not found.');

        $expectedType = match ($documentType) {
            'devis' => 'DEVIS', 'credit_note' => 'AVOIR', default => 'FACTURE',
        };
        if (strtoupper((string)$header['invoice_type']) !== $expectedType) {
            throw new RuntimeException('The saved document type does not match the requested document type.');
        }
        if ((int)($header['is_validated'] ?? 0) !== 1) {
            throw new RuntimeException('Only a validated document can be sent.');
        }
        if (strtoupper((string)($header['status'] ?? '')) === 'CANCELLED') {
            throw new RuntimeException('A cancelled document cannot be sent.');
        }
        if ($expectedType === 'DEVIS' && !in_array(strtoupper((string)$header['status']), ['SENT', 'ACCEPTED', 'REJECTED'], true)) {
            throw new RuntimeException('This quotation cannot be sent in its current state.');
        }

        $snapshot = invoiceSnapshotLoad($conn, $tenantId, $documentId);
        if ($snapshot !== null) {
            $projection = invoiceSnapshotPdfProjection($snapshot);
            return $projection['document'] + ['_snapshot_company' => $projection['company']];
        }

        $items = documentPdfFetchItems($conn, 'SELECT product_code code, product description, qty, price, discount, tva_rate,
            subtotal, montant_tva tax_total, subtotalTTC total FROM erp_invoice_items WHERE invoice_id = ? ORDER BY id', $documentId);
        return [
            'number' => (string)$header['invoice'], 'date' => (string)$header['invoice_date'],
            'due_date' => (string)$header['invoice_due_date'], 'expected_date' => '',
            'status' => (string)$header['status'], 'currency' => (string)($header['currency'] ?? 'TND'),
            'party_name' => (string)($header['party_name'] ?? ''), 'party_email' => (string)($header['party_email'] ?? $header['custom_email'] ?? ''),
            'party_phone' => (string)($header['party_phone'] ?? ''), 'party_address' => (string)($header['party_address'] ?? ''),
            'party_fiscal_id' => (string)($header['party_fiscal_id'] ?? ''), 'notes' => (string)($header['notes'] ?? ''),
            'subtotal' => (float)($header['subtotal'] ?? 0), 'tax_total' => (float)($header['montant_tva'] ?? 0),
            'stamp' => (float)($header['timbre'] ?? 0), 'total' => (float)($header['total'] ?? 0), 'items' => $items,
        ];
    }

    if ($documentType === 'sales_order') {
        $stmt = $conn->prepare("SELECT o.*, c.name party_name, c.email party_email, c.phone party_phone,
            c.address party_address, c.fiscalId party_fiscal_id FROM erp_sales_orders o
            JOIN clients c ON c.id = o.client_id AND c.user_id = o.user_id
            WHERE o.id = ? AND o.user_id = ? LIMIT 1");
        $stmt->bind_param('ii', $documentId, $tenantId);
        $stmt->execute(); $header = $stmt->get_result()->fetch_assoc(); $stmt->close();
        if (!$header) throw new RuntimeException('Document not found.');
        if (!in_array(strtoupper((string)$header['status']), ['CONFIRMED', 'PARTIALLY_DELIVERED', 'DELIVERED', 'INVOICED'], true)) {
            throw new RuntimeException('Only a confirmed sales order can be sent.');
        }
        $items = documentPdfFetchItems($conn, 'SELECT product_code code, product description, qty, price, discount, tva_rate,
            subtotal, montant_tva tax_total, total FROM erp_sales_order_items WHERE sales_order_id = ? ORDER BY id', $documentId);
        return documentPdfNormalizeOperationalHeader($header, $items, 'order_number', 'order_date', 'expected_delivery_date', 'montant_tva');
    }

    if ($documentType === 'delivery_note') {
        $stmt = $conn->prepare("SELECT d.*, c.name party_name, c.email party_email, c.phone party_phone,
            c.address party_address, c.fiscalId party_fiscal_id FROM erp_delivery_notes d
            JOIN clients c ON c.id = d.client_id AND c.user_id = d.user_id
            WHERE d.id = ? AND d.user_id = ? AND d.document_type = 'DELIVERY' LIMIT 1");
        $stmt->bind_param('ii', $documentId, $tenantId);
        $stmt->execute(); $header = $stmt->get_result()->fetch_assoc(); $stmt->close();
        if (!$header) throw new RuntimeException('Document not found.');
        if (!in_array(strtoupper((string)$header['status']), ['CONFIRMED', 'DELIVERED'], true)) {
            throw new RuntimeException('Only a confirmed delivery note can be sent.');
        }
        $items = documentPdfFetchItems($conn, 'SELECT product_code code, product description, qty, price, discount, tva_rate,
            subtotal, montant_tva tax_total, total FROM erp_delivery_note_items WHERE delivery_note_id = ? ORDER BY id', $documentId);
        return documentPdfNormalizeOperationalHeader($header, $items, 'delivery_number', 'delivery_date', 'expected_delivery_date', 'montant_tva');
    }

    $stmt = $conn->prepare("SELECT o.*, s.name party_name, s.email party_email, s.phone party_phone,
        s.address party_address, s.fiscal_id party_fiscal_id FROM erp_supplier_orders o
        JOIN suppliers s ON s.id = o.supplier_id AND s.user_id = o.user_id
        WHERE o.id = ? AND o.user_id = ? LIMIT 1");
    $stmt->bind_param('ii', $documentId, $tenantId);
    $stmt->execute(); $header = $stmt->get_result()->fetch_assoc(); $stmt->close();
    if (!$header) throw new RuntimeException('Document not found.');
    if (!in_array(strtoupper((string)$header['status']), ['SENT', 'PARTIALLY_RECEIVED', 'RECEIVED'], true)) {
        throw new RuntimeException('Only a sent supplier order can be emailed.');
    }
    $items = documentPdfFetchItems($conn, 'SELECT product_code code, description, qty, price, 0 discount, tva_rate,
        ROUND(qty * price, 3) subtotal, ROUND(qty * price * tva_rate / 100, 3) tax_total, line_total total
        FROM erp_supplier_order_items WHERE supplier_order_id = ? ORDER BY id', $documentId);
    return documentPdfNormalizeOperationalHeader($header, $items, 'order_number', 'order_date', 'expected_date', 'total_vat');
}

function documentPdfNormalizeOperationalHeader(array $header, array $items, string $numberKey, string $dateKey, string $expectedKey, string $taxKey): array
{
    $subtotal = isset($header['subtotal']) ? (float)$header['subtotal'] : array_sum(array_map(static fn($item) => (float)($item['subtotal'] ?? 0), $items));
    $taxTotal = isset($header[$taxKey]) ? (float)$header[$taxKey] : array_sum(array_map(static fn($item) => (float)($item['tax_total'] ?? 0), $items));
    $total = isset($header['total']) ? (float)$header['total'] : $subtotal + $taxTotal;
    return [
        'number' => (string)($header[$numberKey] ?? ''), 'date' => (string)($header[$dateKey] ?? ''),
        'due_date' => '', 'expected_date' => (string)($header[$expectedKey] ?? ''),
        'status' => (string)($header['status'] ?? ''), 'currency' => 'TND',
        'party_name' => (string)($header['party_name'] ?? ''), 'party_email' => (string)($header['party_email'] ?? ''),
        'party_phone' => (string)($header['party_phone'] ?? ''), 'party_address' => (string)($header['party_address'] ?? ''),
        'party_fiscal_id' => (string)($header['party_fiscal_id'] ?? ''), 'notes' => (string)($header['notes'] ?? ''),
        'subtotal' => $subtotal, 'tax_total' => $taxTotal, 'stamp' => 0.0, 'total' => $total, 'items' => $items,
    ];
}

function documentPdfRender(array $company, array $document, string $documentType, string $language = 'fr'): string
{
    $language = in_array($language, ['en', 'fr', 'ar'], true) ? $language : 'fr';
    $copy = documentPdfCopy($language);
    $direction = $language === 'ar' ? 'rtl' : 'ltr';
    $title = $copy[$documentType] ?? $copy['invoice'];
    $rows = '';
    foreach ($document['items'] as $item) {
        $rows .= '<tr><td>' . documentPdfEscape($item['code'] ?? '') . '</td><td>' . documentPdfEscape($item['description'] ?? '') . '</td>'
            . '<td class="num">' . documentPdfNumber($item['qty'] ?? 0) . '</td><td class="num">' . documentPdfNumber($item['price'] ?? 0) . '</td>'
            . '<td class="num">' . documentPdfNumber($item['discount'] ?? 0) . '%</td><td class="num">' . documentPdfNumber($item['tva_rate'] ?? 0) . '%</td>'
            . '<td class="num">' . documentPdfNumber($item['total'] ?? 0) . '</td></tr>';
    }
    $secondaryDate = $document['due_date'] ?: $document['expected_date'];
    $secondaryLabel = $document['due_date'] ? $copy['due'] : $copy['expected'];
    $notes = trim((string)($document['notes'] ?? ''));
    $html = '<!doctype html><html lang="' . $language . '" dir="' . $direction . '"><head><meta charset="utf-8"><style>
        @page{margin:28px 30px 42px}body{font-family:"DejaVu Sans",sans-serif;color:#172033;font-size:10px}h1{font-size:23px;color:#10937e;margin:0 0 4px}.header{width:100%;border-bottom:2px solid #16b39a;padding-bottom:16px;margin-bottom:18px}.header td{vertical-align:top}.company{font-size:16px;font-weight:bold}.muted{color:#64748b}.meta,.party{width:100%;margin-bottom:16px}.box{border:1px solid #dbe4ec;background:#f8fafc;padding:10px}.label{color:#64748b;font-size:8px;text-transform:uppercase}.value{font-weight:bold;margin-top:2px}table.lines{width:100%;border-collapse:collapse;margin-top:12px}.lines th{background:#10937e;color:#fff;padding:7px 5px;text-align:left}.lines td{border-bottom:1px solid #e2e8f0;padding:7px 5px}.num{text-align:right;white-space:nowrap}.totals{width:42%;margin-left:auto;margin-top:15px;border-collapse:collapse}.totals td{padding:5px;border-bottom:1px solid #e2e8f0}.grand{font-size:13px;font-weight:bold;color:#10937e}.notes{margin-top:18px;padding:10px;border-left:3px solid #16b39a;background:#f8fafc}
        </style></head><body><table class="header"><tr><td><div class="company">' . documentPdfEscape($company['organization_name']) . '</div><div class="muted">' . documentPdfEscape($company['address']) . '<br>' . documentPdfEscape($company['phone']) . '<br>' . documentPdfEscape($company['website']) . '</div></td><td class="num"><h1>' . documentPdfEscape($title) . '</h1><strong>' . documentPdfEscape($document['number']) . '</strong><br><span class="muted">' . documentPdfEscape($copy['status']) . ': ' . documentPdfEscape($document['status']) . '</span></td></tr></table>
        <table class="meta"><tr><td class="box"><div class="label">' . documentPdfEscape($copy['date']) . '</div><div class="value">' . documentPdfEscape($document['date']) . '</div></td><td class="box"><div class="label">' . documentPdfEscape($secondaryLabel) . '</div><div class="value">' . documentPdfEscape($secondaryDate) . '</div></td><td class="box"><div class="label">' . documentPdfEscape($copy['currency']) . '</div><div class="value">' . documentPdfEscape($document['currency']) . '</div></td></tr></table>
        <div class="party box"><div class="label">' . documentPdfEscape($copy['party']) . '</div><div class="value">' . documentPdfEscape($document['party_name']) . '</div>' . documentPdfEscape($document['party_address']) . '<br>' . documentPdfEscape($copy['fiscal']) . ': ' . documentPdfEscape($document['party_fiscal_id']) . ' · ' . documentPdfEscape($copy['email']) . ': ' . documentPdfEscape($document['party_email']) . '</div>
        <table class="lines"><thead><tr><th>' . documentPdfEscape($copy['code']) . '</th><th>' . documentPdfEscape($copy['description']) . '</th><th>' . documentPdfEscape($copy['qty']) . '</th><th>' . documentPdfEscape($copy['unit_price']) . '</th><th>' . documentPdfEscape($copy['discount']) . '</th><th>' . documentPdfEscape($copy['vat']) . '</th><th>' . documentPdfEscape($copy['total']) . '</th></tr></thead><tbody>' . $rows . '</tbody></table>
        <table class="totals"><tr><td>' . documentPdfEscape($copy['subtotal']) . '</td><td class="num">' . documentPdfNumber($document['subtotal']) . ' ' . documentPdfEscape($document['currency']) . '</td></tr><tr><td>' . documentPdfEscape($copy['tax_total']) . '</td><td class="num">' . documentPdfNumber($document['tax_total']) . ' ' . documentPdfEscape($document['currency']) . '</td></tr>'
        . ((float)$document['stamp'] !== 0.0 ? '<tr><td>' . documentPdfEscape($copy['stamp']) . '</td><td class="num">' . documentPdfNumber($document['stamp']) . ' ' . documentPdfEscape($document['currency']) . '</td></tr>' : '')
        . '<tr class="grand"><td>' . documentPdfEscape($copy['total']) . '</td><td class="num">' . documentPdfNumber($document['total']) . ' ' . documentPdfEscape($document['currency']) . '</td></tr></table>'
        . ($notes !== '' ? '<div class="notes"><strong>' . documentPdfEscape($copy['notes']) . '</strong><br>' . nl2br(documentPdfEscape($notes)) . '</div>' : '') . '</body></html>';

    $options = new Options();
    $options->set('defaultFont', 'DejaVu Sans');
    $options->set('isRemoteEnabled', false);
    $dompdf = new Dompdf($options);
    $dompdf->setPaper('A4', 'portrait');
    $dompdf->loadHtml($html, 'UTF-8');
    $dompdf->render();
    $canvas = $dompdf->getCanvas();
    $canvas->page_text(515, 806, '{PAGE_NUM} / {PAGE_COUNT}', 'DejaVu Sans', 8, [0.4, 0.45, 0.55]);
    return $dompdf->output();
}

function createServerDocumentPdf(mysqli $conn, int $tenantId, string $documentType, int $documentId, string $language = 'fr'): array
{
    $document = documentPdfLoad($conn, $tenantId, $documentType, $documentId);
    $company = isset($document['_snapshot_company']) && is_array($document['_snapshot_company'])
        ? $document['_snapshot_company']
        : documentPdfCompany($conn, $tenantId);
    unset($document['_snapshot_company']);
    $safeNumber = preg_replace('/[^A-Za-z0-9._-]/', '_', (string)$document['number']) ?: (string)$documentId;
    return [
        'binary' => documentPdfRender($company, $document, $documentType, $language),
        'filename' => $documentType . '-' . $safeNumber . '.pdf',
        'document' => $document,
    ];
}
