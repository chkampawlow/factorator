import 'package:flutter/material.dart';

import '../core/extraction_models.dart';
import '../core/permission_service.dart';
import '../l10n/app_localizations.dart';
import '../widgets/app_alerts.dart';
import 'create_expense_note_screen.dart';

class ExtractionReviewScreen extends StatefulWidget {
  const ExtractionReviewScreen({
    super.key,
    required this.item,
    required this.permissions,
  });

  final ExtractionItem item;
  final PermissionService permissions;

  @override
  State<ExtractionReviewScreen> createState() => _ExtractionReviewScreenState();
}

class _ExtractionReviewScreenState extends State<ExtractionReviewScreen> {
  late final ExtractedDocument _document;
  late final TextEditingController _invoiceNumberController;
  late final TextEditingController _supplierController;
  late final TextEditingController _clientController;
  late final TextEditingController _issueDateController;
  late final TextEditingController _dueDateController;
  late final TextEditingController _subtotalController;
  late final TextEditingController _taxController;
  late final TextEditingController _totalController;
  late final TextEditingController _currencyController;
  late final List<_LineEditor> _lines;

  ExtractionDestination _destination = ExtractionDestination.expense;
  bool _reviewed = false;

  @override
  void initState() {
    super.initState();
    _document = widget.item.document!;
    _invoiceNumberController =
        TextEditingController(text: _document.invoiceNumber);
    _supplierController = TextEditingController(text: _document.supplierName);
    _clientController = TextEditingController(text: _document.clientName);
    _issueDateController = TextEditingController(text: _document.issueDate);
    _dueDateController = TextEditingController(text: _document.dueDate);
    _subtotalController =
        TextEditingController(text: _format(_document.subtotal));
    _taxController = TextEditingController(text: _format(_document.taxAmount));
    _totalController = TextEditingController(text: _format(_document.total));
    _currencyController = TextEditingController(text: _document.currency);
    _lines = _document.items.map(_LineEditor.new).toList();
  }

  @override
  void dispose() {
    _invoiceNumberController.dispose();
    _supplierController.dispose();
    _clientController.dispose();
    _issueDateController.dispose();
    _dueDateController.dispose();
    _subtotalController.dispose();
    _taxController.dispose();
    _totalController.dispose();
    _currencyController.dispose();
    for (final line in _lines) {
      line.dispose();
    }
    super.dispose();
  }

  String _format(double? value) {
    if (value == null) return '';
    return value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(3).replaceFirst(RegExp(r'0+$'), '');
  }

  String _destinationLabel(
    AppLocalizations l10n,
    ExtractionDestination destination,
  ) {
    return switch (destination) {
      ExtractionDestination.expense => l10n.extractorExpense,
      ExtractionDestination.supplierInvoice => l10n.extractorSupplierInvoice,
      ExtractionDestination.supplierDelivery => l10n.extractorSupplierDelivery,
      ExtractionDestination.purchaseOrder => l10n.extractorPurchaseOrder,
    };
  }

  DateTime? _parseDate(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return null;
    return DateTime.tryParse(value);
  }

  String _expenseTitle() {
    final supplier = _supplierController.text.trim();
    final number = _invoiceNumberController.text.trim();
    if (supplier.isNotEmpty && number.isNotEmpty) return '$supplier · $number';
    if (supplier.isNotEmpty) return supplier;
    if (number.isNotEmpty) return number;
    return widget.item.fileName;
  }

  String _expenseDescription() {
    final details = <String>[
      'Extracted from ${widget.item.fileName}',
      if (_invoiceNumberController.text.trim().isNotEmpty)
        'Document: ${_invoiceNumberController.text.trim()}',
      if (_supplierController.text.trim().isNotEmpty)
        'Supplier: ${_supplierController.text.trim()}',
      if (_clientController.text.trim().isNotEmpty)
        'Client: ${_clientController.text.trim()}',
      if (_taxController.text.trim().isNotEmpty)
        'Tax: ${_taxController.text.trim()} ${_currencyController.text.trim()}',
    ];
    final lineNames = _lines
        .map((line) => line.description.text.trim())
        .where((value) => value.isNotEmpty)
        .take(8)
        .join(', ');
    if (lineNames.isNotEmpty) details.add('Items: $lineNames');
    final value = details.join('\n');
    return value.length <= 1200 ? value : value.substring(0, 1200);
  }

  Future<void> _continue() async {
    final l10n = AppLocalizations.of(context)!;
    if (!_reviewed) return;

    if (_destination != ExtractionDestination.expense) {
      AppAlerts.info(context, l10n.extractorDestinationNeedsWeb);
      return;
    }

    final permissions = widget.permissions;
    if (!permissions.can(AppPermission.expensesCreate)) {
      AppAlerts.error(context, l10n.extractorExpensePermissionDenied);
      return;
    }

    final amount = double.tryParse(
      _totalController.text.trim().replaceAll(',', '.'),
    );
    final requestedCurrency = _currencyController.text.trim().toUpperCase();
    const supportedCurrencies = {'TND', 'EUR', 'USD'};
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CreateExpenseNoteScreen(
          initialTitle: _expenseTitle(),
          initialAmount: amount,
          initialDescription: _expenseDescription(),
          initialDate: _parseDate(_issueDateController.text),
          initialCurrency: supportedCurrencies.contains(requestedCurrency)
              ? requestedCurrency
              : 'TND',
        ),
      ),
    );
    if (created == true && mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final permissions = widget.permissions;
    final canCreateExpense = permissions.can(AppPermission.expensesCreate);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.extractorReviewTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          Text(
            widget.item.fileName,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(l10n.extractorReviewSubtitle),
          const SizedBox(height: 16),
          DropdownButtonFormField<ExtractionDestination>(
            initialValue: _destination,
            decoration: InputDecoration(
              labelText: l10n.extractorDocumentType,
              border: const OutlineInputBorder(),
            ),
            items: ExtractionDestination.values
                .map(
                  (destination) => DropdownMenuItem(
                    value: destination,
                    child: Text(_destinationLabel(l10n, destination)),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) setState(() => _destination = value);
            },
          ),
          const SizedBox(height: 18),
          Text(
            l10n.extractorExtractedData,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          _reviewField(
            l10n: l10n,
            label: l10n.invoiceNumber,
            controller: _invoiceNumberController,
            confidenceKey: 'invoice_number',
          ),
          _reviewField(
            l10n: l10n,
            label: l10n.supplierLabel,
            controller: _supplierController,
            confidenceKey: 'supplier_name',
          ),
          _reviewField(
            l10n: l10n,
            label: l10n.client,
            controller: _clientController,
            confidenceKey: 'client_name',
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _reviewField(
                  l10n: l10n,
                  label: l10n.dateLabel,
                  controller: _issueDateController,
                  confidenceKey: 'issue_date',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _reviewField(
                  l10n: l10n,
                  label: l10n.dueDate,
                  controller: _dueDateController,
                  confidenceKey: 'due_date',
                ),
              ),
            ],
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _reviewField(
                  l10n: l10n,
                  label: l10n.subtotal,
                  controller: _subtotalController,
                  confidenceKey: 'subtotal',
                  numeric: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _reviewField(
                  l10n: l10n,
                  label: l10n.extractorTaxAmount,
                  controller: _taxController,
                  confidenceKey: 'tax_amount',
                  numeric: true,
                ),
              ),
            ],
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _reviewField(
                  l10n: l10n,
                  label: l10n.total,
                  controller: _totalController,
                  confidenceKey: 'total',
                  numeric: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _reviewField(
                  l10n: l10n,
                  label: l10n.currency,
                  controller: _currencyController,
                  confidenceKey: 'currency',
                ),
              ),
            ],
          ),
          if (_document.warnings.isNotEmpty) ...[
            const SizedBox(height: 6),
            _WarningsCard(warnings: _document.warnings),
          ],
          const SizedBox(height: 18),
          Text(
            l10n.extractorLineItems,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          if (_lines.isEmpty)
            Text(l10n.extractorNoLineItems)
          else
            ..._lines.indexed.map(
              (entry) => _LineCard(
                index: entry.$1,
                line: entry.$2,
              ),
            ),
          if (_document.rawText.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Card(
              child: ExpansionTile(
                title: Text(l10n.extractorRawText),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: [
                  SelectableText(_document.rawText.trim()),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          Card(
            child: CheckboxListTile(
              value: _reviewed,
              onChanged: (value) => setState(() => _reviewed = value ?? false),
              title: Text(l10n.extractorConfirmReviewed),
              subtitle: Text(l10n.extractorDraftNotice),
              controlAffinity: ListTileControlAffinity.leading,
            ),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: _reviewed ? _continue : null,
            icon: const Icon(Icons.arrow_forward_rounded),
            label: Text(
              _destination == ExtractionDestination.expense
                  ? l10n.extractorCreatePendingExpense
                  : l10n.continueText,
            ),
          ),
          if (_destination == ExtractionDestination.expense &&
              !canCreateExpense) ...[
            const SizedBox(height: 8),
            Text(
              l10n.extractorExpensePermissionDenied,
              textAlign: TextAlign.center,
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ],
        ],
      ),
    );
  }

  Widget _reviewField({
    required AppLocalizations l10n,
    required String label,
    required TextEditingController controller,
    required String confidenceKey,
    bool numeric = false,
  }) {
    final confidence = _document.confidenceFor(confidenceKey);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: numeric
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          helperText: confidence == null
              ? null
              : l10n.extractorConfidence((confidence * 100).round()),
        ),
      ),
    );
  }
}

class _LineEditor {
  _LineEditor(ExtractedLine line)
      : description = TextEditingController(text: line.description),
        quantity = TextEditingController(text: _formatNumber(line.quantity)),
        unitPrice = TextEditingController(text: _formatNumber(line.unitPrice)),
        total = TextEditingController(text: _formatNumber(line.total)),
        confidence = line.confidence;

  final TextEditingController description;
  final TextEditingController quantity;
  final TextEditingController unitPrice;
  final TextEditingController total;
  final double? confidence;

  static String _formatNumber(double? value) {
    if (value == null) return '';
    return value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(3).replaceFirst(RegExp(r'0+$'), '');
  }

  void dispose() {
    description.dispose();
    quantity.dispose();
    unitPrice.dispose();
    total.dispose();
  }
}

class _LineCard extends StatelessWidget {
  const _LineCard({required this.index, required this.line});

  final int index;
  final _LineEditor line;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${l10n.product} ${index + 1}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                if (line.confidence != null)
                  Text(
                    l10n.extractorConfidence(
                      (line.confidence! * 100).round(),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: line.description,
              decoration: InputDecoration(
                labelText: l10n.description,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: line.quantity,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: l10n.quantityShort,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: line.unitPrice,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: l10n.price,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: line.total,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: l10n.total,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _WarningsCard extends StatelessWidget {
  const _WarningsCard({required this.warnings});

  final List<ExtractionWarning> warnings;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    return Card(
      color: colors.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning_amber_rounded,
                    color: colors.onErrorContainer),
                const SizedBox(width: 8),
                Text(
                  l10n.extractorWarnings,
                  style: TextStyle(
                    color: colors.onErrorContainer,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...warnings.map(
              (warning) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '• ${warning.message}',
                  style: TextStyle(color: colors.onErrorContainer),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
