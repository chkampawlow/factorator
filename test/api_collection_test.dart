import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/core/api_collection.dart';

void main() {
  test('parses a bare API collection', () {
    expect(
      ApiCollection.parse(
        [
          {'id': 1},
          {'id': 2},
        ],
        keys: const ['data'],
        resourceName: 'invoices',
      ),
      hasLength(2),
    );
  });

  for (final key in ['data', 'invoices', 'items', 'results']) {
    test('parses the $key envelope', () {
      final parsed = ApiCollection.parse(
        {
          'success': true,
          key: [
            {'id': '17'}
          ],
        },
        keys: const ['data', 'invoices', 'items', 'results'],
        resourceName: 'invoices',
      );

      expect(parsed.single['id'], '17');
    });
  }

  test('preserves a backend failure message', () {
    expect(
      () => ApiCollection.parse(
        {'success': false, 'message': 'Invoice access denied.'},
        keys: const ['data', 'invoices'],
        resourceName: 'invoices',
      ),
      throwsA(
        isA<Exception>().having(
          (error) => error.toString(),
          'message',
          contains('Invoice access denied.'),
        ),
      ),
    );
  });
}
