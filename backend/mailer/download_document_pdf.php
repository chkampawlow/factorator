<?php

declare(strict_types=1);

require_once __DIR__ . '/../config/response.php';
require_once __DIR__ . '/../config/db.php';
require_once __DIR__ . '/../config/audit.php';
require_once __DIR__ . '/../auth/auth_required.php';
require_once __DIR__ . '/../auth/role_helper.php';
require_once __DIR__ . '/document_pdf_service.php';

try {
    if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'GET') {
        jsonResponse(['success' => false, 'message' => 'Method not allowed. Use GET.'], 405);
    }

    $auth = requireAuth();
    $tenantId = authTenantId($auth);
    $actorId = authActorId($auth);
    $documentId = (int)($_GET['id'] ?? 0);
    $documentType = strtolower(trim((string)($_GET['type'] ?? '')));
    $language = strtolower(trim((string)($_GET['language'] ?? 'fr')));
    if ($documentType === 'supplier_order') $documentType = 'purchase_order';
    $supported = ['invoice', 'devis', 'credit_note', 'sales_order', 'delivery_note', 'purchase_order'];
    if ($documentId <= 0 || !in_array($documentType, $supported, true)) {
        throw new InvalidArgumentException('A valid document type and id are required.');
    }
    if (!in_array($language, ['en', 'fr', 'ar'], true)) $language = 'fr';

    $conn = db();
    if (in_array($documentType, ['invoice', 'devis', 'credit_note'], true)) {
        $invoiceType = match ($documentType) {
            'devis' => 'DEVIS',
            'credit_note' => 'AVOIR',
            default => 'FACTURE',
        };
        requireInvoiceDocumentPermission($conn, $tenantId, $invoiceType, 'view');
    } elseif ($documentType === 'sales_order') {
        requirePermission($conn, $tenantId, 'orders.view');
    } elseif ($documentType === 'delivery_note') {
        requirePermission($conn, $tenantId, 'deliveries.view');
    } else {
        requirePermission($conn, $tenantId, 'supplierOrders.view');
    }

    $generated = createServerDocumentPdf($conn, $tenantId, $documentType, $documentId, $language);
    $binary = (string)($generated['binary'] ?? '');
    if (!str_starts_with($binary, '%PDF-') || strlen($binary) > 10485760) {
        throw new RuntimeException('The server could not generate this PDF document.');
    }
    $filename = preg_replace('/[^A-Za-z0-9._-]/', '_', (string)($generated['filename'] ?? 'document.pdf')) ?: 'document.pdf';

    try {
        auditLog($conn, $tenantId, $actorId, 'DOCUMENT_PDF.DOWNLOADED', strtoupper($documentType), $documentId, null, [
            'filename' => $filename,
            'language' => $language,
            'size' => strlen($binary),
        ]);
    } catch (Throwable $auditError) {
        structuredLog('WARNING', 'DOCUMENT_PDF.AUDIT_FAILED', ['message' => $auditError->getMessage()]);
    }

    header('Content-Type: application/pdf');
    header('Content-Disposition: inline; filename="' . str_replace('"', '', $filename) . '"');
    header('Content-Length: ' . strlen($binary));
    header('Cache-Control: private, no-store');
    header('X-Content-Type-Options: nosniff');
    echo $binary;
} catch (InvalidArgumentException $error) {
    jsonResponse(['success' => false, 'message' => $error->getMessage(), 'code' => 'INVALID_DOCUMENT_PDF_REQUEST'], 422);
} catch (RuntimeException $error) {
    $message = $error->getMessage();
    jsonResponse(['success' => false, 'message' => $message, 'code' => 'DOCUMENT_PDF_UNAVAILABLE'], str_contains(strtolower($message), 'not found') ? 404 : 409);
} catch (Throwable $error) {
    structuredLog('ERROR', 'DOCUMENT_PDF.DOWNLOAD_FAILED', ['exception' => get_class($error), 'message' => $error->getMessage()]);
    jsonResponse(['success' => false, 'message' => 'Could not generate the document PDF.', 'error_code' => 'DOCUMENT_PDF_FAILED'], 500);
}
