import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/core/client_identity.dart';

void main() {
  test('company clients expose their MF across supported API aliases', () {
    expect(clientIsCompany({'type': 'company'}), isTrue);
    expect(clientIsCompany({'type': 'entreprise'}), isTrue);
    expect(clientFiscalId({'fiscal_id': '1234567a'}), '1234567A');
    expect(clientFiscalId({'mf': '7654321b'}), '7654321B');
  });

  test('individual clients expose their CIN', () {
    expect(clientIsCompany({'type': 'individual'}), isFalse);
    expect(clientIsCompany({'type': 'person'}), isFalse);
    expect(clientIsCompany({'type': 'particulier'}), isFalse);
    expect(clientCin({'cin': '01234567'}), '01234567');
  });

  test('client phone creates a native dialer URI', () {
    expect(
      clientPhoneUri({'phone': '+216 20 123 456'}).toString(),
      'tel:+21620123456',
    );
    expect(clientPhoneUri({'telephone': '(71) 123-456'}).toString(),
        'tel:71123456');
    expect(clientPhoneUri({'phone': '123'}), isNull);
    expect(clientPhoneUri({'phone': ''}), isNull);
  });
}
