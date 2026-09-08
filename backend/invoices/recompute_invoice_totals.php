<?php

header('Content-Type: application/json');

require_once __DIR__ . '/../config/response.php';
require_once __DIR__ . '/../config/db.php';
require_once __DIR__ . '/../auth/auth_required.php';
require_once __DIR__ . '/../auth/role_helper.php';
require_once __DIR__ . '/../taxes/tax_profile_service.php';

try {
    if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
        throw new Exception('Method not allowed');
    }

    $user = requireAuth();
    $userId = (int) $user->id;
    $data = json_decode(file_get_contents('php://input'), true) ?: [];
    $invoiceId = (int) ($data['invoice_id'] ?? 0);
    if ($invoiceId <= 0) {
        throw new Exception('Invalid invoice id');
    }

    $conn = db();
    ensureTaxProfileSchema($conn);
    $conn->begin_transaction();

    $stmt = $conn->prepare(
        "SELECT invoice_date, currency, exchange_rate, timbre, shipping, discount,
                invoice_type, is_validated
         FROM erp_invoices
         WHERE id = ? AND user_id = ?
         FOR UPDATE"
    );
    $stmt->bind_param('ii', $invoiceId, $userId);
    $stmt->execute();
    $invoice = $stmt->get_result()->fetch_assoc();
    $stmt->close();

    if (!$invoice) {
        throw new Exception('Invoice not found');
    }
    requireInvoiceDocumentPermission($conn, $userId, $invoice['invoice_type'] ?? 'FACTURE', 'edit');
    if ((int) $invoice['is_validated'] === 1) {
        throw new Exception('Validated invoices are immutable');
    }

    $stmt = $conn->prepare(
        'SELECT id, product_id, tax_profile_id, qty, price, discount
         FROM erp_invoice_items
         WHERE invoice_id = ?
         ORDER BY id
         FOR UPDATE'
    );
    $stmt->bind_param('i', $invoiceId);
    $stmt->execute();
    $items = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);
    $stmt->close();

    $subtotal = '0.000';
    $vat = '0.000';
    $fodec = '0.000';
    $subtotalTnd = '0.000';
    $taxTnd = '0.000';
    $itemsTotalTnd = '0.000';

    $updateItem = $conn->prepare(
        'UPDATE erp_invoice_items
         SET tax_profile_id=?, tva_rate=?, tax_regime=?, fodec_rate=?, fodec_amount=?,
             legal_basis=?, certificate_reference=?, montant_tva=?, tax_tnd=?, subtotal=?,
             subtotal_tnd=?, subtotalTTC=?, total_tnd=?
         WHERE id=?'
    );

    foreach ($items as $item) {
        $profile = resolveTaxProfile(
            $conn,
            $userId,
            (int) $item['tax_profile_id'],
            (int) $item['product_id'],
            $invoice['invoice_date']
        );
        $tax = calculateTaxLine(
            $item['qty'],
            $item['price'],
            $item['discount'],
            $profile,
            $invoice['exchange_rate']
        );
        $profileId = (int) $profile['id'];
        $itemId = (int) $item['id'];
        $updateItem->bind_param(
            'idsddssddddddi',
            $profileId,
            $tax['vat_rate'],
            $tax['tax_regime'],
            $tax['fodec_rate'],
            $tax['fodec_amount'],
            $tax['legal_basis'],
            $tax['certificate_reference'],
            $tax['vat'],
            $tax['tax_tnd'],
            $tax['subtotal'],
            $tax['subtotal_tnd'],
            $tax['total'],
            $tax['total_tnd'],
            $itemId
        );
        $updateItem->execute();

        $subtotal = bcadd($subtotal, $tax['subtotal'], 3);
        $vat = bcadd($vat, $tax['vat'], 3);
        $fodec = bcadd($fodec, $tax['fodec_amount'], 3);
        $subtotalTnd = bcadd($subtotalTnd, $tax['subtotal_tnd'], 3);
        $taxTnd = bcadd($taxTnd, $tax['tax_tnd'], 3);
        $itemsTotalTnd = bcadd($itemsTotalTnd, $tax['total_tnd'], 3);
    }
    $updateItem->close();

    $taxableBase = bcadd($subtotal, $fodec, 3);
    $subtotalTtc = bcadd($taxableBase, $vat, 3);
    $stampSign = strtoupper($invoice['invoice_type']) === 'AVOIR' ? '-1' : '1';
    $signedStamp = bcmul((string) $invoice['timbre'], $stampSign, 8);
    $charges = bcadd(
        bcsub((string) $invoice['shipping'], (string) $invoice['discount'], 8),
        $signedStamp,
        8
    );
    $total = money3(bcadd($subtotalTtc, $charges, 8));
    $totalTnd = money3(
        bcadd($itemsTotalTnd, bcmul($charges, (string) $invoice['exchange_rate'], 8), 8)
    );

    $stmt = $conn->prepare(
        'UPDATE erp_invoices
         SET subtotal=?, subtotal_tnd=?, base_tva=?, montant_tva=?, tax_total_tnd=?,
             subtotal_ttc=?, total=?, total_tnd=?
         WHERE id=? AND user_id=?'
    );
    $stmt->bind_param(
        'ddddddddii',
        $subtotal,
        $subtotalTnd,
        $taxableBase,
        $vat,
        $taxTnd,
        $subtotalTtc,
        $total,
        $totalTnd,
        $invoiceId,
        $userId
    );
    $stmt->execute();
    $stmt->close();

    $conn->commit();
    jsonResponse([
        'success' => true,
        'subtotal' => $subtotal,
        'fodec_amount' => $fodec,
        'vat' => $vat,
        'total' => $total,
        'currency' => $invoice['currency'],
        'exchange_rate' => $invoice['exchange_rate'],
        'subtotal_tnd' => $subtotalTnd,
        'tax_total_tnd' => $taxTnd,
        'total_tnd' => $totalTnd,
    ]);
} catch (Throwable $e) {
    if (isset($conn)) {
        try {
            $conn->rollback();
        } catch (Throwable $rollbackError) {
        }
    }
    jsonResponse(['success' => false, 'message' => $e->getMessage()], 400);
}
