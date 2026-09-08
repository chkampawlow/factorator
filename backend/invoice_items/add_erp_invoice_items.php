<?php
header('Content-Type: application/json');

require_once __DIR__ . '/../config/response.php';
require_once __DIR__ . '/../config/db.php';
require_once __DIR__ . '/../auth/auth_required.php';
require_once __DIR__ . '/../auth/role_helper.php';


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

    $raw = file_get_contents("php://input");
    $data = json_decode($raw, true);

    if (!is_array($data)) {
        throw new Exception("Invalid JSON body");
    }

    $invoice_id = (int)($data["invoice_id"] ?? 0);
    $items = $data["items"] ?? [];

    if ($invoice_id <= 0) {
        throw new Exception("invoice_id is required");
    }

    if (!is_array($items) || count($items) === 0) {
        throw new Exception("No items provided");
    }

    $conn = db();

    $check = $conn->prepare("
        SELECT id, invoice, invoice_date, invoice_type, IFNULL(is_validated, 0) AS is_validated
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

    requireInvoiceDocumentPermission($conn, $user_id, $invoiceRow['invoice_type'] ?? 'FACTURE', 'edit');

    if ((int)$invoiceRow['is_validated'] === 1) {
        throw new Exception("Validated invoices cannot be changed");
    }

    $invoice = (string)$invoiceRow["invoice"];
    $invoice_date = $invoiceRow["invoice_date"];

    $stmt = $conn->prepare("
        INSERT INTO erp_invoice_items (
            invoice_id,
            invoice,
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
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ");

    $insertedCount = 0;

    foreach ($items as $item) {
        $product_code = trim((string)($item["product_code"] ?? ""));
        $product = trim((string)($item["product"] ?? ""));
        $qty = (float)($item["qty"] ?? 1);
        $price = (float)($item["price"] ?? 0);
        $discount = (float)($item["discount"] ?? 0);
        $tva_rate = (float)($item["tva_rate"] ?? 0);

        if ($product === "") {
            throw new Exception("Each item must have a product name");
        }

        if ($qty <= 0) {
            throw new Exception("Each item must have qty > 0");
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

        $subtotal = $qty * $price;

        if ($discount > 0) {
            $subtotal -= ($subtotal * ($discount / 100));
        }

        $montant_tva = $subtotal * ($tva_rate / 100);
        $subtotalTTC = $subtotal + $montant_tva;

        $stmt->bind_param(
            "isssddddddds",
            $invoice_id,
            $invoice,
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
        $insertedCount++;
    }

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

    $subtotal = (float)$totals["sum_subtotal"];
    $montant_tva = (float)$totals["sum_tva"];
    $subtotal_ttc = (float)$totals["sum_ttc"];
    $total = $subtotal_ttc;

    $upd = $conn->prepare("
        UPDATE erp_invoices
        SET subtotal = ?, montant_tva = ?, subtotal_ttc = ?, total = ?
        WHERE id = ? AND user_id = ?
    ");
    $upd->bind_param(
        "ddddii",
        $subtotal,
        $montant_tva,
        $subtotal_ttc,
        $total,
        $invoice_id,
        $user_id
    );
    $upd->execute();
    $upd->close();

    jsonResponse([
        "success" => true,
        "message" => "Invoice items inserted successfully",
        "count" => $insertedCount,
        "invoice_id" => $invoice_id,
        "totals" => [
            "subtotal" => $subtotal,
            "montant_tva" => $montant_tva,
            "subtotal_ttc" => $subtotal_ttc,
            "total" => $total
        ]
    ]);
} catch (Throwable $e) {
    jsonResponse([
        "success" => false,
        "message" => $e->getMessage()
    ], 400);
}
