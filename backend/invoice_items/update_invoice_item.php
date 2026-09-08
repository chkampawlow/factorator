<?php
header('Content-Type: application/json');

require_once __DIR__ . '/../config/response.php';
require_once __DIR__ . '/../config/db.php';
require_once __DIR__ . '/../auth/auth_required.php';
require_once __DIR__ . '/../auth/role_helper.php';

require_once __DIR__ . '/../products/product_inventory.php';


function readNumber($data, $key, $fallback = 0.0) {
    if (!isset($data[$key])) {
        return $fallback;
    }

    return (float)str_replace(',', '.', (string)$data[$key]);
}

try {
    if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
        jsonResponse([
            "success" => false,
            "message" => "Method not allowed. Use POST."
        ], 405);
        exit;
    }

    $authUser = requireAuth();
    $user_id = (int)$authUser->id;

    $data = json_decode(file_get_contents("php://input"), true);

    if (!is_array($data)) {
        throw new Exception("Invalid JSON body");
    }

    $id = isset($data['id']) ? (int)$data['id'] : 0;
    $invoice_id = isset($data['invoice_id']) ? (int)$data['invoice_id'] : 0;
    $invoice = isset($data['invoice']) ? trim((string)$data['invoice']) : '';
    $product_id = isset($data['product_id']) ? (int)$data['product_id'] : 0;
    $product_code = isset($data['product_code']) ? trim((string)$data['product_code']) : null;
    $product = isset($data['product']) ? trim((string)$data['product']) : '';
    $qty = readNumber($data, 'qty', 1.0);
    $tva_rate = readNumber($data, 'tva_rate', 0.0);
    $price = readNumber($data, 'price', 0.0);
    $discount = readNumber($data, 'discount', 0.0);
    $invoice_date = isset($data['invoice_date']) ? trim((string)$data['invoice_date']) : '';

    if ($id <= 0) {
        throw new Exception("Invalid item id");
    }

    if ($invoice_id <= 0) {
        throw new Exception("Invalid invoice_id");
    }

    if ($product === '') {
        throw new Exception("Product is required");
    }

    if ($qty < 0) {
        throw new Exception("Invalid quantity");
    }

    if ($price < 0) {
        throw new Exception("Invalid price");
    }

    if ($discount < 0) {
        $discount = 0.0;
    }
    if ($discount > 100) {
        $discount = 100.0;
    }

    if ($tva_rate < 0) {
        $tva_rate = 0.0;
    }

    $htBeforeDiscount = $qty * $price;
    $discountValue = $htBeforeDiscount * ($discount / 100.0);
    $subtotal = round(max($htBeforeDiscount - $discountValue, 0), 3);
    $montant_tva = round($subtotal * ($tva_rate / 100.0), 3);
    $subtotalTTC = round($subtotal + $montant_tva, 3);

    $conn = db();
    ensureProductInventorySchema($conn);

    $check = $conn->prepare("
        SELECT eii.id, ei.invoice, ei.invoice_date, ei.invoice_type, IFNULL(ei.is_validated, 0) AS is_validated
        FROM erp_invoice_items eii
        INNER JOIN erp_invoices ei
            ON ei.id = eii.invoice_id
        WHERE eii.id = ?
          AND eii.invoice_id = ?
          AND ei.user_id = ?
        LIMIT 1
    ");

    if (!$check) {
        throw new Exception("Failed to prepare item lookup: " . $conn->error);
    }

    $check->bind_param("iii", $id, $invoice_id, $user_id);
    $check->execute();
    $itemRow = $check->get_result()->fetch_assoc();
    $check->close();

    if (!$itemRow) {
        throw new Exception("Invoice item not found or not allowed");
    }

    $invoiceType = strtoupper((string)($itemRow['invoice_type'] ?? 'FACTURE'));
    requireInvoiceDocumentPermission($conn, $user_id, $invoiceType, 'edit');

    if ((int)$itemRow['is_validated'] === 1) {
        throw new Exception("Validated invoices cannot be changed");
    }

    if ($invoice === '') {
        $invoice = (string)$itemRow['invoice'];
    }

    if ($invoice_date === '') {
        $invoice_date = (string)$itemRow['invoice_date'];
    }

    $product_id = resolveProductIdForUser($conn, $user_id, $product_id, $product_code, $product);
    $documentSign = $invoiceType === 'AVOIR' ? -1.0 : 1.0;
    $subtotal *= $documentSign;
    $montant_tva = round($subtotal * ($tva_rate / 100.0), 3);
    $subtotalTTC = round($subtotal + $montant_tva, 3);

    $stmt = $conn->prepare("
        UPDATE erp_invoice_items
        SET
            invoice = ?,
            product_id = NULLIF(?, 0),
            product_code = ?,
            product = ?,
            qty = ?,
            tva_rate = ?,
            montant_tva = ?,
            price = ?,
            discount = ?,
            subtotal = ?,
            subtotalTTC = ?,
            invoice_date = ?
        WHERE id = ? AND invoice_id = ?
        LIMIT 1
    ");

    if (!$stmt) {
        throw new Exception("Failed to prepare invoice item update: " . $conn->error);
    }

    $stmt->bind_param(
        "sissdddddddsii",
        $invoice,
        $product_id,
        $product_code,
        $product,
        $qty,
        $tva_rate,
        $montant_tva,
        $price,
        $discount,
        $subtotal,
        $subtotalTTC,
        $invoice_date,
        $id,
        $invoice_id
    );

    $stmt->execute();

    if ($stmt->error) {
        throw new Exception("Failed to update invoice item: " . $stmt->error);
    }

    $affected = $stmt->affected_rows;
    $stmt->close();

    jsonResponse([
        "success" => true,
        "id" => $id,
        "invoice_id" => $invoice_id,
        "affected_rows" => $affected,
        "qty" => $qty,
        "tva_rate" => $tva_rate,
        "montant_tva" => $montant_tva,
        "price" => $price,
        "discount" => $discount,
        "subtotal" => $subtotal,
        "subtotalTTC" => $subtotalTTC,
        "invoice_date" => $invoice_date,
        "message" => "Invoice item updated successfully"
    ]);
} catch (Throwable $e) {
    jsonResponse([
        "success" => false,
        "message" => $e->getMessage()
    ], 400);
}
?>
