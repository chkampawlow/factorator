<?php
header('Content-Type: application/json');

require_once __DIR__ . '/../config/response.php';
require_once __DIR__ . '/../config/db.php';
require_once __DIR__ . '/../auth/auth_required.php';
require_once __DIR__ . '/../auth/role_helper.php';

require_once __DIR__ . '/../products/product_inventory.php';

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

    $invoice_id   = isset($data['invoice_id']) ? (int)$data['invoice_id'] : 0;
    $product_id   = isset($data['product_id']) ? (int)$data['product_id'] : 0;
    $product_code = isset($data['product_code']) ? trim((string)$data['product_code']) : '';
    $product      = isset($data['product']) ? trim((string)$data['product']) : '';
    $qty          = isset($data['qty']) ? (float)$data['qty'] : 0;
    $tva_rate     = isset($data['tva_rate']) ? (float)$data['tva_rate'] : 0;
    $price        = isset($data['price']) ? (float)$data['price'] : 0;
    $discount     = isset($data['discount']) ? (float)$data['discount'] : 0;

    if ($invoice_id <= 0) {
        throw new Exception("Invalid invoice_id");
    }

    if ($product === '') {
        throw new Exception("Product name is required");
    }

    if ($qty <= 0) {
        throw new Exception("Quantity must be greater than 0");
    }

    if ($price < 0) {
        throw new Exception("Price cannot be negative");
    }

    if ($discount < 0 || $discount > 100) {
        throw new Exception("Discount must be between 0 and 100");
    }

    if ($tva_rate < 0) {
        throw new Exception("TVA rate cannot be negative");
    }

    $conn = db();
    ensureProductInventorySchema($conn);

    $check = $conn->prepare("
        SELECT id, invoice, invoice_date, invoice_type, IFNULL(timbre, 0) AS timbre, IFNULL(is_validated, 0) AS is_validated
        FROM erp_invoices
        WHERE id = ? AND user_id = ?
        LIMIT 1
    ");
    $check->bind_param("ii", $invoice_id, $user_id);
    $check->execute();
    $invoiceRow = $check->get_result()->fetch_assoc();
    $check->close();

    if (!$invoiceRow) {
        throw new Exception("Invoice not found or not allowed");
    }

    $invoiceType = strtoupper((string)($invoiceRow['invoice_type'] ?? 'FACTURE'));
    requireInvoiceDocumentPermission($conn, $user_id, $invoiceType, 'edit');

    if ((int)$invoiceRow['is_validated'] === 1) {
        throw new Exception("Validated invoices cannot be changed");
    }

    $invoice = (string)$invoiceRow['invoice'];
    $invoice_date = $invoiceRow['invoice_date'];
    $documentSign = $invoiceType === 'AVOIR' ? -1.0 : 1.0;
    $timbre = (float)($invoiceRow['timbre'] ?? 0);
    $product_id = resolveProductIdForUser($conn, $user_id, $product_id, $product_code, $product);

    $subtotal = $qty * $price;
    if ($discount > 0) {
        $subtotal -= ($subtotal * ($discount / 100));
    }
    $subtotal *= $documentSign;

    $montant_tva = $subtotal * ($tva_rate / 100);
    $subtotalTTC = $subtotal + $montant_tva;

    $stmt = $conn->prepare("
        INSERT INTO erp_invoice_items (
            invoice_id,
            invoice,
            product_id,
            product_code,
            product,
            qty,
            tva_rate,
            montant_tva,
            price,
            discount,
            subtotal,
            subtotalTTC,
            invoice_date
        ) VALUES (?, ?, NULLIF(?, 0), ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ");

    $stmt->bind_param(
        "isissddddddds",
        $invoice_id,
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
        $invoice_date
    );

    $stmt->execute();
    $itemId = $stmt->insert_id;
    $stmt->close();

    $sumStmt = $conn->prepare("
        SELECT
            COALESCE(SUM(subtotal), 0) AS sum_subtotal,
            COALESCE(SUM(montant_tva), 0) AS sum_tva,
            COALESCE(SUM(subtotalTTC), 0) AS sum_ttc
        FROM erp_invoice_items
        WHERE invoice_id = ?
    ");
    $sumStmt->bind_param("i", $invoice_id);
    $sumStmt->execute();
    $totals = $sumStmt->get_result()->fetch_assoc();
    $sumStmt->close();

    $sumSubtotal = (float)$totals['sum_subtotal'];
    $sumTva = (float)$totals['sum_tva'];
    $sumTtc = (float)$totals['sum_ttc'];
    $total = $sumTtc + ($timbre * $documentSign);

    $upd = $conn->prepare("
        UPDATE erp_invoices
        SET subtotal = ?, montant_tva = ?, subtotal_ttc = ?, total = ?
        WHERE id = ? AND user_id = ?
    ");
    $upd->bind_param(
        "ddddii",
        $sumSubtotal,
        $sumTva,
        $sumTtc,
        $total,
        $invoice_id,
        $user_id
    );
    $upd->execute();
    $upd->close();

    jsonResponse([
        "success" => true,
        "id" => $itemId,
        "message" => "Invoice item added successfully",
        "invoice_id" => $invoice_id,
        "item" => [
            "invoice" => $invoice,
            "product_id" => $product_id,
            "product_code" => $product_code,
            "product" => $product,
            "qty" => $qty,
            "tva_rate" => $tva_rate,
            "montant_tva" => $montant_tva,
            "price" => $price,
            "discount" => $discount,
            "subtotal" => $subtotal,
            "subtotalTTC" => $subtotalTTC,
            "invoice_date" => $invoice_date
        ],
        "totals" => [
            "subtotal" => $sumSubtotal,
            "montant_tva" => $sumTva,
            "subtotal_ttc" => $sumTtc,
            "total" => $total
        ]
    ]);
} catch (Throwable $e) {
    jsonResponse([
        "success" => false,
        "message" => $e->getMessage()
    ], 400);
}
?>
