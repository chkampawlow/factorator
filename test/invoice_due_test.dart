import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/core/invoice_due.dart';

void main() {
  test('quotations and credits never have invoice payment due warnings', () {
    for (final type in ['DEVIS', 'AVOIR', 'DRAFT']) {
      for (final status in [
        'UNPAID',
        'SENT',
        'ACCEPTED',
        'REJECTED',
        'DRAFT'
      ]) {
        expect(hasInvoicePaymentDue(type, status), isFalse);
      }
    }
  });
  test('only unpaid customer invoices have payment due warnings', () {
    expect(hasInvoicePaymentDue('FACTURE', 'UNPAID'), isTrue);
    expect(hasInvoicePaymentDue('FACTURE', 'PARTIALLY_PAID'), isTrue);
    for (final status in ['DRAFT', 'PAID', 'CANCELLED', 'SENT', '']) {
      expect(hasInvoicePaymentDue('FACTURE', status), isFalse);
    }
  });
}
