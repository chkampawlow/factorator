import 'dart:typed_data';

import 'package:my_app/core/api_client.dart';
import 'package:my_app/core/api_collection.dart';
import 'package:my_app/core/api_config.dart';
import 'package:my_app/core/document_center_models.dart';
import 'package:my_app/core/permission_service.dart';

class DocumentCenterResult {
  const DocumentCenterResult(this.documents, this.failures);

  final List<MobileDocument> documents;
  final List<String> failures;
}

class DocumentCenterRepo {
  final ApiClient _api = ApiClient.instance;

  Future<DocumentCenterResult> list({
    required PermissionService permissions,
    String search = '',
    Set<DocumentKind>? kinds,
    DocumentStatusGroup status = DocumentStatusGroup.all,
    DateTime? from,
    DateTime? to,
  }) async {
    final allowed = DocumentKind.values
        .where((kind) => canViewDocumentKind(permissions, kind))
        .where((kind) => kinds == null || kinds.contains(kind))
        .toSet();
    final operations = <Future<_DocumentFamilyResult>>[];
    final query = search.trim();
    final invoiceKinds = allowed.intersection({
      DocumentKind.invoice,
      DocumentKind.quotation,
      DocumentKind.creditNote,
    });
    if (invoiceKinds.isNotEmpty) {
      operations.add(_family(
        'Sales documents',
        ApiConfig.getInvoices,
        query,
        MobileDocument.fromInvoice,
        params: {
          if (from != null) 'date_from': _date(from),
          if (to != null) 'date_to': _date(to),
        },
        include: (document) => invoiceKinds.contains(document.kind),
      ));
    }
    if (allowed.contains(DocumentKind.salesOrder)) {
      operations.add(_family('Sales orders', ApiConfig.salesOrdersList, query,
          MobileDocument.fromSalesOrder,
          params: {
            if (from != null) 'date_from': _date(from),
            if (to != null) 'date_to': _date(to),
          }));
    }
    if (allowed.contains(DocumentKind.deliveryNote)) {
      operations.add(_family('Delivery notes', ApiConfig.deliveriesList, query,
          MobileDocument.fromDelivery,
          params: {
            if (from != null) 'date_from': _date(from),
            if (to != null) 'date_to': _date(to),
          }));
    }
    if (allowed.contains(DocumentKind.supplierOrder)) {
      operations.add(_family(
        'Supplier orders',
        ApiConfig.supplierOrdersList,
        query,
        MobileDocument.fromSupplierOrder,
      ));
    }
    if (allowed.contains(DocumentKind.supplierReception)) {
      operations.add(_family(
        'Supplier receptions',
        ApiConfig.supplierReceptionsList,
        query,
        MobileDocument.fromSupplierReception,
      ));
    }
    if (allowed.contains(DocumentKind.supplierInvoice)) {
      operations.add(_family(
        'Supplier invoices',
        ApiConfig.supplierInvoicesList,
        query,
        MobileDocument.fromSupplierInvoice,
      ));
    }
    if (allowed.contains(DocumentKind.expense)) {
      operations.add(_family('Expenses', ApiConfig.expenseNotesList, query,
          MobileDocument.fromExpense,
          params: {
            if (from != null) 'date_from': _date(from),
            if (to != null) 'date_to': _date(to),
          }));
    }

    final families = await Future.wait(operations);
    final documents = families
        .expand((family) => family.documents)
        .where((document) => documentMatchesStatus(document, status))
        .where((document) => documentDateInRange(document, from, to))
        .toList()
      ..sort((a, b) {
        final byDate = b.date.compareTo(a.date);
        return byDate != 0 ? byDate : b.id.compareTo(a.id);
      });
    return DocumentCenterResult(
      documents,
      families.map((family) => family.error).whereType<String>().toList(),
    );
  }

  Future<_DocumentFamilyResult> _family(
    String name,
    String endpoint,
    String search,
    MobileDocument Function(Map<String, dynamic>) convert, {
    Map<String, dynamic> params = const {},
    bool Function(MobileDocument)? include,
  }) async {
    try {
      final rows = await _api.getAllPages(
        endpoint,
        resourceName: name,
        queryParams: {
          ...params,
          if (search.isNotEmpty) 'search': search,
        },
      );
      final documents = rows
          .map(convert)
          .where((document) => document.id > 0)
          .where((document) => include?.call(document) ?? true)
          .toList();
      return _DocumentFamilyResult(documents);
    } catch (error) {
      return _DocumentFamilyResult(
        const [],
        '$name: ${error.toString().replaceFirst('Exception: ', '')}',
      );
    }
  }

  Future<DocumentDetails> detail(MobileDocument summary) async {
    late Map<String, dynamic> header;
    var items = <Map<String, dynamic>>[];
    var extra = <String, dynamic>{};
    switch (summary.kind) {
      case DocumentKind.invoice:
      case DocumentKind.quotation:
      case DocumentKind.creditNote:
        final responses = await Future.wait([
          _api.get(
            ApiConfig.getInvoiceById,
            authRequired: true,
            queryParams: {'id': summary.id},
          ),
          _api.get(
            ApiConfig.getInvoiceItems,
            authRequired: true,
            queryParams: {'invoice_id': summary.id},
          ),
        ]);
        header = _map(_map(responses[0])['invoice']);
        items = ApiCollection.parse(
          responses[1],
          keys: const ['data', 'items', 'results'],
          resourceName: 'document items',
        );
        if (summary.kind == DocumentKind.invoice &&
            _truthy(header['is_validated'])) {
          try {
            final settlement = _map(await _api.get(
              ApiConfig.invoiceSettlements,
              authRequired: true,
              queryParams: {'invoice_id': summary.id},
            ));
            header = {...header, ..._map(settlement['summary'])};
            extra = {
              'payments': _maps(settlement['payments']),
              'withholdings': _maps(settlement['withholdings']),
            };
          } catch (_) {
            // The document itself remains viewable if ledger access is absent.
          }
        }
      case DocumentKind.salesOrder:
        final envelope = _map(await _api.get(
          ApiConfig.salesOrderDetail,
          authRequired: true,
          queryParams: {'id': summary.id},
        ));
        header = _map(envelope['order']);
        items = _maps(envelope['items']);
      case DocumentKind.deliveryNote:
        final envelope = _map(await _api.get(
          ApiConfig.deliveryDetail,
          authRequired: true,
          queryParams: {'id': summary.id},
        ));
        header = _map(envelope['delivery']);
        items = _maps(envelope['items']);
      case DocumentKind.supplierOrder:
        final envelope = _map(await _api.get(
          ApiConfig.supplierOrderDetail,
          authRequired: true,
          queryParams: {'id': summary.id},
        ));
        header = _map(envelope['order']);
        items = _maps(header['items']);
      case DocumentKind.supplierReception:
        final envelope = _map(await _api.get(
          ApiConfig.supplierReceptionDetail,
          authRequired: true,
          queryParams: {'id': summary.id},
        ));
        header = _map(envelope['reception']);
        items = _maps(header['lines']);
      case DocumentKind.supplierInvoice:
        final envelope = _map(await _api.get(
          ApiConfig.supplierInvoiceDetail,
          authRequired: true,
          queryParams: {'id': summary.id},
        ));
        header = _map(envelope['invoice']);
        items = _maps(envelope['items']);
        extra = {
          'payments': _maps(envelope['payments']),
          'credits': _maps(envelope['credits']),
          'returns': _maps(envelope['returns']),
        };
      case DocumentKind.expense:
        final envelope = _map(await _api.get(
          ApiConfig.expenseNoteDetail,
          authRequired: true,
          queryParams: {'id': summary.id},
        ));
        header = _map(envelope['expense']);
    }
    if (header.isEmpty) throw Exception('Document details are unavailable.');
    final document = switch (summary.kind) {
      DocumentKind.invoice ||
      DocumentKind.quotation ||
      DocumentKind.creditNote =>
        MobileDocument.fromInvoice(header),
      DocumentKind.salesOrder => MobileDocument.fromSalesOrder(header),
      DocumentKind.deliveryNote => MobileDocument.fromDelivery(header),
      DocumentKind.supplierOrder => MobileDocument.fromSupplierOrder(header),
      DocumentKind.supplierReception =>
        MobileDocument.fromSupplierReception(header),
      DocumentKind.supplierInvoice =>
        MobileDocument.fromSupplierInvoice(header),
      DocumentKind.expense => MobileDocument.fromExpense(header),
    };
    return DocumentDetails(
      document: document,
      header: header,
      items: items,
      relations: _relations(summary.kind, header, items),
      extra: extra,
    );
  }

  Future<Uint8List> pdf(MobileDocument document, String language) async =>
      _api.getPdf(
        ApiConfig.documentPdf,
        queryParams: {
          'type': document.kind.pdfType!,
          'id': document.id,
          'language': language,
        },
      );

  List<DocumentRelation> _relations(
    DocumentKind kind,
    Map<String, dynamic> header,
    List<Map<String, dynamic>> items,
  ) {
    final relations = <DocumentRelation>[];
    void add(DocumentKind relationKind, dynamic id, dynamic number) {
      final parsedId = int.tryParse('${id ?? 0}') ?? 0;
      if (parsedId <= 0) return;
      if (relations
          .any((item) => item.kind == relationKind && item.id == parsedId)) {
        return;
      }
      relations.add(DocumentRelation(
        kind: relationKind,
        id: parsedId,
        number: '${number ?? ''}'.trim(),
      ));
    }

    switch (kind) {
      case DocumentKind.invoice:
      case DocumentKind.quotation:
      case DocumentKind.creditNote:
        add(DocumentKind.salesOrder, header['sales_order_id'], '');
        add(DocumentKind.deliveryNote, header['delivery_note_id'], '');
        add(DocumentKind.invoice, header['source_invoice_id'], '');
      case DocumentKind.salesOrder:
        add(DocumentKind.quotation, header['source_devis_id'],
            header['source_devis_number']);
      case DocumentKind.deliveryNote:
        add(DocumentKind.salesOrder, header['sales_order_id'],
            header['order_number']);
      case DocumentKind.supplierReception:
        add(DocumentKind.supplierOrder, header['sourceSupplierOrderId'],
            header['sourceSupplierOrderNumber']);
      case DocumentKind.supplierInvoice:
        add(DocumentKind.supplierOrder, header['supplierOrderId'],
            header['supplierOrderNumber']);
        for (final item in items) {
          add(DocumentKind.supplierReception, item['receptionId'],
              item['receptionNumber']);
        }
      case DocumentKind.expense:
        final sourceKind =
            _sourceKind('${header['source_document_type'] ?? ''}');
        if (sourceKind != null) {
          add(sourceKind, header['source_document_id'],
              header['source_document_number']);
        }
      case DocumentKind.supplierOrder:
        break;
    }
    return relations;
  }

  DocumentKind? _sourceKind(String value) => switch (value.toUpperCase()) {
        'INVOICE' || 'CUSTOMER_INVOICE' => DocumentKind.invoice,
        'DEVIS' || 'QUOTATION' => DocumentKind.quotation,
        'AVOIR' || 'CREDIT_NOTE' => DocumentKind.creditNote,
        'SALES_ORDER' || 'ORDER' => DocumentKind.salesOrder,
        'DELIVERY_NOTE' || 'DELIVERY' => DocumentKind.deliveryNote,
        'SUPPLIER_ORDER' || 'PURCHASE_ORDER' => DocumentKind.supplierOrder,
        'SUPPLIER_RECEPTION' || 'RECEPTION' => DocumentKind.supplierReception,
        'SUPPLIER_INVOICE' => DocumentKind.supplierInvoice,
        _ => null,
      };

  String _date(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

  Map<String, dynamic> _map(dynamic value) =>
      value is Map ? Map<String, dynamic>.from(value) : {};

  List<Map<String, dynamic>> _maps(dynamic value) => value is List
      ? value
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList()
      : [];

  bool _truthy(dynamic value) =>
      value == true || value == 1 || '$value'.toLowerCase() == 'true';
}

class _DocumentFamilyResult {
  const _DocumentFamilyResult(this.documents, [this.error]);

  final List<MobileDocument> documents;
  final String? error;
}
