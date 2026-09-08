import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/core/document_center_models.dart';
import 'package:my_app/core/permission_service.dart';
import 'package:my_app/core/user_session.dart';

void main() {
  test('normalizes sales and supplier document response shapes', () {
    final quotation = MobileDocument.fromInvoice({
      'id': 4,
      'invoice': 'DV-004',
      'invoice_type': 'DEVIS',
      'client_name': 'Client A',
      'status': 'SENT',
      'invoice_date': '2026-09-03',
      'total': '120.500',
      'currency': 'TND',
      'is_validated': 1,
    });
    final supplierInvoice = MobileDocument.fromSupplierInvoice({
      'id': 8,
      'invoiceNumber': 'SUP-8',
      'supplierName': 'Supplier B',
      'status': 'VALIDATED',
      'invoiceDate': '2026-09-04',
      'totalTtc': 44,
    });

    expect(quotation.kind, DocumentKind.quotation);
    expect(quotation.party, 'Client A');
    expect(quotation.canPreviewPdf, isTrue);
    expect(supplierInvoice.kind, DocumentKind.supplierInvoice);
    expect(supplierInvoice.number, 'SUP-8');
    expect(supplierInvoice.total, 44);
  });

  test('groups workflow statuses consistently', () {
    final draft = _document('DRAFT');
    final open = _document('PARTIALLY_PAID');
    final completed = _document('PAID');
    final cancelled = _document('CANCELLED');

    expect(documentMatchesStatus(draft, DocumentStatusGroup.draft), isTrue);
    expect(documentMatchesStatus(open, DocumentStatusGroup.open), isTrue);
    expect(documentMatchesStatus(completed, DocumentStatusGroup.completed),
        isTrue);
    expect(documentMatchesStatus(cancelled, DocumentStatusGroup.cancelled),
        isTrue);
    expect(
        documentMatchesStatus(_document('VALIDATED'), DocumentStatusGroup.open),
        isTrue);
  });

  test('document kinds are exposed only by their backend permissions', () {
    const permissions = PermissionService(UserSession(
      userId: 1,
      tenantId: 1,
      companyId: 1,
      membershipId: 1,
      membershipStatus: 'ACTIVE',
      role: 'UNKNOWN',
      permissions: {'supplierOrders.view'},
      user: {},
      company: {},
    ));

    expect(
        canViewDocumentKind(permissions, DocumentKind.supplierOrder), isTrue);
    expect(canViewDocumentKind(permissions, DocumentKind.invoice), isFalse);
  });

  test('date filtering is inclusive', () {
    const document = MobileDocument(
      id: 1,
      kind: DocumentKind.expense,
      number: 'Expense',
      party: '',
      status: 'APPROVED',
      date: '2026-09-04 10:30:00',
      total: 1,
      currency: 'TND',
      raw: {},
    );

    expect(
      documentDateInRange(
        document,
        DateTime(2026, 9, 4),
        DateTime(2026, 9, 4),
      ),
      isTrue,
    );
  });
}

MobileDocument _document(String status) => MobileDocument(
      id: 1,
      kind: DocumentKind.supplierInvoice,
      number: 'D-1',
      party: '',
      status: status,
      date: '2026-09-04',
      total: 0,
      currency: 'TND',
      raw: const {},
    );
