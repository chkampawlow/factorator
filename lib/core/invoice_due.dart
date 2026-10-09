bool hasInvoicePaymentDue(String type, String status) =>
    type.trim().toUpperCase() == 'FACTURE' &&
    ['UNPAID', 'OPEN', 'PARTIAL', 'PARTIALLY_PAID', 'OVERDUE']
        .contains(status.trim().toUpperCase());
