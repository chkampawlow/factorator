enum ExtractionDestination {
  expense,
  supplierInvoice,
  supplierDelivery,
  purchaseOrder,
}

class ExtractionBatch {
  const ExtractionBatch({required this.summary, required this.items});

  final ExtractionSummary summary;
  final List<ExtractionItem> items;

  factory ExtractionBatch.fromJson(
    Map<String, dynamic> json, {
    Map<String, String> sourcePaths = const {},
  }) {
    final rawItems = json['items'];
    return ExtractionBatch(
      summary: ExtractionSummary.fromJson(_map(json['summary'])),
      items: rawItems is List
          ? rawItems.whereType<Map>().map((item) {
              final row = Map<String, dynamic>.from(item);
              final fileName = '${row['fileName'] ?? ''}';
              return ExtractionItem.fromJson(
                row,
                sourcePath: sourcePaths[fileName] ?? '',
              );
            }).toList()
          : const [],
    );
  }
}

class ExtractionSummary {
  const ExtractionSummary({
    required this.requested,
    required this.processed,
    required this.failed,
    required this.successRate,
    required this.totalPages,
    required this.totalInputLabel,
    required this.wallClockMs,
  });

  final int requested;
  final int processed;
  final int failed;
  final double successRate;
  final int totalPages;
  final String totalInputLabel;
  final double wallClockMs;

  factory ExtractionSummary.fromJson(Map<String, dynamic> json) =>
      ExtractionSummary(
        requested: _integer(json['requested']),
        processed: _integer(json['processed']),
        failed: _integer(json['failed']),
        successRate: _number(json['successRate']),
        totalPages: _integer(json['totalPages']),
        totalInputLabel: '${json['totalInputLabel'] ?? ''}',
        wallClockMs: _number(json['wallClockMs']),
      );
}

class ExtractionItem {
  const ExtractionItem({
    required this.fileName,
    required this.sourcePath,
    required this.sizeLabel,
    required this.elapsedMs,
    required this.success,
    required this.error,
    required this.document,
  });

  final String fileName;
  final String sourcePath;
  final String sizeLabel;
  final double elapsedMs;
  final bool success;
  final String error;
  final ExtractedDocument? document;

  factory ExtractionItem.fromJson(
    Map<String, dynamic> json, {
    String sourcePath = '',
  }) {
    final result = json['result'];
    return ExtractionItem(
      fileName: '${json['fileName'] ?? ''}',
      sourcePath: sourcePath,
      sizeLabel: '${json['sizeLabel'] ?? ''}',
      elapsedMs: _number(json['elapsedMs']),
      success: _truthy(json['success']),
      error: '${json['error'] ?? ''}',
      document: result is Map
          ? ExtractedDocument.fromJson(Map<String, dynamic>.from(result))
          : null,
    );
  }
}

class ExtractedDocument {
  const ExtractedDocument({
    required this.fileName,
    required this.invoiceNumber,
    required this.issueDate,
    required this.dueDate,
    required this.supplierName,
    required this.clientName,
    required this.subtotal,
    required this.taxAmount,
    required this.total,
    required this.currency,
    required this.pageCount,
    required this.rawText,
    required this.items,
    required this.warnings,
    required this.overallConfidence,
    required this.fieldConfidence,
    required this.validationStatus,
    required this.reviewRequired,
  });

  final String fileName;
  final String invoiceNumber;
  final String issueDate;
  final String dueDate;
  final String supplierName;
  final String clientName;
  final double? subtotal;
  final double? taxAmount;
  final double? total;
  final String currency;
  final int pageCount;
  final String rawText;
  final List<ExtractedLine> items;
  final List<ExtractionWarning> warnings;
  final double overallConfidence;
  final Map<String, double> fieldConfidence;
  final String validationStatus;
  final bool reviewRequired;

  factory ExtractedDocument.fromJson(Map<String, dynamic> json) {
    final confidence = _map(json['confidence']);
    final fields = _map(confidence['fields']);
    final rawItems = json['items'];
    final rawWarnings = json['warnings'];
    return ExtractedDocument(
      fileName: '${json['file_name'] ?? ''}',
      invoiceNumber:
          '${json['invoice_number'] ?? json['document_number'] ?? ''}',
      issueDate: '${json['issue_date'] ?? ''}',
      dueDate: '${json['due_date'] ?? ''}',
      supplierName: '${json['supplier_name'] ?? ''}',
      clientName: '${json['client_name'] ?? ''}',
      subtotal: _nullableNumber(json['subtotal'] ?? json['subtotal_ht']),
      taxAmount: _nullableNumber(json['tax_amount'] ?? json['vat_total']),
      total: _nullableNumber(json['total'] ?? json['total_ttc']),
      currency: '${json['currency'] ?? 'TND'}'.toUpperCase(),
      pageCount: _integer(json['page_count']),
      rawText: '${json['raw_text'] ?? ''}',
      items: rawItems is List
          ? rawItems
              .whereType<Map>()
              .map((line) =>
                  ExtractedLine.fromJson(Map<String, dynamic>.from(line)))
              .toList()
          : const [],
      warnings: rawWarnings is List
          ? rawWarnings
              .whereType<Map>()
              .map((warning) => ExtractionWarning.fromJson(
                    Map<String, dynamic>.from(warning),
                  ))
              .toList()
          : const [],
      overallConfidence: _confidence(confidence['overall']),
      fieldConfidence: fields.map(
        (key, value) => MapEntry(key, _confidence(value)),
      ),
      validationStatus: '${json['validation_status'] ?? 'not_checked'}',
      reviewRequired: json.containsKey('review_required')
          ? _truthy(json['review_required'])
          : true,
    );
  }

  double? confidenceFor(String field) => fieldConfidence[field];
}

class ExtractedLine {
  const ExtractedLine({
    required this.description,
    required this.quantity,
    required this.unitPrice,
    required this.total,
    required this.confidence,
  });

  final String description;
  final double? quantity;
  final double? unitPrice;
  final double? total;
  final double? confidence;

  factory ExtractedLine.fromJson(Map<String, dynamic> json) => ExtractedLine(
        description: '${json['description'] ?? ''}',
        quantity: _nullableNumber(json['quantity']),
        unitPrice: _nullableNumber(json['unit_price'] ?? json['unit_price_ht']),
        total: _nullableNumber(json['total'] ?? json['line_total_ttc']),
        confidence:
            json['confidence'] == null ? null : _confidence(json['confidence']),
      );
}

class ExtractionWarning {
  const ExtractionWarning({
    required this.code,
    required this.severity,
    required this.field,
    required this.message,
    this.itemIndex,
  });

  final String code;
  final String severity;
  final String field;
  final String message;
  final int? itemIndex;

  factory ExtractionWarning.fromJson(Map<String, dynamic> json) =>
      ExtractionWarning(
        code: '${json['code'] ?? ''}',
        severity: '${json['severity'] ?? 'warning'}',
        field: '${json['field'] ?? ''}',
        message: '${json['message'] ?? ''}',
        itemIndex:
            json['item_index'] == null ? null : _integer(json['item_index']),
      );
}

Map<String, dynamic> _map(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : const {};

int _integer(dynamic value) =>
    value is int ? value : int.tryParse('$value') ?? 0;

double _number(dynamic value) =>
    value is num ? value.toDouble() : double.tryParse('$value') ?? 0;

double? _nullableNumber(dynamic value) {
  if (value == null || '$value'.trim().isEmpty) return null;
  return value is num ? value.toDouble() : double.tryParse('$value');
}

double _confidence(dynamic value) {
  final parsed = _number(value);
  return (parsed > 1 ? parsed / 100 : parsed).clamp(0, 1);
}

bool _truthy(dynamic value) =>
    value == true || value == 1 || '$value'.toLowerCase() == 'true';
