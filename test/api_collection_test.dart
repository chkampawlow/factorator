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

  test('collects every page until the reported total is reached', () async {
    final requestedPages = <int>[];

    final rows = await ApiCollection.collectPages(
      fetchPage: (page, pageSize) async {
        requestedPages.add(page);
        final pages = {
          1: [
            {'id': 1},
            {'id': 2},
          ],
          2: [
            {'id': 3},
            {'id': 4},
          ],
          3: [
            {'id': 5},
          ],
        };
        return {
          'success': true,
          'data': pages[page] ?? const [],
          'page': page,
          'page_size': pageSize,
          'total': 5,
        };
      },
      keys: const ['data'],
      resourceName: 'clients',
      pageSize: 2,
    );

    expect(requestedPages, [1, 2, 3]);
    expect(rows.map((row) => row['id']), [1, 2, 3, 4, 5]);
  });

  test('uses a short final page when an older endpoint omits total', () async {
    final requestedPages = <int>[];

    final rows = await ApiCollection.collectPages(
      fetchPage: (page, pageSize) async {
        requestedPages.add(page);
        return {
          'success': true,
          'data': page == 1
              ? [
                  {'id': 1},
                  {'id': 2},
                ]
              : [
                  {'id': 3},
                ],
          'page_size': pageSize,
        };
      },
      keys: const ['data'],
      resourceName: 'products',
      pageSize: 2,
    );

    expect(requestedPages, [1, 2]);
    expect(rows, hasLength(3));
  });

  test('honors the defensive maximum page count', () async {
    final requestedPages = <int>[];

    final rows = await ApiCollection.collectPages(
      fetchPage: (page, pageSize) async {
        requestedPages.add(page);
        return {
          'success': true,
          'data': [
            {'id': page},
          ],
          'page_size': 1,
          'total': 50,
        };
      },
      keys: const ['data'],
      resourceName: 'invoices',
      pageSize: 1,
      maxPages: 3,
    );

    expect(requestedPages, [1, 2, 3]);
    expect(rows, hasLength(3));
  });
}
