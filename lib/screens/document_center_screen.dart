import 'package:flutter/material.dart';
import 'package:my_app/core/access_scope.dart';
import 'package:my_app/core/document_center_models.dart';
import 'package:my_app/core/permission_service.dart';
import 'package:my_app/l10n/app_localizations.dart';
import 'package:my_app/screens/pdf_preview_screen.dart';
import 'package:my_app/storage/document_center_repo.dart';
import 'package:my_app/widgets/app_alerts.dart';
import 'package:my_app/widgets/app_top_bar.dart';

class DocumentCenterScreen extends StatefulWidget {
  const DocumentCenterScreen({
    super.key,
    required this.onToggleTheme,
    required this.onChangePrimaryColor,
    required this.onChangeLanguage,
    required this.currentPrimaryColor,
  });

  final VoidCallback onToggleTheme;
  final void Function(Color color) onChangePrimaryColor;
  final void Function(String code) onChangeLanguage;
  final Color currentPrimaryColor;

  @override
  State<DocumentCenterScreen> createState() => _DocumentCenterScreenState();
}

class _DocumentCenterScreenState extends State<DocumentCenterScreen> {
  final _repo = DocumentCenterRepo();
  final _search = TextEditingController();
  List<MobileDocument> _documents = [];
  List<String> _failures = [];
  DocumentKind? _kind;
  DocumentStatusGroup _status = DocumentStatusGroup.all;
  DateTimeRange? _dates;
  bool _loading = true;
  String? _error;

  PermissionService get _permissions => AccessScope.of(context).permissions;

  List<DocumentKind> get _availableKinds => DocumentKind.values
      .where((kind) => canViewDocumentKind(_permissions, kind))
      .toList();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _repo.list(
        permissions: _permissions,
        search: _search.text,
        kinds: _kind == null ? null : {_kind!},
        status: _status,
        from: _dates?.start,
        to: _dates?.end,
      );
      if (!mounted) return;
      setState(() {
        _documents = result.documents;
        _failures = result.failures;
        _loading = false;
        if (_documents.isEmpty && _failures.isNotEmpty) {
          _error = _failures.join('\n');
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _pickDates() async {
    final now = DateTime.now();
    final selected = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 10),
      lastDate: DateTime(now.year + 2),
      initialDateRange: _dates,
    );
    if (selected == null || !mounted) return;
    setState(() => _dates = selected);
    await _load();
  }

  Future<void> _open(MobileDocument document) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => DocumentDetailScreen(
          document: document,
          permissions: _permissions,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppTopBar(
        title: l10n.documentsTitle,
        onToggleTheme: widget.onToggleTheme,
        onChangePrimaryColor: widget.onChangePrimaryColor,
        onChangeLanguage: widget.onChangeLanguage,
        currentPrimaryColor: widget.currentPrimaryColor,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: TextField(
                  controller: _search,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _load(),
                  decoration: InputDecoration(
                    hintText: l10n.documentSearchHint,
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: IconButton(
                      tooltip: l10n.searchAction,
                      onPressed: _load,
                      icon: const Icon(Icons.arrow_forward),
                    ),
                  ),
                ),
              ),
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    Padding(
                      padding: const EdgeInsetsDirectional.only(end: 8),
                      child: ChoiceChip(
                        label: Text(l10n.allDocuments),
                        selected: _kind == null,
                        onSelected: (_) {
                          setState(() => _kind = null);
                          _load();
                        },
                      ),
                    ),
                    ..._availableKinds.map(
                      (kind) => Padding(
                        padding: const EdgeInsetsDirectional.only(end: 8),
                        child: ChoiceChip(
                          avatar: Icon(_kindIcon(kind), size: 17),
                          label: Text(_kindLabel(kind, l10n)),
                          selected: _kind == kind,
                          onSelected: (_) {
                            setState(() => _kind = kind);
                            _load();
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final statusPicker =
                        DropdownButtonFormField<DocumentStatusGroup>(
                      initialValue: _status,
                      decoration: InputDecoration(
                        labelText: l10n.status,
                        isDense: true,
                      ),
                      items: DocumentStatusGroup.values
                          .map((group) => DropdownMenuItem(
                                value: group,
                                child: Text(_statusGroupLabel(group, l10n)),
                              ))
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _status = value);
                        _load();
                      },
                    );
                    final datePicker = Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: OutlinedButton.icon(
                            onPressed: _pickDates,
                            icon: const Icon(Icons.date_range_outlined),
                            label: Text(
                              _dates == null
                                  ? l10n.dates
                                  : '${_shortDate(_dates!.start)} – ${_shortDate(_dates!.end)}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        if (_dates != null)
                          IconButton(
                            tooltip: l10n.clearDates,
                            onPressed: () {
                              setState(() => _dates = null);
                              _load();
                            },
                            icon: const Icon(Icons.close),
                          ),
                      ],
                    );
                    if (constraints.maxWidth < 470) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          statusPicker,
                          const SizedBox(height: 8),
                          datePicker,
                        ],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(child: statusPicker),
                        const SizedBox(width: 10),
                        Flexible(child: datePicker),
                      ],
                    );
                  },
                ),
              ),
              if (_failures.isNotEmpty && _documents.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 2),
                  child: MaterialBanner(
                    content: Text(
                      '${_failures.length} ${l10n.documentSourcesFailed}',
                    ),
                    leading: const Icon(Icons.warning_amber_rounded),
                    actions: [
                      TextButton(onPressed: _load, child: Text(l10n.retry)),
                    ],
                  ),
                ),
              Expanded(child: _body()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body() {
    final l10n = AppLocalizations.of(context)!;
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(28),
          children: [
            const SizedBox(height: 80),
            const Icon(Icons.cloud_off_outlined, size: 54),
            const SizedBox(height: 14),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 14),
            Center(
              child: FilledButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: Text(l10n.retry),
              ),
            ),
          ],
        ),
      );
    }
    if (_documents.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(28),
          children: [
            const SizedBox(height: 100),
            const Icon(Icons.folder_open_outlined, size: 58),
            const SizedBox(height: 14),
            Text(l10n.noDocumentsFilters, textAlign: TextAlign.center),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 28),
        itemCount: _documents.length,
        separatorBuilder: (_, __) => const SizedBox(height: 6),
        itemBuilder: (context, index) {
          final document = _documents[index];
          return Card(
            child: ListTile(
              leading: CircleAvatar(child: Icon(_kindIcon(document.kind))),
              title: Text(
                document.number.isEmpty
                    ? '${_kindLabel(document.kind, l10n)} #${document.id}'
                    : document.number,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                '${_kindLabel(document.kind, l10n)}${document.party.isEmpty ? '' : ' • ${document.party}'}\n${document.date}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              isThreeLine: true,
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _StatusChip(document.status, l10n: l10n),
                  if (document.total != 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '${document.total.toStringAsFixed(3)} ${document.currency}',
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                    ),
                ],
              ),
              onTap: () => _open(document),
            ),
          );
        },
      ),
    );
  }
}

class DocumentDetailScreen extends StatefulWidget {
  const DocumentDetailScreen({
    super.key,
    required this.document,
    required this.permissions,
  });

  final MobileDocument document;
  final PermissionService permissions;

  @override
  State<DocumentDetailScreen> createState() => _DocumentDetailScreenState();
}

class _DocumentDetailScreenState extends State<DocumentDetailScreen> {
  final _repo = DocumentCenterRepo();
  DocumentDetails? _details;
  String? _error;
  bool _loading = true;
  bool _loadingPdf = false;

  MobileDocument get _document => _details?.document ?? widget.document;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final details = await _repo.detail(widget.document);
      if (!mounted) return;
      setState(() {
        _details = details;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _previewPdf() async {
    if (_loadingPdf || !_document.canPreviewPdf) return;
    setState(() => _loadingPdf = true);
    try {
      final bytes = await _repo.pdf(
        _document,
        Localizations.localeOf(context).languageCode,
      );
      if (!mounted) return;
      await Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) => PdfPreviewScreen(
            pdfBytes: bytes,
            title: _document.number.isEmpty
                ? _kindLabel(
                    _document.kind,
                    AppLocalizations.of(context)!,
                  )
                : _document.number,
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      AppAlerts.error(
        context,
        error.toString().replaceFirst('Exception: ', ''),
      );
    } finally {
      if (mounted) setState(() => _loadingPdf = false);
    }
  }

  Future<void> _openRelation(DocumentRelation relation) async {
    if (!canViewDocumentKind(widget.permissions, relation.kind)) {
      AppAlerts.error(
        context,
        AppLocalizations.of(context)!.cannotViewRelatedDocument,
      );
      return;
    }
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => DocumentDetailScreen(
          permissions: widget.permissions,
          document: MobileDocument(
            id: relation.id,
            kind: relation.kind,
            number: relation.number,
            party: '',
            status: '',
            date: '',
            total: 0,
            currency: 'TND',
            raw: const {},
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(_document.number.isEmpty
            ? _kindLabel(_document.kind, l10n)
            : _document.number),
        actions: [
          if (_document.canPreviewPdf)
            IconButton(
              tooltip: l10n.previewOrSharePdf,
              onPressed: _loadingPdf ? null : _previewPdf,
              icon: _loadingPdf
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.picture_as_pdf_outlined),
            ),
        ],
      ),
      body: _body(),
    );
  }

  Widget _body() {
    final l10n = AppLocalizations.of(context)!;
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 52),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: Text(l10n.retry),
              ),
            ],
          ),
        ),
      );
    }
    final details = _details!;
    final fields = _headerFields(details, l10n);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1000),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                            child: Icon(_kindIcon(details.document.kind))),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_kindLabel(details.document.kind, l10n),
                                  style:
                                      Theme.of(context).textTheme.labelLarge),
                              Text(
                                details.document.number.isEmpty
                                    ? '#${details.document.id}'
                                    : details.document.number,
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                            ],
                          ),
                        ),
                        _StatusChip(
                          _first(details.header, ['status']),
                          l10n: l10n,
                        ),
                      ],
                    ),
                    const Divider(height: 28),
                    ...fields.map(
                      (field) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 115,
                              child: Text(field.key,
                                  style:
                                      Theme.of(context).textTheme.labelMedium),
                            ),
                            Expanded(child: Text(field.value)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (details.relations.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(l10n.relatedDocuments,
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 6),
              Card(
                child: Column(
                  children: details.relations
                      .map((relation) => ListTile(
                            leading: Icon(_kindIcon(relation.kind)),
                            title: Text(_kindLabel(relation.kind, l10n)),
                            subtitle: Text(relation.number.isEmpty
                                ? '#${relation.id}'
                                : relation.number),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => _openRelation(relation),
                          ))
                      .toList(),
                ),
              ),
            ],
            if (details.items.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('${l10n.lines} (${details.items.length})',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 6),
              ...details.items.map(
                (item) => Card(
                  child: ListTile(
                    title: Text(_lineTitle(item, l10n)),
                    subtitle: Text(_lineDetails(item, l10n)),
                    trailing: _lineTotal(item).isEmpty
                        ? null
                        : Text(_lineTotal(item)),
                  ),
                ),
              ),
            ],
            ..._extraSections(details, l10n),
            const SizedBox(height: 28),
          ],
        ),
      ),
    );
  }

  List<MapEntry<String, String>> _headerFields(
    DocumentDetails details,
    AppLocalizations l10n,
  ) {
    final h = details.header;
    final fields = <MapEntry<String, String>>[];
    void add(String label, List<String> keys) {
      final value = _first(h, keys);
      if (value.isNotEmpty) fields.add(MapEntry(label, value));
    }

    add(l10n.party, [
      'client_name',
      'custom_name',
      'supplierName',
      'supplier_name',
      'category'
    ]);
    add(l10n.dateLabel, [
      'invoice_date',
      'invoiceDate',
      'order_date',
      'orderDate',
      'delivery_date',
      'receivedDate',
      'expense_date'
    ]);
    add(l10n.dueExpected, [
      'invoice_due_date',
      'dueDate',
      'expected_delivery_date',
      'expectedDate'
    ]);
    add(l10n.totalLabel,
        ['total_tnd', 'totalTtcTnd', 'total', 'totalTtc', 'amount']);
    add(l10n.currency, ['currency']);
    add(l10n.balance, ['remaining_balance', 'balanceTnd', 'balance']);
    add(l10n.match, ['matchStatus']);
    add(l10n.sourceOrder, [
      'source_devis_number',
      'order_number',
      'sourceSupplierOrderNumber',
      'supplierOrderNumber'
    ]);
    add(l10n.invoiceNumber, ['invoiceNumber']);
    add(l10n.deliveryNote, ['supplierDeliveryNoteNumber']);
    add(l10n.exception, ['exceptionType']);
    add(l10n.exceptionReason, ['exceptionReason']);
    add(l10n.source, ['source_document_number']);
    add(l10n.descriptionLabel, ['description']);
    add(l10n.notes, ['notes']);
    return fields;
  }

  List<Widget> _extraSections(
    DocumentDetails details,
    AppLocalizations l10n,
  ) {
    final widgets = <Widget>[];
    for (final entry in details.extra.entries) {
      final rows = entry.value is List
          ? (entry.value as List).whereType<Map>().toList()
          : const <Map>[];
      if (rows.isEmpty) continue;
      widgets.add(const SizedBox(height: 16));
      widgets.add(Text(
        '${_extraSectionLabel(entry.key, l10n)} (${rows.length})',
        style: Theme.of(context).textTheme.titleMedium,
      ));
      widgets.add(const SizedBox(height: 6));
      widgets.add(Card(
        child: Column(
          children: rows
              .map((row) => ListTile(
                    leading: const Icon(Icons.receipt_long_outlined),
                    title: Text(_first(Map<String, dynamic>.from(row), [
                      'reference_number',
                      'credit_number',
                      'certificate_number',
                      'withholding_type',
                      'reason',
                      'status',
                      'id'
                    ])),
                    subtitle: Text(_first(Map<String, dynamic>.from(row), [
                      'payment_date',
                      'credit_date',
                      'return_date',
                      'created_at'
                    ])),
                    trailing: Text(_first(Map<String, dynamic>.from(row),
                        ['amount_tnd', 'amount', 'quantity'])),
                  ))
              .toList(),
        ),
      ));
    }
    return widgets;
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip(this.status, {required this.l10n});
  final String status;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final value = status.trim().isEmpty ? 'UNKNOWN' : status.toUpperCase();
    final color = switch (value) {
      'PAID' ||
      'DELIVERED' ||
      'RECEIVED' ||
      'REVIEWED' ||
      'VALIDATED' ||
      'ACCEPTED' =>
        Colors.green,
      'CANCELLED' || 'REJECTED' => Theme.of(context).colorScheme.error,
      'DRAFT' => Colors.blueGrey,
      _ => Colors.orange,
    };
    final label = _statusLabel(value, l10n);
    return Semantics(
      label: '${l10n.status}: $label',
      child: Container(
        constraints: const BoxConstraints(maxWidth: 110),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .13),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

IconData _kindIcon(DocumentKind kind) => switch (kind) {
      DocumentKind.invoice => Icons.receipt_long_outlined,
      DocumentKind.quotation => Icons.request_quote_outlined,
      DocumentKind.creditNote => Icons.assignment_return_outlined,
      DocumentKind.salesOrder => Icons.shopping_bag_outlined,
      DocumentKind.deliveryNote => Icons.local_shipping_outlined,
      DocumentKind.supplierOrder => Icons.shopping_cart_outlined,
      DocumentKind.supplierReception => Icons.move_to_inbox_outlined,
      DocumentKind.supplierInvoice => Icons.receipt_outlined,
      DocumentKind.expense => Icons.payments_outlined,
    };

String _kindLabel(DocumentKind kind, AppLocalizations l10n) => switch (kind) {
      DocumentKind.invoice => l10n.kindInvoice,
      DocumentKind.quotation => l10n.kindQuotation,
      DocumentKind.creditNote => l10n.kindCreditNote,
      DocumentKind.salesOrder => l10n.kindSalesOrder,
      DocumentKind.deliveryNote => l10n.kindDeliveryNote,
      DocumentKind.supplierOrder => l10n.kindSupplierOrder,
      DocumentKind.supplierReception => l10n.kindSupplierReception,
      DocumentKind.supplierInvoice => l10n.kindSupplierInvoice,
      DocumentKind.expense => l10n.kindExpense,
    };

String _statusGroupLabel(
  DocumentStatusGroup status,
  AppLocalizations l10n,
) =>
    switch (status) {
      DocumentStatusGroup.all => l10n.allStatuses,
      DocumentStatusGroup.draft => l10n.statusDraftMobile,
      DocumentStatusGroup.open => l10n.statusOpen,
      DocumentStatusGroup.completed => l10n.statusCompleted,
      DocumentStatusGroup.cancelled => l10n.statusCancelledMobile,
    };

String _statusLabel(String status, AppLocalizations l10n) => switch (status) {
      'PAID' => l10n.statusPaid,
      'UNPAID' => l10n.statusUnpaid,
      'PENDING' => l10n.statusPending,
      'REJECTED' => l10n.statusRejected,
      'CANCELLED' => l10n.statusCancelledMobile,
      'DRAFT' => l10n.statusDraftMobile,
      _ => status.replaceAll('_', ' '),
    };

String _extraSectionLabel(String key, AppLocalizations l10n) => switch (key) {
      'payments' => l10n.customerPaymentLedger,
      'withholdings' => l10n.withholdingCertificates,
      'credits' => l10n.supplierCredits,
      'returns' => l10n.supplierReturns,
      _ => '${key[0].toUpperCase()}${key.substring(1)}'.replaceAll('_', ' '),
    };

String _first(Map<String, dynamic> row, List<String> keys) {
  for (final key in keys) {
    final value = row[key];
    if (value != null && '$value'.trim().isNotEmpty) return '$value';
  }
  return '';
}

String _lineTitle(Map<String, dynamic> item, AppLocalizations l10n) {
  final value = _first(item, [
    'description',
    'product',
    'name',
    'product_code',
    'code',
  ]);
  return value.isEmpty ? l10n.documentLine : value;
}

String _lineDetails(Map<String, dynamic> item, AppLocalizations l10n) {
  final accepted = _first(item, ['acceptedQty']);
  final damaged = _first(item, ['damagedQty']);
  final rejected = _first(item, ['rejectedQty']);
  if (accepted.isNotEmpty || damaged.isNotEmpty || rejected.isNotEmpty) {
    return '${l10n.accepted} ${accepted.isEmpty ? '0' : accepted} • '
        '${l10n.damaged} ${damaged.isEmpty ? '0' : damaged} • '
        '${l10n.rejected} ${rejected.isEmpty ? '0' : rejected}';
  }
  final qty = _first(item, ['invoiceQty', 'quantity', 'qty']);
  final price = _first(item, ['invoicePrice', 'unit_price', 'price']);
  final match = _first(item, ['matchStatus']);
  return [
    if (qty.isNotEmpty) '${l10n.quantityShort} $qty',
    if (price.isNotEmpty) '${l10n.price} $price',
    if (match.isNotEmpty) match,
  ].join(' • ');
}

String _lineTotal(Map<String, dynamic> item) => _first(item,
    ['totalTtc', 'subtotalTTC', 'lineTotal', 'total_ttc', 'total', 'subtotal']);

String _shortDate(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
