import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/core/accounting_review.dart';

void main() {
  test('parses authoritative accounting summary and queues', () {
    final snapshot = AccountingReviewSnapshot.fromJson({
      'generatedAt': '2026-09-05T12:00:00+01:00',
      'currency': 'TND',
      'capabilities': {
        'receivables': true,
        'payables': 1,
        'expenses': true,
        'expenseApproval': true,
        'customerPayments': true,
        'withholding': true,
        'supplierPayments': true,
        'supplierCredits': true,
        'supplierReturns': true,
        'reports': true,
      },
      'summary': {
        'receivableCount': '2',
        'receivableBalanceTnd': '300.500',
        'overdueReceivableCount': 1,
        'overdueReceivableTnd': 100,
        'payableCount': 3,
        'payableBalanceTnd': 700,
        'overduePayableCount': 1,
        'overduePayableTnd': 200,
        'matchingIssueCount': 2,
        'pendingExpenseCount': 1,
        'pendingExpenseTnd': 25,
      },
      'receivables': [
        {
          'kind': 'RECEIVABLE',
          'id': 4,
          'title': 'Overdue customer invoice',
          'party': 'Client A',
          'documentNumber': 'FAC-4',
          'date': '2026-08-01',
          'dueDate': '2026-08-31',
          'status': 'OVERDUE',
          'amountTnd': '100.250',
          'entityType': 'INVOICE',
          'entityId': '4',
          'matchStatus': '',
        }
      ],
      'payables': [],
      'expenses': [],
      'activity': [],
    });

    expect(snapshot.summary.receivableCount, 2);
    expect(snapshot.summary.receivableBalanceTnd, 300.5);
    expect(snapshot.capabilities.expenseApproval, isTrue);
    expect(snapshot.receivables.single.kind, AccountingEntryKind.receivable);
    expect(snapshot.receivables.single.isOverdue, isTrue);
    expect(snapshot.receivables.single.entityId, 4);
  });

  test('identifies supplier matching exceptions', () {
    final entry = AccountingReviewEntry.fromJson({
      'kind': 'PAYABLE',
      'id': 8,
      'title': 'Supplier invoice needs matching review',
      'status': 'VALIDATED',
      'amountTnd': 50,
      'entityType': 'SUPPLIER_INVOICE',
      'entityId': 8,
      'matchStatus': 'VARIANCE',
    });

    expect(entry.hasMatchingIssue, isTrue);
    expect(entry.isOverdue, isFalse);
  });
}
