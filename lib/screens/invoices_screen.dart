import 'package:flutter/material.dart';
import 'package:my_app/l10n/app_localizations.dart';
import 'package:my_app/storage/invoices_repo.dart';
import 'create_invoice_screen.dart';
import 'invoice_edit_screen.dart';

class InvoicesScreen extends StatefulWidget {
  const InvoicesScreen({super.key});

  @override
  State<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends State<InvoicesScreen> {
  final InvoicesRepo _repo = InvoicesRepo();

  bool _loading = true;
  bool _didLoadOnce = false;
  List<Map<String, dynamic>> _invoices = [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didLoadOnce) {
      _didLoadOnce = true;
      _load();
    }
  }

  Future<void> _openCreate() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CreateInvoiceScreen()),
    );

    if (!mounted) return;
    await _load();
  }

  Future<void> _openEdit(int invoiceId) async {
    if (invoiceId <= 0) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InvoiceEditScreen(invoiceId: invoiceId),
      ),
    );

    if (!mounted) return;
    await _load();
  }

  Future<void> _load() async {
    final l10n = AppLocalizations.of(context)!;

    if (mounted) {
      setState(() => _loading = true);
    }

    try {
      final data = await _repo.getAllInvoices();

      if (!mounted) return;

      setState(() {
        _invoices = List<Map<String, dynamic>>.from(data);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _invoices = [];
        _loading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${l10n.loadFailed}: ${e.toString().replaceFirst('Exception: ', '')}',
          ),
        ),
      );
    }
  }

  int _toInt(dynamic v, [int fallback = 0]) {
    if (v == null) return fallback;
    if (v is int) return v;
    return int.tryParse(v.toString()) ?? fallback;
  }

  double _toDouble(dynamic value, [double fallback = 0.0]) {
    if (value == null) return fallback;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? fallback;
  }

  DateTime _parseDate(dynamic value) {
    if (value == null) return DateTime.now();
    return DateTime.tryParse(value.toString()) ?? DateTime.now();
  }

  String _daysLeftText(DateTime due) {
    final l10n = AppLocalizations.of(context)!;

    final now = DateTime.now();
    final d0 = DateTime(now.year, now.month, now.day);
    final d1 = DateTime(due.year, due.month, due.day);
    final diff = d1.difference(d0).inDays;

    if (diff > 0) {
      return l10n.dueInDays(diff.toString(), diff == 1 ? '' : 's');
    }
    if (diff == 0) {
      return l10n.dueToday;
    }

    final late = diff.abs();
    return l10n.overdueByDays(late.toString(), late == 1 ? '' : 's');
  }

  bool _isOverdue(String status, DateTime due) {
    final now = DateTime.now();
    final dueOnly = DateTime(due.year, due.month, due.day);
    final today = DateTime(now.year, now.month, now.day);

    return status.toUpperCase() != 'PAID' && dueOnly.isBefore(today);
  }

  Color _statusBg(String status, bool isOverdue, ColorScheme cs) {
    final s = status.toUpperCase();
    if (s == 'PAID') return cs.primaryContainer;
    if (isOverdue) return cs.errorContainer;
    return cs.tertiaryContainer;
  }

  Color _statusFg(String status, bool isOverdue, ColorScheme cs) {
    final s = status.toUpperCase();
    if (s == 'PAID') return cs.onPrimaryContainer;
    if (isOverdue) return cs.onErrorContainer;
    return cs.onTertiaryContainer;
  }

  String _money(dynamic value) {
    final n = _toDouble(value);
    return n.toStringAsFixed(3);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.invoices),
        actions: [
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
            tooltip: l10n.refresh,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreate,
        icon: const Icon(Icons.add),
        label: Text(l10n.newInvoice),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _invoices.isEmpty
                ? _EmptyInvoices(onCreate: _openCreate)
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: _invoices.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, i) {
                        final inv = _invoices[i];

                        final invoiceId = _toInt(inv['id']);
                        final invNumber = (inv['invoice'] ?? '').toString();
                        final status = (inv['status'] ?? 'open').toString();
                        final total = _money(inv['total']);
                        final subtotal = _money(inv['subtotal']);
                        final vatAmount = _money(inv['montant_tva']);
                        final email = (inv['custom_email'] ?? '').toString();
                        final code = (inv['custom_code'] ?? '').toString();
                        final invoiceType =
                            (inv['invoice_type'] ?? '').toString();
                        final typeDoc = (inv['type_doc'] ?? '').toString();

                        final due = _parseDate(inv['invoice_due_date']);
                        final issue = _parseDate(inv['invoice_date']);
                        final overdue = _isOverdue(status, due);

                        return Card(
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    invNumber.isEmpty ? l10n.invoice : invNumber,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                _StatusPill(
                                  text: overdue
                                      ? l10n.overdue.toUpperCase()
                                      : status.toUpperCase(),
                                  bg: _statusBg(status, overdue, cs),
                                  fg: _statusFg(status, overdue, cs),
                                ),
                              ],
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (email.isNotEmpty)
                                    Text(
                                      email,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  if (code.isNotEmpty ||
                                      invoiceType.isNotEmpty ||
                                      typeDoc.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        [
                                          if (code.isNotEmpty)
                                            '${l10n.code}: $code',
                                          if (invoiceType.isNotEmpty)
                                            '${l10n.type}: $invoiceType',
                                          if (typeDoc.isNotEmpty)
                                            '${l10n.doc}: $typeDoc',
                                        ].join(' • '),
                                      ),
                                    ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${_daysLeftText(due)} • ${l10n.issued} ${issue.toLocal().toString().split(' ')[0]}',
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'HT $subtotal • TVA $vatAmount',
                                    style: TextStyle(
                                      color: cs.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '$total TND',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Icon(
                                  Icons.chevron_right,
                                  color: cs.onSurfaceVariant,
                                ),
                              ],
                            ),
                            onTap: () => _openEdit(invoiceId),
                          ),
                        );
                      },
                    ),
                  ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String text;
  final Color bg;
  final Color fg;

  const _StatusPill({
    required this.text,
    required this.bg,
    required this.fg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontWeight: FontWeight.w900,
          color: fg,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _EmptyInvoices extends StatelessWidget {
  final Future<void> Function() onCreate;

  const _EmptyInvoices({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 80),
        Icon(
          Icons.receipt_long,
          size: 70,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(height: 14),
        Center(
          child: Text(
            l10n.noInvoicesYet,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Center(
          child: Text(
            l10n.createYourFirstInvoiceToSeeItHere,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(height: 18),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: SizedBox(
            height: 48,
            child: FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add),
              label: Text(l10n.createInvoice),
            ),
          ),
        ),
      ],
    );
  }
}