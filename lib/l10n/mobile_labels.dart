import 'app_localizations.dart';

String localizedWorkflowStatus(AppLocalizations l10n, String raw) {
  final status = raw.trim().toUpperCase();
  return switch (status) {
    '' => '',
    'DRAFT' => l10n.statusDraftMobile,
    'OPEN' => l10n.statusOpen,
    'PENDING' => l10n.statusPending,
    'CONFIRMED' => l10n.statusConfirmed,
    'SENT' => l10n.statusSent,
    'PARTIALLY_DELIVERED' => l10n.statusPartiallyDelivered,
    'PARTIALLY_RECEIVED' => l10n.statusPartiallyReceived,
    'DELIVERED' => l10n.statusDelivered,
    'RECEIVED' => l10n.received,
    'REVIEWED' => l10n.statusReviewed,
    'COMPLETED' => l10n.statusCompleted,
    'INVOICED' => l10n.statusInvoiced,
    'PAID' => l10n.statusPaid,
    'UNPAID' => l10n.statusUnpaid,
    'REJECTED' => l10n.statusRejected,
    'CANCELLED' => l10n.statusCancelledMobile,
    _ => status.replaceAll('_', ' '),
  };
}

String localizedSearchType(AppLocalizations l10n, String raw) => switch (raw) {
      'Client' => l10n.client,
      'Product' => l10n.product,
      'Invoice' => l10n.invoice,
      'Expense' => l10n.kindExpense,
      'Supplier' => l10n.supplierLabel,
      'Supplier order' => l10n.kindSupplierOrder,
      _ => raw,
    };

String localizedReceptionException(AppLocalizations l10n, String raw) =>
    switch (raw.trim().toUpperCase()) {
      'NONE' => l10n.none,
      'OVERDELIVERY' => l10n.overdelivery,
      'NO_ORDER' => l10n.noPurchaseOrder,
      final value => value.replaceAll('_', ' '),
    };
