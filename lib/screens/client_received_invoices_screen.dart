import 'package:flutter/material.dart';
import 'package:my_app/l10n/app_localizations.dart';
import 'package:my_app/screens/app_top_bar.dart';
import 'package:my_app/storage/received_invoices_repo.dart';

class ClientReceivedInvoicesScreen extends StatefulWidget {
  const ClientReceivedInvoicesScreen({super.key});

  @override
  State<ClientReceivedInvoicesScreen> createState() =>
      _ClientReceivedInvoicesScreenState();
}

class _ClientReceivedInvoicesScreenState
    extends State<ClientReceivedInvoicesScreen> {
  final ReceivedInvoicesRepo _repo = ReceivedInvoicesRepo();

  late final TextEditingController _searchCtrl;
  String _q = '';
  bool _loading = true;
  String _statusFilter = 'ALL'; // ALL | OPEN | PAID | CANCELLED
  List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    _searchCtrl = TextEditingController();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);

    try {
      final status = _statusFilter == 'ALL' ? '' : _statusFilter;
      final items = await _repo.listReceivedInvoices(limit: 200, offset: 0, status: status);
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _items = [];
        _loading = false;
      });
    }
  }

  Map<String, dynamic> _asMap(dynamic v) {
    if (v is Map<String, dynamic>) return v;
    if (v is Map) return Map<String, dynamic>.from(v);
    return <String, dynamic>{};
  }

  List<Map<String, dynamic>> _visibleItems() {
    final q = _q.trim().toLowerCase();
    if (q.isEmpty) return _items;

    bool contains(String v) => v.toLowerCase().contains(q);

    return _items.where((inv) {
      final invoiceNo = (inv['invoice'] ?? '').toString();
      final date = (inv['invoice_date'] ?? '').toString();
      final status = (inv['status'] ?? '').toString();

      final from = _asMap(inv['from']);
      final fromName = (from['name'] ?? '').toString();
      final fromEmail = (from['email'] ?? '').toString();

      return contains(invoiceNo) ||
          contains(date) ||
          contains(status) ||
          contains(fromName) ||
          contains(fromEmail);
    }).toList();
  }

  double _toDouble(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString().replaceAll(',', '.')) ?? 0;
  }

  String _money(BuildContext context, double v) {
    // Simple formatter (you can plug your CurrencyService later)
    return v.toStringAsFixed(3);
  }

  Color _statusColor(ColorScheme cs, String status) {
    final s = status.trim().toUpperCase();
    if (s == 'PAID') return cs.primary;
    if (s == 'CANCELLED' || s == 'CANCELED') return cs.error;
    if (s == 'OPEN' || s == 'UNPAID' || s == 'PENDING') return cs.tertiary;
    return cs.onSurfaceVariant;
  }

  String _statusLabel(String status) {
    final s = status.trim().toUpperCase();
    if (s.isEmpty) return '—';
    return s;
  }

  // Section header for card-based UI
  Widget _sectionTitle(BuildContext context, String text) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: t.titleSmall?.copyWith(fontWeight: FontWeight.w900),
      ),
    );
  }

  // Soft card wrapper for modern look
  Widget _softCard(BuildContext context, Widget child) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: cs.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: cs.outlineVariant.withOpacity(0.25)),
      ),
      child: child,
    );
  }

  Future<void> _openDetails(int invoiceId) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _ClientReceivedInvoiceDetailsScreen(invoiceId: invoiceId),
      ),
    );
  }

  Widget _filterChip({
    required String label,
    required String value,
  }) {
    final selected = _statusFilter == value;
    final cs = Theme.of(context).colorScheme;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      selectedColor: cs.primaryContainer.withOpacity(0.55),
      backgroundColor: cs.surfaceContainerHighest.withOpacity(0.55),
      side: BorderSide(color: cs.outlineVariant.withOpacity(0.25)),
      labelStyle: TextStyle(
        fontWeight: FontWeight.w800,
        color: selected ? cs.onPrimaryContainer : cs.onSurface,
      ),
      onSelected: (_) async {
        if (_statusFilter == value) return;
        setState(() => _statusFilter = value);
        await _load();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;

    final visible = _visibleItems();

    return Scaffold(
      appBar: AppTopBar(
        title: l10n.receivedInvoicesListTitle,
        actions: [
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: l10n.refresh,
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  // Search
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
decoration: BoxDecoration(
  color: Colors.transparent,
  borderRadius: BorderRadius.circular(18),
),
                    child: Row(
                      children: [
                        Icon(Icons.search_rounded, color: cs.onSurfaceVariant),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _searchCtrl,
                            onChanged: (v) {
                              _q = v;
                              if (mounted) setState(() {});
                            },
                            decoration: InputDecoration(
                              hintText: l10n.searchReceivedInvoicesHint,
                              border: InputBorder.none,
                              isDense: true,
                            ),
                          ),
                        ),
                        if (_q.trim().isNotEmpty)
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            onPressed: () {
                              _searchCtrl.clear();
                              _q = '';
                              if (mounted) setState(() {});
                            },
                            icon: Icon(Icons.close_rounded, color: cs.onSurfaceVariant),
                            tooltip: l10n.clear,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  // Filters section, modern card style
                  // Filters (no container)
SingleChildScrollView(
  scrollDirection: Axis.horizontal,
  child: Row(
    children: [
      _filterChip(label: l10n.all, value: 'ALL'),
      const SizedBox(width: 8),
      _filterChip(label: l10n.pending, value: 'OPEN'),
      const SizedBox(width: 8),
      _filterChip(label: l10n.paidLabel, value: 'PAID'),
      const SizedBox(width: 8),
      _filterChip(label: l10n.cancelledLabel, value: 'CANCELLED'),
    ],
  ),
),
                  const SizedBox(height: 14),
                  // _sectionTitle(context, l10n.receivedInvoicesListTitle),

                  if (visible.isEmpty)
                    _softCard(
                      context,
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          l10n.noResults,
                          style: t.bodyMedium?.copyWith(
                            color: cs.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    )
                  else
                    ...visible.map((inv) {
                      final from = _asMap(inv['from']);
                      final fromName = (from['name'] ?? '').toString().trim();
                      final fromType = (from['type'] ?? '').toString().trim(); // organization | individual
                      final status = (inv['status'] ?? '').toString().trim();
                      final invoiceNo = (inv['invoice'] ?? '').toString().trim();
                      final date = (inv['invoice_date'] ?? '').toString().trim();
                      final total = _toDouble(inv['total']);
                      final id = int.tryParse((inv['id'] ?? '0').toString()) ?? 0;
                      final stColor = _statusColor(cs, status);

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Card(
                          elevation: 0,
                          color: cs.surface,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                            side: BorderSide(color: cs.outlineVariant.withOpacity(0.25)),
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(18),
                            onTap: id <= 0 ? null : () => _openDetails(id),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  Container(
                                    height: 44,
                                    width: 44,
                                    decoration: BoxDecoration(
                                      color: cs.surfaceContainerHighest.withOpacity(0.55),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(color: cs.outlineVariant.withOpacity(0.22)),
                                    ),
                                    child: Icon(
                                      fromType == 'organization'
                                          ? Icons.business_rounded
                                          : Icons.person_rounded,
                                      color: cs.primary,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          fromName.isEmpty ? l10n.unknown : fromName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: t.titleSmall?.copyWith(fontWeight: FontWeight.w900),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '$invoiceNo • $date',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: t.bodySmall?.copyWith(
                                            color: cs.onSurfaceVariant,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: stColor.withOpacity(0.10),
                                          borderRadius: BorderRadius.circular(999),
                                          border: Border.all(color: stColor.withOpacity(0.30)),
                                        ),
                                        child: Text(
                                          _statusLabel(status),
                                          style: t.labelSmall?.copyWith(
                                            fontWeight: FontWeight.w900,
                                            color: stColor,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        _money(context, total),
                                        style: t.titleSmall?.copyWith(fontWeight: FontWeight.w900),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
    );
  }
}

class _ClientReceivedInvoiceDetailsScreen extends StatefulWidget {
  final int invoiceId;
  const _ClientReceivedInvoiceDetailsScreen({required this.invoiceId});

  @override
  State<_ClientReceivedInvoiceDetailsScreen> createState() =>
      _ClientReceivedInvoiceDetailsScreenState();
}

class _ClientReceivedInvoiceDetailsScreenState
    extends State<_ClientReceivedInvoiceDetailsScreen> {
  final ReceivedInvoicesRepo _repo = ReceivedInvoicesRepo();

  bool _loading = true;
  Map<String, dynamic>? _inv;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);

    try {
      final inv = await _repo.getReceivedInvoiceById(widget.invoiceId);
      if (!mounted) return;
      setState(() {
        _inv = inv;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _inv = null;
        _loading = false;
      });
    }
  }

  Map<String, dynamic> _asMap(dynamic v) {
    if (v is Map<String, dynamic>) return v;
    if (v is Map) return Map<String, dynamic>.from(v);
    return <String, dynamic>{};
  }

  String _safe(dynamic v) => (v ?? '').toString().trim();

  // Info row for details screen
  Widget _infoRow(BuildContext context, String label, String value) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: t.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value.isEmpty ? '—' : value,
              style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppTopBar(
        title: l10n.invoiceDetails,
        subtitle: '${l10n.receivedInvoices} #${widget.invoiceId}',
        actions: [
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: l10n.refresh,
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _inv == null
              ? Center(
                  child: Text(
                    l10n.noResults,
                    style: t.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Card(
                      elevation: 0,
                      color: cs.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                        side: BorderSide(color: cs.outlineVariant.withOpacity(0.25)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _safe(_inv!['invoice']),
                              style: t.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                            ),
                            const SizedBox(height: 8),
                            _infoRow(context, l10n.date, _safe(_inv!['invoice_date'])),
                            _infoRow(context, l10n.dueDate, _safe(_inv!['invoice_due_date'])),
                            _infoRow(context, l10n.status, _safe(_inv!['status'])),
                            _infoRow(context, l10n.total, _safe(_inv!['total'])),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Sender
                    Card(
                      elevation: 0,
                      color: cs.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                        side: BorderSide(color: cs.outlineVariant.withOpacity(0.25)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.sender,
                              style: t.titleSmall?.copyWith(fontWeight: FontWeight.w900),
                            ),
                            const SizedBox(height: 10),
                            Builder(builder: (_) {
                              final issuer = _asMap(_inv!['issuer']);
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _infoRow(context, l10n.name, _safe(issuer['name'])),
                                  _infoRow(context, l10n.email, _safe(issuer['email'])),
                                  _infoRow(context, l10n.phone, _safe(issuer['phone'])),
                                  _infoRow(context, l10n.address, _safe(issuer['address'])),
                                  _infoRow(context, l10n.accountType, _safe(issuer['type'])),
                                ],
                              );
                            }),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Receiver (me / client)
                    Card(
                      elevation: 0,
                      color: cs.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                        side: BorderSide(color: cs.outlineVariant.withOpacity(0.25)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.receiver,
                              style: t.titleSmall?.copyWith(fontWeight: FontWeight.w900),
                            ),
                            const SizedBox(height: 10),
                            Builder(builder: (_) {
                              final client = _asMap(_inv!['client']);
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _infoRow(context, l10n.name, _safe(client['name'])),
                                  _infoRow(context, l10n.email, _safe(client['email'])),
                                  _infoRow(context, l10n.phone, _safe(client['phone'])),
                                  _infoRow(context, l10n.address, _safe(client['address'])),
                                  _infoRow(context, l10n.accountType, _safe(client['type'])),
                                ],
                              );
                            }),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}