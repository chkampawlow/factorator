import 'permission_service.dart';

enum DocumentKind {
  invoice,
  quotation,
  creditNote,
  salesOrder,
  deliveryNote,
  supplierOrder,
  supplierReception,
  supplierInvoice,
  expense,
}

extension DocumentKindDetails on DocumentKind {
  String get label => switch (this) {
        DocumentKind.invoice => 'Invoice',
        DocumentKind.quotation => 'Quotation',
        DocumentKind.creditNote => 'Credit note',
        DocumentKind.salesOrder => 'Sales order',
        DocumentKind.deliveryNote => 'Delivery note',
        DocumentKind.supplierOrder => 'Supplier PO',
        DocumentKind.supplierReception => 'Supplier reception',
        DocumentKind.supplierInvoice => 'Supplier invoice',
        DocumentKind.expense => 'Expense',
      };

  String? get pdfType => switch (this) {
        DocumentKind.invoice => 'invoice',
        DocumentKind.quotation => 'devis',
        DocumentKind.creditNote => 'credit_note',
        DocumentKind.salesOrder => 'sales_order',
        DocumentKind.deliveryNote => 'delivery_note',
        DocumentKind.supplierOrder => 'purchase_order',
        _ => null,
      };
}

enum DocumentStatusGroup { all, draft, open, completed, cancelled }

extension DocumentStatusGroupDetails on DocumentStatusGroup {
  String get label => switch (this) {
        DocumentStatusGroup.all => 'All statuses',
        DocumentStatusGroup.draft => 'Draft',
        DocumentStatusGroup.open => 'Open',
        DocumentStatusGroup.completed => 'Completed',
        DocumentStatusGroup.cancelled => 'Cancelled',
      };
}

class MobileDocument {
  const MobileDocument({
    required this.id,
    required this.kind,
    required this.number,
    required this.party,
    required this.status,
    required this.date,
    required this.total,
    required this.currency,
    required this.raw,
    this.dueDate = '',
  });

  final int id;
  final DocumentKind kind;
  final String number;
  final String party;
  final String status;
  final String date;
  final String dueDate;
  final double total;
  final String currency;
  final Map<String, dynamic> raw;

  String get key => '${kind.name}:$id';

  bool get canPreviewPdf {
    if (kind.pdfType == null) return false;
    final normalized = status.toUpperCase();
    if (normalized == 'CANCELLED' || normalized == 'DRAFT') return false;
    return switch (kind) {
      DocumentKind.invoice ||
      DocumentKind.creditNote =>
        _truthy(raw['is_validated']),
      DocumentKind.quotation => _truthy(raw['is_validated']) &&
          const {'SENT', 'ACCEPTED', 'REJECTED'}.contains(normalized),
      DocumentKind.salesOrder => const {
          'CONFIRMED',
          'PARTIALLY_DELIVERED',
          'DELIVERED',
          'INVOICED',
        }.contains(normalized),
      DocumentKind.deliveryNote =>
        const {'CONFIRMED', 'DELIVERED'}.contains(normalized),
      DocumentKind.supplierOrder => const {
          'SENT',
          'PARTIALLY_RECEIVED',
          'RECEIVED',
        }.contains(normalized),
      _ => false,
    };
  }

  static MobileDocument fromInvoice(Map<String, dynamic> row) {
    final invoiceType = '${row['invoice_type'] ?? 'FACTURE'}'.toUpperCase();
    final kind = switch (invoiceType) {
      'DEVIS' => DocumentKind.quotation,
      'AVOIR' => DocumentKind.creditNote,
      _ => DocumentKind.invoice,
    };
    return MobileDocument(
      id: _integer(row['id']),
      kind: kind,
      number: '${row['invoice'] ?? ''}',
      party: '${row['client_name'] ?? row['custom_name'] ?? ''}',
      status: '${row['status'] ?? ''}',
      date: '${row['invoice_date'] ?? ''}',
      dueDate: '${row['invoice_due_date'] ?? ''}',
      total: _number(row['total_tnd'] ?? row['total']),
      currency: '${row['currency'] ?? 'TND'}',
      raw: row,
    );
  }

  static MobileDocument fromSalesOrder(Map<String, dynamic> row) =>
      MobileDocument(
        id: _integer(row['id']),
        kind: DocumentKind.salesOrder,
        number: '${row['order_number'] ?? ''}',
        party: '${row['client_name'] ?? ''}',
        status: '${row['status'] ?? ''}',
        date: '${row['order_date'] ?? row['created_at'] ?? ''}',
        dueDate: '${row['expected_delivery_date'] ?? ''}',
        total: _number(row['total']),
        currency: '${row['currency'] ?? 'TND'}',
        raw: row,
      );

  static MobileDocument fromDelivery(Map<String, dynamic> row) =>
      MobileDocument(
        id: _integer(row['id']),
        kind: DocumentKind.deliveryNote,
        number: '${row['delivery_number'] ?? ''}',
        party: '${row['client_name'] ?? ''}',
        status: '${row['status'] ?? ''}',
        date: '${row['delivery_date'] ?? row['created_at'] ?? ''}',
        dueDate: '${row['expected_delivery_date'] ?? ''}',
        total: _number(row['total']),
        currency: '${row['currency'] ?? 'TND'}',
        raw: row,
      );

  static MobileDocument fromSupplierOrder(Map<String, dynamic> row) =>
      MobileDocument(
        id: _integer(row['id']),
        kind: DocumentKind.supplierOrder,
        number: '${row['orderNumber'] ?? row['order_number'] ?? ''}',
        party: '${row['supplierName'] ?? row['supplier_name'] ?? ''}',
        status: '${row['status'] ?? ''}',
        date: '${row['orderDate'] ?? row['order_date'] ?? ''}',
        dueDate: '${row['expectedDate'] ?? row['expected_date'] ?? ''}',
        total: _number(row['total']),
        currency: '${row['currency'] ?? 'TND'}',
        raw: row,
      );

  static MobileDocument fromSupplierReception(Map<String, dynamic> row) =>
      MobileDocument(
        id: _integer(row['id']),
        kind: DocumentKind.supplierReception,
        number:
            '${row['supplierDeliveryNoteNumber'] ?? row['invoiceNumber'] ?? row['id'] ?? ''}',
        party: '${row['supplierName'] ?? ''}',
        status: '${row['status'] ?? ''}',
        date: '${row['receivedDate'] ?? row['invoiceDate'] ?? ''}',
        total: _number(row['totalTtc']),
        currency: '${row['currency'] ?? 'TND'}',
        raw: row,
      );

  static MobileDocument fromSupplierInvoice(Map<String, dynamic> row) =>
      MobileDocument(
        id: _integer(row['id']),
        kind: DocumentKind.supplierInvoice,
        number: '${row['invoiceNumber'] ?? ''}',
        party: '${row['supplierName'] ?? ''}',
        status: '${row['status'] ?? ''}',
        date: '${row['invoiceDate'] ?? ''}',
        dueDate: '${row['dueDate'] ?? ''}',
        total: _number(row['totalTtc']),
        currency: '${row['currency'] ?? 'TND'}',
        raw: row,
      );

  static MobileDocument fromExpense(Map<String, dynamic> row) => MobileDocument(
        id: _integer(row['id']),
        kind: DocumentKind.expense,
        number: '${row['title'] ?? row['id'] ?? ''}',
        party: '${row['supplier_name'] ?? row['category'] ?? ''}',
        status: '${row['status'] ?? ''}',
        date: '${row['expense_date'] ?? row['created_at'] ?? ''}',
        total: _number(row['amount']),
        currency: '${row['currency'] ?? 'TND'}',
        raw: row,
      );
}

class DocumentRelation {
  const DocumentRelation({
    required this.kind,
    required this.id,
    required this.number,
  });

  final DocumentKind kind;
  final int id;
  final String number;
}

class DocumentDetails {
  const DocumentDetails({
    required this.document,
    required this.header,
    required this.items,
    required this.relations,
    this.extra = const {},
  });

  final MobileDocument document;
  final Map<String, dynamic> header;
  final List<Map<String, dynamic>> items;
  final List<DocumentRelation> relations;
  final Map<String, dynamic> extra;
}

bool canViewDocumentKind(PermissionService permissions, DocumentKind kind) {
  if (permissions.hasWildcard) return permissions.isActive;
  final names = switch (kind) {
    DocumentKind.invoice => AppPermission.invoicesView.backendNames,
    DocumentKind.quotation => AppPermission.devisView.backendNames,
    DocumentKind.creditNote => AppPermission.creditNotesView.backendNames,
    DocumentKind.salesOrder => const ['orders.view'],
    DocumentKind.deliveryNote => const ['deliveries.view'],
    DocumentKind.supplierOrder => const ['supplierOrders.view'],
    DocumentKind.supplierReception =>
      AppPermission.supplierReceptionsView.backendNames,
    DocumentKind.supplierInvoice => const ['supplierInvoices.view'],
    DocumentKind.expense => AppPermission.expensesView.backendNames,
  };
  return permissions.allowsAny(names);
}

bool documentMatchesStatus(
  MobileDocument document,
  DocumentStatusGroup group,
) {
  if (group == DocumentStatusGroup.all) return true;
  final status = document.status.toUpperCase();
  if (group == DocumentStatusGroup.draft) return status == 'DRAFT';
  if (group == DocumentStatusGroup.cancelled) {
    return status == 'CANCELLED' || status == 'REJECTED';
  }
  final completed = switch (document.kind) {
    DocumentKind.invoice => const {'PAID', 'PAYED', 'PAID_IN_FULL'},
    DocumentKind.quotation => const {'ACCEPTED'},
    DocumentKind.creditNote => const {'VALIDATED', 'AVOIR'},
    DocumentKind.salesOrder => const {'DELIVERED', 'INVOICED'},
    DocumentKind.deliveryNote => const {'DELIVERED'},
    DocumentKind.supplierOrder => const {'RECEIVED'},
    DocumentKind.supplierReception => const {'REVIEWED'},
    DocumentKind.supplierInvoice => const {'PAID'},
    DocumentKind.expense => const {'APPROVED', 'REIMBURSED'},
  };
  return group == DocumentStatusGroup.completed
      ? completed.contains(status)
      : status != 'DRAFT' &&
          status != 'CANCELLED' &&
          status != 'REJECTED' &&
          !completed.contains(status);
}

bool documentDateInRange(
  MobileDocument document,
  DateTime? from,
  DateTime? to,
) {
  if (from == null && to == null) return true;
  final rawDate = document.date.length >= 10
      ? document.date.substring(0, 10)
      : document.date;
  final date = DateTime.tryParse(rawDate);
  if (date == null) return false;
  final day = DateTime(date.year, date.month, date.day);
  if (from != null) {
    final start = DateTime(from.year, from.month, from.day);
    if (day.isBefore(start)) return false;
  }
  if (to != null) {
    final end = DateTime(to.year, to.month, to.day);
    if (day.isAfter(end)) return false;
  }
  return true;
}

int _integer(dynamic value) =>
    value is int ? value : int.tryParse('$value') ?? 0;

double _number(dynamic value) =>
    value is num ? value.toDouble() : double.tryParse('$value') ?? 0;

bool _truthy(dynamic value) =>
    value == true || value == 1 || '$value'.toLowerCase() == 'true';
