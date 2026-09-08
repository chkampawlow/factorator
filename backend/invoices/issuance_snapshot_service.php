<?php

declare(strict_types=1);

function invoiceSnapshotCanonicalize(mixed $value): mixed
{
    if (!is_array($value)) {
        return $value;
    }
    if (array_is_list($value)) {
        return array_map('invoiceSnapshotCanonicalize', $value);
    }
    ksort($value, SORT_STRING);
    foreach ($value as $key => $item) {
        $value[$key] = invoiceSnapshotCanonicalize($item);
    }
    return $value;
}

function invoiceSnapshotJson(array $snapshot): string
{
    return json_encode(
        invoiceSnapshotCanonicalize($snapshot),
        JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES | JSON_PRESERVE_ZERO_FRACTION | JSON_THROW_ON_ERROR
    );
}

function invoiceSnapshotDecodeVerified(string $json, string $expectedHash): array
{
    $actualHash = hash('sha256', $json);
    if (!preg_match('/^[a-f0-9]{64}$/', $expectedHash) || !hash_equals($expectedHash, $actualHash)) {
        throw new RuntimeException('The immutable invoice snapshot failed its integrity check.');
    }
    $snapshot = json_decode($json, true, 512, JSON_THROW_ON_ERROR);
    if (!is_array($snapshot) || (int)($snapshot['version'] ?? 0) !== 1) {
        throw new RuntimeException('The immutable invoice snapshot version is unsupported.');
    }
    return $snapshot;
}

function invoiceSnapshotLoad(mysqli $conn, int $tenantId, int $invoiceId): ?array
{
    $stmt = $conn->prepare('SELECT snapshot_json,snapshot_sha256 FROM erp_invoice_issuance_snapshots WHERE invoice_id=? AND user_id=? LIMIT 1');
    $stmt->bind_param('ii', $invoiceId, $tenantId);
    $stmt->execute();
    $row = $stmt->get_result()->fetch_assoc();
    $stmt->close();
    if (!$row) {
        return null;
    }
    return invoiceSnapshotDecodeVerified((string)$row['snapshot_json'], (string)$row['snapshot_sha256']);
}

function invoiceSnapshotActorId(int $fallback): int
{
    if (function_exists('activeAuthPrincipal') && ($principal = activeAuthPrincipal())) {
        return authActorId($principal);
    }
    return $fallback;
}

function captureInvoiceIssuanceSnapshot(mysqli $conn, int $tenantId, int $actorId, int $invoiceId): array
{
    $existing = invoiceSnapshotLoad($conn, $tenantId, $invoiceId);
    if ($existing !== null) {
        return $existing;
    }

    $actorId = invoiceSnapshotActorId($actorId);
    $stmt = $conn->prepare("SELECT i.*,
        co.organization_name seller_name,co.fiscal_id seller_fiscal_id,co.phone seller_phone,
        co.fax seller_fax,co.address seller_address,co.website seller_website,
        cl.type buyer_type,cl.name buyer_name,cl.email buyer_email,cl.phone buyer_phone,
        cl.address buyer_address,cl.fiscalId buyer_fiscal_id,cl.cin buyer_cin,
        issuer.display_name issuer_name,issuer.email issuer_email
        FROM erp_invoices i
        JOIN companies co ON co.id=i.user_id
        JOIN clients cl ON cl.id=CAST(i.custom_code AS UNSIGNED) AND cl.user_id=i.user_id
        LEFT JOIN users issuer ON issuer.id=?
        WHERE i.id=? AND i.user_id=? LIMIT 1 FOR UPDATE");
    $stmt->bind_param('iii', $actorId, $invoiceId, $tenantId);
    $stmt->execute();
    $invoice = $stmt->get_result()->fetch_assoc();
    $stmt->close();
    if (!$invoice || (int)($invoice['is_validated'] ?? 0) !== 1) {
        throw new RuntimeException('Only an issued tenant invoice can be snapshotted.');
    }

    $documentType = strtoupper((string)($invoice['invoice_type'] ?? ''));
    if (!in_array($documentType, ['FACTURE', 'DEVIS', 'AVOIR'], true)) {
        throw new RuntimeException('Unsupported issued document type.');
    }

    $itemsStmt = $conn->prepare('SELECT id,product_id,product_code,product,qty,price,discount,tax_profile_id,tva_rate,tax_regime,fodec_rate,fodec_amount,legal_basis,certificate_reference,subtotal,montant_tva,subtotalTTC,subtotal_tnd,tax_tnd,total_tnd FROM erp_invoice_items WHERE invoice_id=? ORDER BY id');
    $itemsStmt->bind_param('i', $invoiceId);
    $itemsStmt->execute();
    $items = $itemsStmt->get_result()->fetch_all(MYSQLI_ASSOC);
    $itemsStmt->close();
    if ($items === []) {
        throw new RuntimeException('An issued document snapshot requires at least one line item.');
    }

    $snapshot = [
        'version' => 1,
        'document' => [
            'id' => (int)$invoice['id'],
            'number' => (string)$invoice['invoice'],
            'type' => $documentType,
            'status_at_issue' => (string)$invoice['status'],
            'issue_date' => (string)$invoice['invoice_date'],
            'due_date' => (string)$invoice['invoice_due_date'],
            'currency' => (string)($invoice['currency'] ?? 'TND'),
            'exchange_rate' => (string)($invoice['exchange_rate'] ?? '1'),
            'exchange_rate_date' => (string)($invoice['exchange_rate_date'] ?? ''),
            'salesperson_name' => (string)($invoice['salesperson_name'] ?? ''),
            'notes' => (string)($invoice['notes'] ?? ''),
            'source_flow' => (string)($invoice['source_flow'] ?? 'DIRECT'),
            'sales_order_id' => (int)($invoice['sales_order_id'] ?? 0),
            'delivery_note_id' => (int)($invoice['delivery_note_id'] ?? 0),
            'source_invoice_id' => (int)($invoice['source_invoice_id'] ?? 0),
            'subtotal' => (string)($invoice['subtotal'] ?? '0'),
            'tax_base' => (string)($invoice['base_tva'] ?? '0'),
            'tax_total' => (string)($invoice['montant_tva'] ?? '0'),
            'stamp_duty' => (string)($invoice['timbre'] ?? '0'),
            'total' => (string)($invoice['total'] ?? '0'),
            'subtotal_tnd' => (string)($invoice['subtotal_tnd'] ?? '0'),
            'tax_total_tnd' => (string)($invoice['tax_total_tnd'] ?? '0'),
            'total_tnd' => (string)($invoice['total_tnd'] ?? '0'),
        ],
        'seller' => [
            'name' => (string)$invoice['seller_name'],
            'fiscal_id' => (string)($invoice['seller_fiscal_id'] ?? ''),
            'phone' => (string)($invoice['seller_phone'] ?? ''),
            'fax' => (string)($invoice['seller_fax'] ?? ''),
            'address' => (string)($invoice['seller_address'] ?? ''),
            'website' => (string)($invoice['seller_website'] ?? ''),
        ],
        'buyer' => [
            'type' => (string)($invoice['buyer_type'] ?? ''),
            'name' => (string)$invoice['buyer_name'],
            'email' => (string)($invoice['buyer_email'] ?? ''),
            'phone' => (string)($invoice['buyer_phone'] ?? ''),
            'address' => (string)($invoice['buyer_address'] ?? ''),
            'fiscal_id' => (string)($invoice['buyer_fiscal_id'] ?? ''),
            'cin' => (string)($invoice['buyer_cin'] ?? ''),
        ],
        'issuer' => [
            'actor_id' => $actorId,
            'display_name' => (string)($invoice['issuer_name'] ?? ''),
            'email' => (string)($invoice['issuer_email'] ?? ''),
            'salesperson_name' => (string)($invoice['salesperson_name'] ?? ''),
        ],
        'items' => array_map(static fn(array $item): array => [
            'id' => (int)$item['id'],
            'product_id' => (int)($item['product_id'] ?? 0),
            'code' => (string)($item['product_code'] ?? ''),
            'description' => (string)($item['product'] ?? ''),
            'qty' => (string)($item['qty'] ?? '0'),
            'price' => (string)($item['price'] ?? '0'),
            'discount' => (string)($item['discount'] ?? '0'),
            'tax_profile_id' => (int)($item['tax_profile_id'] ?? 0),
            'tva_rate' => (string)($item['tva_rate'] ?? '0'),
            'tax_regime' => (string)($item['tax_regime'] ?? ''),
            'fodec_rate' => (string)($item['fodec_rate'] ?? '0'),
            'fodec_amount' => (string)($item['fodec_amount'] ?? '0'),
            'legal_basis' => (string)($item['legal_basis'] ?? ''),
            'certificate_reference' => (string)($item['certificate_reference'] ?? ''),
            'subtotal' => (string)($item['subtotal'] ?? '0'),
            'tax_total' => (string)($item['montant_tva'] ?? '0'),
            'total' => (string)($item['subtotalTTC'] ?? '0'),
            'subtotal_tnd' => (string)($item['subtotal_tnd'] ?? '0'),
            'tax_tnd' => (string)($item['tax_tnd'] ?? '0'),
            'total_tnd' => (string)($item['total_tnd'] ?? '0'),
        ], $items),
    ];

    $json = invoiceSnapshotJson($snapshot);
    $hash = hash('sha256', $json);
    $insert = $conn->prepare('INSERT INTO erp_invoice_issuance_snapshots(invoice_id,user_id,document_type,snapshot_version,snapshot_json,snapshot_sha256,captured_by) VALUES(?,?,?,1,?,?,NULLIF(?,0))');
    $insert->bind_param('iisssi', $invoiceId, $tenantId, $documentType, $json, $hash, $actorId);
    $insert->execute();
    $insert->close();
    return $snapshot;
}

function invoiceSnapshotPdfProjection(array $snapshot): array
{
    $document = $snapshot['document'] ?? [];
    $buyer = $snapshot['buyer'] ?? [];
    return [
        'company' => [
            'organization_name' => (string)($snapshot['seller']['name'] ?? ''),
            'fiscal_id' => (string)($snapshot['seller']['fiscal_id'] ?? ''),
            'phone' => (string)($snapshot['seller']['phone'] ?? ''),
            'fax' => (string)($snapshot['seller']['fax'] ?? ''),
            'address' => (string)($snapshot['seller']['address'] ?? ''),
            'website' => (string)($snapshot['seller']['website'] ?? ''),
        ],
        'document' => [
            'number' => (string)($document['number'] ?? ''),
            'date' => (string)($document['issue_date'] ?? ''),
            'due_date' => (string)($document['due_date'] ?? ''),
            'expected_date' => '',
            'status' => (string)($document['status_at_issue'] ?? ''),
            'currency' => (string)($document['currency'] ?? 'TND'),
            'party_name' => (string)($buyer['name'] ?? ''),
            'party_email' => (string)($buyer['email'] ?? ''),
            'party_phone' => (string)($buyer['phone'] ?? ''),
            'party_address' => (string)($buyer['address'] ?? ''),
            'party_fiscal_id' => (string)($buyer['fiscal_id'] ?? ''),
            'notes' => (string)($document['notes'] ?? ''),
            'subtotal' => (float)($document['subtotal'] ?? 0),
            'tax_total' => (float)($document['tax_total'] ?? 0),
            'stamp' => (float)($document['stamp_duty'] ?? 0),
            'total' => (float)($document['total'] ?? 0),
            'items' => $snapshot['items'] ?? [],
        ],
    ];
}
