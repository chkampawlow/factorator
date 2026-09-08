<?php

require_once __DIR__ . '/../auth/role_helper.php';

function enforceInvoiceDatePolicy(mysqli $conn, int $userId, string $invoiceDate): void
{
    $date = DateTimeImmutable::createFromFormat('!Y-m-d', $invoiceDate);
    $errors = DateTimeImmutable::getLastErrors();
    if (!$date || ($errors !== false && ($errors['warning_count'] > 0 || $errors['error_count'] > 0))) {
        throw new Exception('Invalid invoice_date. Expected YYYY-MM-DD.');
    }

    $closed = $conn->prepare("
        SELECT id
        FROM erp_accounting_periods
        WHERE user_id = ? AND status IN ('LOCKED','FILED') AND ? BETWEEN period_start AND period_end
        LIMIT 1
    ");
    if (!$closed) {
        throw new Exception('Failed to verify the accounting period: ' . $conn->error);
    }
    $dateValue = $date->format('Y-m-d');
    $closed->bind_param('is', $userId, $dateValue);
    $closed->execute();
    $closedPeriod = $closed->get_result()->fetch_assoc();
    $closed->close();
    if ($closedPeriod) {
        throw new Exception('This accounting period is locked or filed; documents in it are immutable.');
    }

    $today = new DateTimeImmutable('today', new DateTimeZone('Africa/Tunis'));
    if ($date < $today && !userHasPermission($conn, $userId, 'invoices.backdate')) {
        throw new Exception('Only accounting users can backdate an invoice.');
    }
}
