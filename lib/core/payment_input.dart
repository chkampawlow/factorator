bool validInvoicePayment({
  required double? amount,
  required double? remaining,
  required double? rate,
  required String method,
  required String reference,
}) {
  if (amount == null ||
      !amount.isFinite ||
      amount <= 0 ||
      remaining == null ||
      !remaining.isFinite ||
      amount > remaining + .0005 ||
      rate == null ||
      !rate.isFinite ||
      rate <= 0) {
    return false;
  }
  if (!['CASH', 'CHEQUE', 'BANK_TRANSFER', 'CARD', 'DRAFT', 'OTHER']
      .contains(method)) {
    return false;
  }
  return !['CHEQUE', 'BANK_TRANSFER', 'CARD', 'DRAFT'].contains(method) ||
      reference.trim().isNotEmpty;
}

bool validPaymentProof(String name, int size) =>
    size > 0 &&
    size <= 10 * 1024 * 1024 &&
    ['pdf', 'jpg', 'jpeg', 'png', 'webp']
        .contains(name.split('.').last.toLowerCase());
