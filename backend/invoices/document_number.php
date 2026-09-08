<?php

/**
 * Creates the sequence storage used by all sales documents.
 * The primary key scopes a sequence to one company/user, document type and year.
 */
function ensureDocumentNumberSequenceSchema(mysqli $conn): void
{
    static $checked = false;
    if ($checked) return;
    $conn->query("SELECT user_id,document_type,document_year,next_number FROM erp_document_number_sequences LIMIT 0");
    $checked = true;
}

function validateDocumentDates(string $documentDate, string $dueDate): void
{
    $date = DateTimeImmutable::createFromFormat('!Y-m-d', $documentDate);
    $dateErrors = DateTimeImmutable::getLastErrors();
    if (!$date || ($dateErrors !== false && ($dateErrors['warning_count'] > 0 || $dateErrors['error_count'] > 0))) {
        throw new Exception('Invalid invoice_date. Expected YYYY-MM-DD.');
    }

    $due = DateTimeImmutable::createFromFormat('!Y-m-d', $dueDate);
    $dueErrors = DateTimeImmutable::getLastErrors();
    if (!$due || ($dueErrors !== false && ($dueErrors['warning_count'] > 0 || $dueErrors['error_count'] > 0))) {
        throw new Exception('Invalid invoice_due_date. Expected YYYY-MM-DD.');
    }

    if ($due < $date) {
        throw new Exception('invoice_due_date cannot be before invoice_date.');
    }
}

/**
 * Reserves and returns a concurrency-safe number such as FAC-2026-000001.
 * LAST_INSERT_ID is connection-local, so simultaneous requests cannot receive
 * the same number.
 */
function nextDocumentNumber(mysqli $conn, int $userId, string $documentType, string $documentDate): string
{
    $type = strtoupper(trim($documentType));
    $prefixes = [
        'FACTURE' => 'FAC',
        'DRAFT' => 'FAC',
        'DEVIS' => 'DEV',
        'AVOIR' => 'AV',
        'BON_COMMANDE' => 'BC',
        'BON_LIVRAISON' => 'BL',
        'BON_SORTIE' => 'BS',
    ];

    if (!isset($prefixes[$type])) {
        throw new Exception('Unsupported document type for numbering.');
    }

    $year = (int)substr($documentDate, 0, 4);
    if ($year < 2000 || $year > 2200) {
        throw new Exception('Invalid document year.');
    }

    $sequenceType = $type === 'DRAFT' ? 'FACTURE' : $type;
    $stmt = $conn->prepare("
        INSERT INTO erp_document_number_sequences (user_id, document_type, document_year, next_number)
        VALUES (?, ?, ?, LAST_INSERT_ID(1))
        ON DUPLICATE KEY UPDATE next_number = LAST_INSERT_ID(next_number + 1)
    ");
    if (!$stmt) {
        throw new Exception('Failed to prepare document number reservation: ' . $conn->error);
    }
    $stmt->bind_param('isi', $userId, $sequenceType, $year);
    $stmt->execute();
    $stmt->close();

    $sequence = (int)$conn->insert_id;
    if ($sequence <= 0) {
        throw new Exception('Failed to reserve a document number.');
    }

    return sprintf('%s-%d-%06d', $prefixes[$type], $year, $sequence);
}
