import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/core/extraction_models.dart';

void main() {
  test('parses the deployed extractor response into typed review data', () {
    final batch = ExtractionBatch.fromJson(
      {
        'summary': {
          'requested': 2,
          'processed': 1,
          'failed': 1,
          'successRate': 50,
          'totalPages': 3,
          'totalInputLabel': '2.4 MB',
          'wallClockMs': 931.5,
        },
        'items': [
          {
            'fileName': 'receipt.jpg',
            'sizeLabel': '300 KB',
            'elapsedMs': 423,
            'success': true,
            'result': {
              'file_name': 'receipt.jpg',
              'invoice_number': 'FAC-2026-14',
              'issue_date': '2026-09-04',
              'due_date': '2026-09-14',
              'supplier_name': 'Supplier SARL',
              'client_name': 'El Fatoura',
              'subtotal': '100.000',
              'tax_amount': 19,
              'total': '119',
              'currency': 'tnd',
              'page_count': 1,
              'raw_text': 'OCR text',
              'items': [
                {
                  'description': 'Paper',
                  'quantity': '2',
                  'unit_price': '50',
                  'total': '100',
                  'confidence': 84,
                },
              ],
              'confidence': {
                'overall': 92,
                'fields': {'invoice_number': 0.98, 'total': 91},
              },
              'warnings': [
                {
                  'code': 'TOTAL_CHECK',
                  'severity': 'warning',
                  'field': 'total',
                  'message': 'Check the detected total.',
                },
              ],
              'validation_status': 'needs_review',
              'review_required': true,
            },
          },
          {
            'fileName': 'bad.pdf',
            'success': false,
            'error': 'Unreadable PDF',
          },
        ],
      },
      sourcePaths: const {'receipt.jpg': '/tmp/receipt.jpg'},
    );

    expect(batch.summary.requested, 2);
    expect(batch.summary.totalPages, 3);
    expect(batch.items, hasLength(2));

    final item = batch.items.first;
    final document = item.document!;
    expect(item.sourcePath, '/tmp/receipt.jpg');
    expect(document.invoiceNumber, 'FAC-2026-14');
    expect(document.total, 119);
    expect(document.currency, 'TND');
    expect(document.overallConfidence, closeTo(.92, .001));
    expect(document.confidenceFor('total'), closeTo(.91, .001));
    expect(document.confidenceFor('missing'), isNull);
    expect(document.items.single.description, 'Paper');
    expect(document.items.single.confidence, closeTo(.84, .001));
    expect(document.warnings.single.code, 'TOTAL_CHECK');
    expect(document.reviewRequired, isTrue);
    expect(batch.items.last.document, isNull);
    expect(batch.items.last.error, 'Unreadable PDF');
  });

  test('supports extractor field aliases and clamps confidence', () {
    final document = ExtractedDocument.fromJson({
      'document_number': 'ALT-1',
      'subtotal_ht': '10.5',
      'vat_total': '2',
      'total_ttc': '12.5',
      'confidence': {
        'overall': 130,
        'fields': {'total': -10},
      },
      'items': [
        {'unit_price_ht': '10.5', 'line_total_ttc': '12.5'},
      ],
    });

    expect(document.invoiceNumber, 'ALT-1');
    expect(document.subtotal, 10.5);
    expect(document.taxAmount, 2);
    expect(document.total, 12.5);
    expect(document.overallConfidence, 1);
    expect(document.confidenceFor('total'), 0);
    expect(document.items.single.unitPrice, 10.5);
    expect(document.items.single.total, 12.5);
    expect(document.reviewRequired, isTrue);
  });
}
