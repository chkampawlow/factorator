import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:my_app/core/supplier_reception_logic.dart';
import 'package:my_app/l10n/app_localizations.dart';
import 'package:my_app/storage/supplier_receptions_repo.dart';
import 'package:my_app/widgets/app_alerts.dart';

class SupplierReceptionFormScreen extends StatefulWidget {
  const SupplierReceptionFormScreen({
    super.key,
    this.reception,
    this.supplierOrder,
    this.previousReceptions = const [],
  }) : assert(reception != null || supplierOrder != null);

  final Map<String, dynamic>? reception;
  final Map<String, dynamic>? supplierOrder;
  final List<Map<String, dynamic>> previousReceptions;

  @override
  State<SupplierReceptionFormScreen> createState() =>
      _SupplierReceptionFormScreenState();
}

class _SupplierReceptionFormScreenState
    extends State<SupplierReceptionFormScreen> {
  final _repo = SupplierReceptionsRepo();
  final _formKey = GlobalKey<FormState>();
  final _imagePicker = ImagePicker();

  late final TextEditingController _invoiceNumber;
  late final TextEditingController _deliveryNumber;
  late final TextEditingController _notes;
  late final TextEditingController _exceptionReason;
  late final List<_ReceptionLineEditor> _lines;

  late String _invoiceDate;
  late String _receivedDate;
  late String _deliveryDate;
  late String _exceptionType;
  late final int _supplierId;
  late final int _sourceOrderId;
  late final String _supplierName;
  late final String _sourceOrderNumber;
  late int _savedId;
  XFile? _attachment;
  bool _saving = false;

  bool get _isEdit => widget.reception != null;

  @override
  void initState() {
    super.initState();
    final reception = widget.reception;
    final order = widget.supplierOrder;
    final today = _dateOnly(DateTime.now());

    _savedId = _asInt(reception?['id']);
    _supplierId = _asInt(reception?['supplierId'] ?? order?['supplierId']);
    _sourceOrderId =
        _asInt(reception?['sourceSupplierOrderId'] ?? order?['id']);
    _supplierName =
        '${reception?['supplierName'] ?? order?['supplierName'] ?? ''}';
    _sourceOrderNumber =
        '${reception?['sourceSupplierOrderNumber'] ?? order?['orderNumber'] ?? ''}';
    _invoiceNumber =
        TextEditingController(text: '${reception?['invoiceNumber'] ?? ''}');
    _deliveryNumber = TextEditingController(
      text: '${reception?['supplierDeliveryNoteNumber'] ?? ''}',
    );
    _notes = TextEditingController(text: '${reception?['notes'] ?? ''}');
    _exceptionReason =
        TextEditingController(text: '${reception?['exceptionReason'] ?? ''}');
    _invoiceDate = '${reception?['invoiceDate'] ?? today}';
    _receivedDate = '${reception?['receivedDate'] ?? today}';
    _deliveryDate = '${reception?['supplierDeliveryNoteDate'] ?? ''}';
    _exceptionType = '${reception?['exceptionType'] ?? 'NONE'}'.toUpperCase();

    if (reception != null) {
      final rawLines = reception['lines'] as List? ?? const [];
      _lines = rawLines
          .whereType<Map>()
          .map((line) => _ReceptionLineEditor.existing(
                Map<String, dynamic>.from(line),
              ))
          .toList();
    } else {
      final accepted = confirmedAcceptedQuantities(widget.previousReceptions);
      final rawLines = order?['items'] as List? ?? const [];
      _lines = rawLines.whereType<Map>().map((raw) {
        final line = Map<String, dynamic>.from(raw);
        final remaining = remainingSupplierOrderQuantity(line, accepted);
        return _ReceptionLineEditor.fromOrder(line, remaining);
      }).toList();
    }
  }

  @override
  void dispose() {
    _invoiceNumber.dispose();
    _deliveryNumber.dispose();
    _notes.dispose();
    _exceptionReason.dispose();
    for (final line in _lines) {
      line.dispose();
    }
    super.dispose();
  }

  int _asInt(dynamic value) => int.tryParse('${value ?? 0}') ?? 0;

  String _dateOnly(DateTime value) => value.toIso8601String().split('T').first;

  Future<void> _pickDate({required _ReceptionDate field}) async {
    final current = switch (field) {
      _ReceptionDate.invoice => _invoiceDate,
      _ReceptionDate.received => _receivedDate,
      _ReceptionDate.delivery => _deliveryDate,
    };
    final initial = DateTime.tryParse(current) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(DateTime.now().year + 3),
      initialDate: initial,
    );
    if (picked == null || !mounted) return;
    setState(() {
      switch (field) {
        case _ReceptionDate.invoice:
          _invoiceDate = _dateOnly(picked);
        case _ReceptionDate.received:
          _receivedDate = _dateOnly(picked);
        case _ReceptionDate.delivery:
          _deliveryDate = _dateOnly(picked);
      }
    });
  }

  Future<void> _pickAttachment() async {
    final l10n = AppLocalizations.of(context)!;
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(l10n.takeEvidencePhoto),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(l10n.chooseEvidencePhoto),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    try {
      final file = await _imagePicker.pickImage(
        source: source,
        imageQuality: 88,
        maxWidth: 2400,
      );
      if (file != null && mounted) setState(() => _attachment = file);
    } catch (error) {
      if (mounted) {
        AppAlerts.error(context, '${l10n.couldNotSelectPhoto}: $error');
      }
    }
  }

  List<Map<String, dynamic>> _linePayloads() {
    final l10n = AppLocalizations.of(context)!;
    final payloads = <Map<String, dynamic>>[];
    for (final editor in _lines.where((line) => line.included)) {
      final accepted = editor.accepted;
      final damaged = editor.damaged;
      final rejected = editor.rejected;
      if (accepted < 0 || damaged < 0 || rejected < 0) {
        throw Exception(l10n.negativeReceptionQuantities);
      }
      final quantity = accepted + damaged + rejected;
      if (quantity <= 0) {
        throw Exception(
          '${l10n.enterReceivedQuantity} (${editor.name})',
        );
      }
      final reason = editor.reason.text.trim();
      if ((damaged > 0 || rejected > 0) && reason.isEmpty) {
        throw Exception(
          '${l10n.discrepancyReasonRequired} (${editor.name})',
        );
      }
      final source = editor.source;
      final itemType = '${source['itemType'] ?? 'PRODUCT'}'.toUpperCase();
      payloads.add({
        'catalogId': _asInt(source['catalogId']),
        'code': '${source['code'] ?? ''}',
        'name': editor.name,
        'itemType': itemType,
        'orderedQty': receptionNumber(
          source['orderedQty'] ?? source['qty'],
        ),
        'qty': quantity,
        'acceptedQty': accepted,
        'damagedQty': damaged,
        'rejectedQty': rejected,
        'discrepancyReason': reason,
        'stockImpact': itemType == 'SERVICE' ? 0 : accepted,
        'price': receptionNumber(source['price']),
        'sellingPrice': receptionNumber(source['sellingPrice']),
        'subtotal': quantity * receptionNumber(source['price']),
        'tvaRate': receptionNumber(source['tvaRate']),
        'unit': '${source['unit'] ?? 'piece'}',
      });
    }
    if (payloads.isEmpty) {
      throw Exception(l10n.selectReceptionLine);
    }
    return payloads;
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;
    if (_saving || !_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    try {
      final lines = _linePayloads();
      final totals = supplierReceptionTotals(lines);
      final hasOverdelivery = !_isEdit &&
          _sourceOrderId > 0 &&
          _lines.any((line) => line.included && line.accepted > line.remaining);
      final exceptionType = _sourceOrderId <= 0
          ? 'NO_ORDER'
          : hasOverdelivery
              ? 'OVERDELIVERY'
              : _exceptionType;
      final exceptionReason = _exceptionReason.text.trim();
      if (exceptionType != 'NONE' && exceptionReason.isEmpty) {
        throw Exception(l10n.explainReceptionException);
      }

      _savedId = await _repo.saveDraft({
        if (_savedId > 0) 'id': _savedId,
        'supplierId': _supplierId,
        'sourceSupplierOrderId': _sourceOrderId,
        'invoiceNumber': _invoiceNumber.text.trim(),
        'invoiceDate': _invoiceDate,
        'supplierDeliveryNoteNumber': _deliveryNumber.text.trim(),
        'supplierDeliveryNoteDate': _deliveryDate,
        'receivedDate': _receivedDate,
        'notes': _notes.text.trim(),
        'exceptionType': exceptionType,
        'exceptionReason': exceptionReason,
        'status': 'DRAFT',
        ...totals,
        'lines': lines,
      });

      var attachmentFailed = false;
      final attachment = _attachment;
      if (attachment != null) {
        try {
          await _repo.uploadDiscrepancyAttachment(_savedId, attachment.path);
        } catch (_) {
          attachmentFailed = true;
        }
      }
      if (!mounted) return;
      if (attachmentFailed) {
        AppAlerts.warning(
          context,
          l10n.evidenceUploadFailed,
        );
      } else {
        AppAlerts.success(context, l10n.receptionDraftSaved);
      }
      Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        AppAlerts.error(
          context,
          error.toString().replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final totals = supplierReceptionTotals(
      _lines.where((line) => line.included).map((line) => {
            'qty': line.accepted + line.damaged + line.rejected,
            'price': receptionNumber(line.source['price']),
            'tvaRate': receptionNumber(line.source['tvaRate']),
          }),
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? l10n.editReception : l10n.newReception),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.local_shipping_outlined),
                    title: Text(_supplierName),
                    subtitle: Text(
                      _sourceOrderNumber.isEmpty
                          ? l10n.receptionWithoutOrder
                          : '${l10n.purchaseOrder}: $_sourceOrderNumber',
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _invoiceNumber,
                  maxLength: 100,
                  decoration: InputDecoration(
                    labelText: l10n.supplierInvoiceOptional,
                    prefixIcon: const Icon(Icons.receipt_long_outlined),
                  ),
                ),
                TextFormField(
                  controller: _deliveryNumber,
                  maxLength: 100,
                  decoration: InputDecoration(
                    labelText: l10n.supplierDeliveryNumber,
                    prefixIcon: const Icon(Icons.description_outlined),
                  ),
                ),
                const SizedBox(height: 4),
                _dateTile(
                  label: l10n.invoiceDate,
                  value: _invoiceDate,
                  onTap: () => _pickDate(field: _ReceptionDate.invoice),
                ),
                _dateTile(
                  label: l10n.receivedDate,
                  value: _receivedDate,
                  onTap: () => _pickDate(field: _ReceptionDate.received),
                ),
                _dateTile(
                  label: l10n.deliveryDateOptional,
                  value: _deliveryDate.isEmpty ? l10n.notSet : _deliveryDate,
                  onTap: () => _pickDate(field: _ReceptionDate.delivery),
                  onClear: _deliveryDate.isEmpty
                      ? null
                      : () => setState(() => _deliveryDate = ''),
                ),
                const SizedBox(height: 18),
                Text(
                  l10n.receivedQuantities,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                ..._lines.map(_lineCard),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _exceptionType,
                  decoration: InputDecoration(
                    labelText: l10n.receptionException,
                    prefixIcon: const Icon(Icons.warning_amber_outlined),
                  ),
                  items: [
                    DropdownMenuItem(value: 'NONE', child: Text(l10n.none)),
                    if (_sourceOrderId > 0)
                      DropdownMenuItem(
                        value: 'OVERDELIVERY',
                        child: Text(l10n.overdelivery),
                      ),
                    if (_sourceOrderId <= 0)
                      DropdownMenuItem(
                        value: 'NO_ORDER',
                        child: Text(l10n.noPurchaseOrder),
                      ),
                  ],
                  onChanged: _sourceOrderId <= 0
                      ? null
                      : (value) =>
                          setState(() => _exceptionType = value ?? 'NONE'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _exceptionReason,
                  maxLength: 255,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: l10n.exceptionReason,
                  ),
                ),
                TextFormField(
                  controller: _notes,
                  maxLines: 3,
                  decoration: InputDecoration(labelText: l10n.internalNotes),
                ),
                const SizedBox(height: 12),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.add_a_photo_outlined),
                    title: Text(
                      _attachment?.name ??
                          (widget.reception?['hasDiscrepancyAttachment'] == true
                              ? '${widget.reception?['discrepancyAttachmentName']}'
                              : l10n.addDiscrepancyEvidence),
                    ),
                    subtitle: Text(l10n.evidenceFileHelp),
                    trailing: _attachment == null
                        ? const Icon(Icons.chevron_right)
                        : IconButton(
                            onPressed: () => setState(() => _attachment = null),
                            icon: const Icon(Icons.close),
                          ),
                    onTap: _pickAttachment,
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.receptionTotals,
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 8),
                        Text('${l10n.totalHt}: '
                            '${_number(totals['totalHt'] ?? 0)} TND'),
                        Text('${l10n.vat}: '
                            '${_number(totals['totalVat'] ?? 0)} TND'),
                        Text(
                          '${l10n.totalTtc}: '
                          '${_number(totals['totalTtc'] ?? 0)} TND',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(_saving ? l10n.saving : l10n.saveReceptionDraft),
                ),
                const SizedBox(height: 28),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _dateTile({
    required String label,
    required String value,
    required VoidCallback onTap,
    VoidCallback? onClear,
  }) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.calendar_today_outlined),
        title: Text(label),
        subtitle: Text(value),
        trailing: onClear == null
            ? const Icon(Icons.chevron_right)
            : IconButton(onPressed: onClear, icon: const Icon(Icons.close)),
        onTap: onTap,
      ),
    );
  }

  Widget _lineCard(_ReceptionLineEditor line) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: line.included,
              onChanged: (value) => setState(() => line.included = value),
              title: Text(line.name),
              subtitle: Text(
                '${line.source['code'] ?? ''} • ${l10n.ordered} '
                '${_number(receptionNumber(line.source['orderedQty'] ?? line.source['qty']))} '
                '• ${l10n.remaining} ${_number(line.remaining)}',
              ),
            ),
            if (line.included) ...[
              Row(
                children: [
                  Expanded(
                    child: _quantityField(
                      controller: line.acceptedController,
                      label: l10n.accepted,
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _quantityField(
                      controller: line.damagedController,
                      label: l10n.damaged,
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _quantityField(
                      controller: line.rejectedController,
                      label: l10n.rejected,
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: line.reason,
                maxLength: 255,
                decoration: InputDecoration(
                  labelText: l10n.discrepancyReason,
                  isDense: true,
                ),
              ),
              Text(
                '${l10n.received}: '
                '${_number(line.accepted + line.damaged + line.rejected)} '
                '${line.source['unit'] ?? ''}',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _quantityField({
    required TextEditingController controller,
    required String label,
    required ValueChanged<String> onChanged,
  }) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: onChanged,
      decoration: InputDecoration(labelText: label, isDense: true),
    );
  }

  String _number(double value) {
    final fixed = value.toStringAsFixed(3);
    return fixed.replaceFirst(RegExp(r'\.?0+$'), '');
  }
}

enum _ReceptionDate { invoice, received, delivery }

class _ReceptionLineEditor {
  _ReceptionLineEditor._({
    required this.source,
    required this.remaining,
    required this.included,
    required double accepted,
    required double damaged,
    required double rejected,
    required String discrepancyReason,
  })  : acceptedController = TextEditingController(text: _text(accepted)),
        damagedController = TextEditingController(text: _text(damaged)),
        rejectedController = TextEditingController(text: _text(rejected)),
        reason = TextEditingController(text: discrepancyReason);

  factory _ReceptionLineEditor.existing(Map<String, dynamic> line) {
    return _ReceptionLineEditor._(
      source: line,
      remaining: receptionNumber(line['orderedQty']),
      included: true,
      accepted: receptionNumber(line['acceptedQty'] ?? line['qty']),
      damaged: receptionNumber(line['damagedQty']),
      rejected: receptionNumber(line['rejectedQty']),
      discrepancyReason: '${line['discrepancyReason'] ?? ''}',
    );
  }

  factory _ReceptionLineEditor.fromOrder(
    Map<String, dynamic> orderLine,
    double remaining,
  ) {
    final source = <String, dynamic>{
      ...orderLine,
      'name': '${orderLine['description'] ?? orderLine['name'] ?? ''}',
      'orderedQty': receptionNumber(orderLine['qty']),
      'sellingPrice': receptionNumber(orderLine['sellingPrice']),
    };
    return _ReceptionLineEditor._(
      source: source,
      remaining: remaining,
      included: remaining > 0,
      accepted: remaining,
      damaged: 0,
      rejected: 0,
      discrepancyReason: '',
    );
  }

  final Map<String, dynamic> source;
  final double remaining;
  bool included;
  final TextEditingController acceptedController;
  final TextEditingController damagedController;
  final TextEditingController rejectedController;
  final TextEditingController reason;

  String get name => '${source['name'] ?? source['description'] ?? 'Item'}';
  double get accepted => receptionNumber(acceptedController.text);
  double get damaged => receptionNumber(damagedController.text);
  double get rejected => receptionNumber(rejectedController.text);

  void dispose() {
    acceptedController.dispose();
    damagedController.dispose();
    rejectedController.dispose();
    reason.dispose();
  }

  static String _text(double value) {
    final fixed = value.toStringAsFixed(3);
    return fixed.replaceFirst(RegExp(r'\.?0+$'), '');
  }
}
