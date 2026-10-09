import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/core/payment_input.dart';

void main() {
  test('proof accepts supported files within backend size limit', () {
    for (final name in ['receipt.PDF', 'photo.jpg', 'photo.jpeg', 'photo.png', 'photo.webp']) {
      expect(validPaymentProof(name, 10 * 1024 * 1024), isTrue);
    }
    expect(validPaymentProof('receipt.pdf', 10 * 1024 * 1024 + 1), isFalse);
    expect(validPaymentProof('receipt.pdf', 0), isFalse);
    expect(validPaymentProof('photo.heic', 100), isFalse);
    expect(validPaymentProof('script.php', 100), isFalse);
  });
  bool valid(double amount,
          {String method = 'CASH', String reference = '', double rate = 1}) =>
      validInvoicePayment(
          amount: amount,
          remaining: 100,
          rate: rate,
          method: method,
          reference: reference);
  test('partial and full payments accepted, invalid money rejected', () {
    expect(valid(40), isTrue);
    expect(valid(100), isTrue);
    for (final amount in [0.0, -1.0, 101.0, double.nan, double.infinity]) {
      expect(valid(amount), isFalse);
    }
    expect(valid(10, rate: 0), isFalse);
  });
  test('ledger codes and reference requirements match Angular backend', () {
    for (final method in ['CHEQUE', 'BANK_TRANSFER', 'CARD', 'DRAFT']) {
      expect(valid(10, method: method), isFalse);
      expect(valid(10, method: method, reference: 'TX-42'), isTrue);
    }
    expect(valid(10, method: 'CHECK'), isFalse);
    expect(valid(10, method: 'TRANSFER'), isFalse);
  });
}
