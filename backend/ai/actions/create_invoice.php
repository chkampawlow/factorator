<?php

declare(strict_types=1);

require_once __DIR__ . '/_bootstrap.php';

// AI_INVOICE_ACTION_DISABLED: the shared bootstrap keeps this legacy mutation fail-closed.

$data = input();
$userId = authenticatedUserId();
$pdo = db();
$idempotencyKey = trim((string)($_SERVER['HTTP_IDEMPOTENCY_KEY'] ?? ($data['idempotency_key'] ?? '')));
if (strlen($idempotencyKey) < 8 || strlen($idempotencyKey) > 128 || !preg_match('/^[A-Za-z0-9._:-]+$/', $idempotencyKey)) {
    respond(422, ['success' => false, 'message' => 'A valid idempotency key is required.']);
}
$hashPayload = $data;
ksort($hashPayload);
$requestHash = hash('sha256', json_encode($hashPayload, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE | JSON_PRESERVE_ZERO_FRACTION));

$clientId = positiveId($data, 'client_id');
$invoiceDate = validDate(
    requiredString($data, 'invoice_date', 10),
    'invoice_date'
);
$dueDate = validDate(
    requiredString($data, 'invoice_due_date', 10),
    'invoice_due_date'
);

if ($dueDate < $invoiceDate) {
    respond(422, [
        'success' => false,
        'message' => 'invoice_due_date cannot be before invoice_date.',
    ]);
}

$periodCheck = $pdo->prepare(
    "SELECT id FROM erp_accounting_periods
     WHERE user_id = :user_id AND status IN ('LOCKED','FILED')
       AND :invoice_date BETWEEN period_start AND period_end
     LIMIT 1"
);
$periodCheck->execute(['user_id' => $userId, 'invoice_date' => $invoiceDate]);
if ($periodCheck->fetch()) {
    respond(422, ['success' => false, 'message' => 'This accounting period is locked or filed.']);
}

$today = new DateTimeImmutable('today', new DateTimeZone('Africa/Tunis'));
$requestedDate = new DateTimeImmutable($invoiceDate, new DateTimeZone('Africa/Tunis'));
if ($requestedDate < $today) {
    $roleCheck = $pdo->prepare('SELECT role FROM users WHERE id = :id LIMIT 1');
    $roleCheck->execute(['id' => $userId]);
    $role = strtoupper((string)($roleCheck->fetchColumn() ?: ''));
    if (!in_array($role, ['ADMINISTRATOR', 'ACCOUNTING'], true)) {
        respond(403, ['success' => false, 'message' => 'Only accounting users can backdate an invoice.']);
    }
}

$clientCheck = $pdo->prepare(
    'SELECT id, email
     FROM clients
     WHERE id = :id
       AND user_id = :user_id
       AND is_archived = 0
     LIMIT 1'
);
$clientCheck->execute([
    'id' => $clientId,
    'user_id' => $userId,
]);
$client = $clientCheck->fetch();

if (!$client) {
    respond(404, [
        'success' => false,
        'message' => 'Client not found.',
    ]);
}

$items = $data['items'] ?? null;

if (!is_array($items) || $items === []) {
    respond(422, [
        'success' => false,
        'message' => 'At least one invoice item is required.',
    ]);
}

$notes = optionalString($data, 'notes', 10000) ?? '';
$shipping = decimalValue($data['shipping'] ?? 0, 'shipping');
$invoiceDiscount = decimalValue($data['discount'] ?? 0, 'discount');
$timbre = decimalValue($data['timbre'] ?? 0, 'timbre');

$invoiceType = strtoupper(trim((string) ($data['invoice_type'] ?? 'FACTURE')));

if ($invoiceType !== 'FACTURE') {
    respond(422, [
        'success' => false,
        'message' => 'This endpoint creates FACTURE invoices only. Credit notes require a separate source-invoice workflow.',
    ]);
}

$preparedItems = [];
$subtotal = 0.0;
$vatTotal = 0.0;
$subtotalTtc = 0.0;

foreach ($items as $index => $item) {
    if (!is_array($item)) {
        respond(422, [
            'success' => false,
            'message' => "items[{$index}] must be an object.",
        ]);
    }

    $productId = null;

    if (($item['product_id'] ?? null) !== null && $item['product_id'] !== '') {
        $productId = filter_var(
            $item['product_id'],
            FILTER_VALIDATE_INT,
            ['options' => ['min_range' => 1]]
        );

        if ($productId === false) {
            respond(422, [
                'success' => false,
                'message' => "items[{$index}].product_id is invalid.",
            ]);
        }
    }

    $name = trim((string) ($item['product'] ?? ''));
    $code = trim((string) ($item['product_code'] ?? ''));
    $price = decimalValue($item['price'] ?? null, "items[{$index}].price");
    $qty = decimalValue($item['qty'] ?? 1, "items[{$index}].qty", 0.001);
    $discountRate = decimalValue(
        $item['discount'] ?? 0,
        "items[{$index}].discount"
    );
    $tvaRate = decimalValue(
        $item['tva_rate'] ?? 0,
        "items[{$index}].tva_rate"
    );

    if ($discountRate > 100 || $tvaRate > 100) {
        respond(422, [
            'success' => false,
            'message' => "items[{$index}] discount and TVA must not exceed 100.",
        ]);
    }

    if ($productId !== null) {
        $productStatement = $pdo->prepare(
            'SELECT id, code, name, price, tva_rate
             FROM products
             WHERE id = :id
               AND user_id = :user_id
             LIMIT 1'
        );
        $productStatement->execute([
            'id' => $productId,
            'user_id' => $userId,
        ]);
        $product = $productStatement->fetch();

        if (!$product) {
            respond(404, [
                'success' => false,
                'message' => "Product for items[{$index}] was not found.",
            ]);
        }

        /*
        | Use authoritative catalog identity. Price and TVA remain request
        | values so the invoice can support negotiated prices.
        */
        $name = (string) $product['name'];
        $code = (string) ($product['code'] ?? '');
    }

    if ($name === '') {
        respond(422, [
            'success' => false,
            'message' => "items[{$index}].product is required.",
        ]);
    }

    $gross = round($qty * $price, 3);
    $lineSubtotal = round($gross * (1 - ($discountRate / 100)), 3);
    $lineVat = round($lineSubtotal * ($tvaRate / 100), 3);
    $lineTtc = round($lineSubtotal + $lineVat, 3);

    $subtotal += $lineSubtotal;
    $vatTotal += $lineVat;
    $subtotalTtc += $lineTtc;

    $preparedItems[] = [
        'product_id' => $productId,
        'product_code' => $code,
        'product' => $name,
        'qty' => $qty,
        'price' => $price,
        'discount' => $discountRate,
        'tva_rate' => $tvaRate,
        'subtotal' => $lineSubtotal,
        'montant_tva' => $lineVat,
        'subtotalTTC' => $lineTtc,
    ];
}

$subtotal = round($subtotal, 3);
$vatTotal = round($vatTotal, 3);
$subtotalTtc = round($subtotalTtc, 3);

if ($invoiceDiscount > ($subtotalTtc + $shipping + $timbre)) {
    respond(422, [
        'success' => false,
        'message' => 'Invoice discount exceeds the invoice amount.',
    ]);
}

$total = round(
    $subtotalTtc + $shipping + $timbre - $invoiceDiscount,
    3
);

$isValidated = !empty($data['is_validated']) ? 1 : 0;
$status = strtoupper(trim((string) ($data['status'] ?? 'UNPAID')));

if ($status !== 'UNPAID') {
    respond(422, [
        'success' => false,
        'message' => 'Validated invoices must start unpaid; record settlement through the payment ledger.',
    ]);
}

$paymentMethod = $data['payment_method'] ?? null;

if ($paymentMethod !== null) {
    $paymentMethod = strtoupper(trim((string) $paymentMethod));

    if (!in_array($paymentMethod, ['CASH', 'CARD', 'TRANSFER', 'CHECK'], true)) {
        respond(422, [
            'success' => false,
            'message' => 'Invalid payment_method.',
        ]);
    }
}

try {
    $pdo->beginTransaction();

    $claim = $pdo->prepare("INSERT INTO erp_idempotency_keys(user_id,operation_name,idempotency_key,request_hash) VALUES(:user_id,'ai.invoice.create',:idempotency_key,:request_hash) ON DUPLICATE KEY UPDATE idempotency_key=VALUES(idempotency_key)");
    $claim->execute(['user_id' => $userId, 'idempotency_key' => $idempotencyKey, 'request_hash' => $requestHash]);
    if ($claim->rowCount() !== 1) {
        $existingStatement = $pdo->prepare("SELECT request_hash,entity_id FROM erp_idempotency_keys WHERE user_id=:user_id AND operation_name='ai.invoice.create' AND idempotency_key=:idempotency_key FOR UPDATE");
        $existingStatement->execute(['user_id' => $userId, 'idempotency_key' => $idempotencyKey]);
        $existing = $existingStatement->fetch();
        if (!$existing || !hash_equals((string)$existing['request_hash'], $requestHash)) {
            throw new RuntimeException('Idempotency key was already used with a different request.');
        }
        $existingId = (int)($existing['entity_id'] ?? 0);
        if ($existingId <= 0) throw new RuntimeException('The original idempotent request did not complete.');
        $numberLookup = $pdo->prepare('SELECT invoice FROM erp_invoices WHERE id=:id AND user_id=:user_id');
        $numberLookup->execute(['id' => $existingId, 'user_id' => $userId]);
        $pdo->commit();
        respond(200, ['success' => true, 'invoice_id' => $existingId, 'invoice_number' => $numberLookup->fetchColumn(), 'replayed' => true]);
    }

    $year = (int)substr($invoiceDate, 0, 4);
    $numberStatement = $pdo->prepare(
        "INSERT INTO erp_document_number_sequences (user_id, document_type, document_year, next_number)
         VALUES (:user_id, 'FACTURE', :document_year, LAST_INSERT_ID(1))
         ON DUPLICATE KEY UPDATE next_number = LAST_INSERT_ID(next_number + 1)"
    );
    $numberStatement->execute(['user_id' => $userId, 'document_year' => $year]);
    $sequence = (int)$pdo->query('SELECT LAST_INSERT_ID()')->fetchColumn();
    if ($sequence <= 0) {
        throw new RuntimeException('Failed to reserve an invoice number.');
    }
    $invoiceNumber = sprintf('FAC-%d-%06d', $year, $sequence);

    $invoiceStatement = $pdo->prepare(
        'INSERT INTO erp_invoices
            (
                invoice, custom_email, custom_code, source_flow,
                invoice_date, invoice_due_date, subtotal, base_tva,
                montant_tva, subtotal_ttc, shipping, discount, vat,
                total, notes, invoice_type, status, is_validated,
                type_doc, timbre, payment_method, user_id
            )
         VALUES
            (
                :invoice, :custom_email, :custom_code, \'DIRECT\',
                :invoice_date, :invoice_due_date, :subtotal, :base_tva,
                :montant_tva, :subtotal_ttc, :shipping, :discount, :vat,
                :total, :notes, \'FACTURE\', :status, :is_validated,
                \'F\', :timbre, :payment_method, :user_id
            )'
    );

    $invoiceStatement->execute([
        'invoice' => $invoiceNumber,
        'custom_email' => $client['email'],
        'custom_code' => (string) $clientId,
        'invoice_date' => $invoiceDate,
        'invoice_due_date' => $dueDate,
        'subtotal' => $subtotal,
        'base_tva' => $subtotal,
        'montant_tva' => $vatTotal,
        'subtotal_ttc' => $subtotalTtc,
        'shipping' => $shipping,
        'discount' => $invoiceDiscount,
        'vat' => $vatTotal,
        'total' => $total,
        'notes' => $notes,
        'status' => $status,
        'is_validated' => $isValidated,
        'timbre' => $timbre,
        'payment_method' => $paymentMethod,
        'user_id' => $userId,
    ]);

    $invoiceId = (int) $pdo->lastInsertId();

    $itemStatement = $pdo->prepare(
        'INSERT INTO erp_invoice_items
            (
                invoice_id, invoice, product_id, product_code, product,
                qty, tva_rate, montant_tva, price, discount,
                subtotal, subtotalTTC, invoice_date
            )
         VALUES
            (
                :invoice_id, :invoice, :product_id, :product_code, :product,
                :qty, :tva_rate, :montant_tva, :price, :discount,
                :subtotal, :subtotal_ttc, :invoice_date
            )'
    );

    foreach ($preparedItems as $item) {
        $itemStatement->execute([
            'invoice_id' => $invoiceId,
            'invoice' => $invoiceNumber,
            'product_id' => $item['product_id'],
            'product_code' => $item['product_code'],
            'product' => $item['product'],
            'qty' => $item['qty'],
            'tva_rate' => $item['tva_rate'],
            'montant_tva' => $item['montant_tva'],
            'price' => $item['price'],
            'discount' => $item['discount'],
            'subtotal' => $item['subtotal'],
            'subtotal_ttc' => $item['subtotalTTC'],
            'invoice_date' => $invoiceDate,
        ]);
    }

    $complete = $pdo->prepare("UPDATE erp_idempotency_keys SET entity_id=:entity_id,completed_at=NOW() WHERE user_id=:user_id AND operation_name='ai.invoice.create' AND idempotency_key=:idempotency_key AND entity_id IS NULL");
    $complete->execute(['entity_id' => $invoiceId, 'user_id' => $userId, 'idempotency_key' => $idempotencyKey]);
    if ($complete->rowCount() !== 1) throw new RuntimeException('Could not complete idempotent request.');

    $pdo->commit();

    respond(201, [
        'success' => true,
        'message' => 'Invoice created successfully.',
        'invoice_id' => $invoiceId,
        'invoice_number' => $invoiceNumber,
        'replayed' => false,
        'totals' => [
            'subtotal' => $subtotal,
            'montant_tva' => $vatTotal,
            'subtotal_ttc' => $subtotalTtc,
            'shipping' => $shipping,
            'discount' => $invoiceDiscount,
            'timbre' => $timbre,
            'total' => $total,
            'currency' => 'TND',
        ],
    ]);
} catch (Throwable $exception) {
    if ($pdo->inTransaction()) {
        $pdo->rollBack();
    }

    throw $exception;
}
