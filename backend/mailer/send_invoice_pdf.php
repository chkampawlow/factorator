<?php

declare(strict_types=1);

header('Content-Type: application/json; charset=utf-8');
header('Cache-Control: no-store, private');

ini_set('display_errors', '0');
ini_set('log_errors', '1');
error_reporting(E_ALL);

require_once __DIR__ . '/../config/response.php';
require_once __DIR__ . '/../config/db.php';
require_once __DIR__ . '/../config/audit.php';
require_once __DIR__ . '/../auth/auth_required.php';
require_once __DIR__ . '/../auth/role_helper.php';
require_once __DIR__ . '/../invoices/document_number.php';
require_once __DIR__ . '/../invoices/issuance_snapshot_service.php';
require_once __DIR__ . '/mailer.php';
require_once __DIR__ . '/document_pdf_service.php';

$conn = null;
$documentEmailTransactionActive = false;
$devisStatusChanged = false;
$devisPreviousState = null;

try {
    if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'POST') {
        jsonResponse([
            'success' => false,
            'message' => 'Method not allowed. Use POST.',
            'code' => 'METHOD_NOT_ALLOWED',
        ], 405);
    }

    if ((int)($_SERVER['CONTENT_LENGTH'] ?? 0) > 65536) {
        throw new InvalidArgumentException('The email request is too large.');
    }

    $authUser = requireAuth();
    $tenantId = authTenantId($authUser);
    $actorId = authActorId($authUser);
    $userId = $actorId;
    $conn = db();

    $data = json_decode((string)file_get_contents('php://input'), true);
    if (!is_array($data)) {
        throw new InvalidArgumentException('Invalid JSON body.');
    }
    if (array_key_exists('pdf', $data) || array_key_exists('filename', $data)) {
        throw new InvalidArgumentException('Browser-generated PDF content is not accepted.');
    }

    $to = trim((string)($data['email'] ?? $authUser->email ?? ''));
    if (!filter_var($to, FILTER_VALIDATE_EMAIL)) {
        throw new InvalidArgumentException('A valid recipient email is required.');
    }

    $language = strtolower(trim((string)($data['language'] ?? 'fr')));
    if (!in_array($language, ['en', 'fr', 'ar'], true)) {
        $language = 'fr';
    }

    $documentType = strtolower(trim((string)($data['document_type'] ?? 'invoice')));
    if ($documentType === 'supplier_order') {
        $documentType = 'purchase_order';
    }
    if (!in_array($documentType, ['invoice', 'devis', 'credit_note', 'sales_order', 'delivery_note', 'purchase_order'], true)) {
        throw new InvalidArgumentException('Unsupported document type.');
    }

    $documentId = (int)($data['document_id'] ?? 0);
    if ($documentId <= 0) {
        throw new InvalidArgumentException('A saved document is required before sending.');
    }

    if (in_array($documentType, ['invoice', 'devis', 'credit_note'], true)) {
        $documentStmt = $conn->prepare("SELECT invoice_type,status,IFNULL(is_validated,0) is_validated
            FROM erp_invoices WHERE id=? AND user_id=? LIMIT 1");
        $documentStmt->bind_param('ii', $documentId, $tenantId);
        $documentStmt->execute();
        $documentRow = $documentStmt->get_result()->fetch_assoc();
        $documentStmt->close();
        if (!$documentRow) {
            throw new RuntimeException('Document not found.');
        }

        $actualType = strtoupper(trim((string)$documentRow['invoice_type']));
        $actualStatus = strtoupper(trim((string)$documentRow['status']));
        $allowedActualTypes = match ($documentType) {
            'devis' => ['DEVIS'],
            'credit_note' => ['AVOIR'],
            default => ['FACTURE', 'DRAFT'],
        };
        if (!in_array($actualType, $allowedActualTypes, true)) {
            throw new RuntimeException('The saved document type does not match the requested document type.');
        }
        requireInvoiceDocumentPermission($conn, $userId, $actualType, 'send');
        if ($actualStatus === 'CANCELLED') {
            throw new RuntimeException('A cancelled document cannot be sent.');
        }
        $isValidated = (int)$documentRow['is_validated'] === 1;
        if ($actualType === 'DRAFT' || ($actualType !== 'DEVIS' && !$isValidated)) {
            throw new RuntimeException('Only an issued document can be sent.');
        }
        if ($actualType === 'DEVIS' && $actualStatus !== 'DRAFT' && !$isValidated) {
            throw new RuntimeException('Only an issued quotation can be sent.');
        }
    } elseif ($documentType === 'sales_order') {
        requirePermission($conn, $userId, 'orders.send');
    } elseif ($documentType === 'delivery_note') {
        requirePermission($conn, $userId, 'deliveries.send');
    } else {
        requirePermission($conn, $userId, 'supplierOrders.send');
    }

    /*
     * AUTO_SEND_DEVIS: emailing a saved draft devis is the issuance action.
     * Keep the status/number change and authoritative PDF generation in one
     * transaction. An SMTP or renderer failure rolls the devis back to DRAFT.
     */
    if ($documentType === 'devis') {
        $conn->begin_transaction();
        $documentEmailTransactionActive = true;

        $devisStmt = $conn->prepare("SELECT id, invoice, invoice_date, invoice_type, status,
            IFNULL(is_validated, 0) is_validated
            FROM erp_invoices WHERE id = ? AND user_id = ? LIMIT 1 FOR UPDATE");
        $devisStmt->bind_param('ii', $documentId, $tenantId);
        $devisStmt->execute();
        $devis = $devisStmt->get_result()->fetch_assoc();
        $devisStmt->close();

        if (!$devis) {
            throw new RuntimeException('Document not found.');
        }
        if (strtoupper((string)$devis['invoice_type']) !== 'DEVIS') {
            throw new RuntimeException('The saved document type does not match the requested document type.');
        }

        $devisStatus = strtoupper((string)$devis['status']);
        if ($devisStatus === 'DRAFT') {
            $devisPreviousState = $devis;
            $devisNumber = nextDocumentNumber($conn, $tenantId, 'DEVIS', (string)$devis['invoice_date']);
            $statusStmt = $conn->prepare("UPDATE erp_invoices
                SET status = 'SENT', is_validated = 1, invoice = ?
                WHERE id = ? AND user_id = ? AND invoice_type = 'DEVIS' AND status = 'DRAFT'");
            $statusStmt->bind_param('sii', $devisNumber, $documentId, $tenantId);
            $statusStmt->execute();
            if ($statusStmt->affected_rows !== 1) {
                $statusStmt->close();
                throw new RuntimeException('The devis status changed before it could be sent.');
            }
            $statusStmt->close();

            $itemNumberStmt = $conn->prepare('UPDATE erp_invoice_items SET invoice = ?, invoice_date = ? WHERE invoice_id = ?');
            $itemNumberStmt->bind_param('ssi', $devisNumber, $devis['invoice_date'], $documentId);
            $itemNumberStmt->execute();
            $itemNumberStmt->close();
            captureInvoiceIssuanceSnapshot($conn, $tenantId, $actorId, $documentId);
            $devisStatusChanged = true;
        } elseif (!in_array($devisStatus, ['SENT', 'ACCEPTED', 'REJECTED'], true)) {
            throw new RuntimeException('This quotation cannot be sent in its current state.');
        }
    }

    if (in_array($documentType, ['invoice', 'devis', 'credit_note'], true)
        && invoiceSnapshotLoad($conn, $tenantId, $documentId) === null) {
        // Preserve legacy issued documents before their next trusted reconstruction.
        captureInvoiceIssuanceSnapshot($conn, $tenantId, $actorId, $documentId);
    }

    $generated = createServerDocumentPdf($conn, $tenantId, $documentType, $documentId, $language);
    $pdfBinary = (string)$generated['binary'];
    $filename = (string)$generated['filename'];
    if (!str_starts_with($pdfBinary, '%PDF-')) {
        throw new RuntimeException('The server could not generate the PDF document.');
    }
    if (strlen($pdfBinary) > 10485760) {
        throw new RuntimeException('The generated PDF exceeds the 10 MB limit.');
    }

    sendInvoicePdf($to, $pdfBinary, $filename, $language, $documentType);

    try {
        auditLog(
            $conn,
            $tenantId,
            $actorId,
            'DOCUMENT_EMAIL.SENT',
            strtoupper($documentType),
            $documentId,
            $devisPreviousState,
            [
                'document_type' => $documentType,
                'email' => $to,
                'filename' => $filename,
                'pdf_source' => 'SERVER_DATABASE',
                'status_transition' => $devisStatusChanged ? 'DRAFT_TO_SENT' : null,
            ]
        );
    } catch (Throwable $auditError) {
        if (function_exists('structuredLog')) {
            structuredLog('WARNING', 'DOCUMENT_EMAIL.AUDIT_FAILED', [
                'message' => $auditError->getMessage(),
                'email' => $to,
                'document_type' => $documentType,
                'document_id' => $documentId,
            ]);
        }
    }

    if ($documentEmailTransactionActive) {
        $conn->commit();
        $documentEmailTransactionActive = false;
    }

    jsonResponse([
        'success' => true,
        'message' => 'Email sent successfully.',
        'delivery' => [
            'status' => 'SENT',
            'email' => $to,
            'filename' => $filename,
            'document_type' => $documentType,
            'document_id' => $documentId,
            'document_number' => (string)($generated['document']['number'] ?? ''),
            'document_status' => (string)($generated['document']['status'] ?? ''),
            'pdf_source' => 'SERVER_DATABASE',
        ],
    ]);
} catch (InvalidArgumentException $e) {
    if ($documentEmailTransactionActive && $conn instanceof mysqli) {
        try { $conn->rollback(); } catch (Throwable) {}
        $documentEmailTransactionActive = false;
    }
    jsonResponse([
        'success' => false,
        'message' => $e->getMessage(),
        'code' => 'INVALID_EMAIL_REQUEST',
    ], 422);
} catch (RuntimeException $e) {
    if ($documentEmailTransactionActive && $conn instanceof mysqli) {
        try { $conn->rollback(); } catch (Throwable) {}
        $documentEmailTransactionActive = false;
    }
    $message = $e->getMessage();
    jsonResponse([
        'success' => false,
        'message' => $message,
        'code' => 'DOCUMENT_EMAIL_REJECTED',
    ], str_contains(strtolower($message), 'not found') ? 404 : 409);
} catch (Throwable $e) {
    if ($documentEmailTransactionActive && $conn instanceof mysqli) {
        try { $conn->rollback(); } catch (Throwable) {}
        $documentEmailTransactionActive = false;
    }
    if (function_exists('structuredLog')) {
        structuredLog('ERROR', 'DOCUMENT_EMAIL.FAILED', [
            'message' => $e->getMessage(),
            'file' => $e->getFile(),
            'line' => $e->getLine(),
        ]);
    }
    jsonResponse([
        'success' => false,
        'message' => 'The email could not be sent. Please try again.',
        'code' => 'DOCUMENT_EMAIL_FAILED',
    ], 500);
}
