import 'package:flutter/material.dart';
import 'package:my_app/l10n/app_localizations.dart';
import 'package:my_app/widgets/app_alerts.dart';
import 'package:my_app/screens/create_invoice_screen.dart';
import 'package:my_app/screens/invoice_edit_screen.dart';
import 'package:my_app/services/currency_service.dart';
import 'package:my_app/services/settings_service.dart';
import 'package:my_app/storage/invoices_repo.dart';

class InvoicesScreen extends StatefulWidget {
  final int initialInvoiceId;

  const InvoicesScreen({
    super.key,
    this.initialInvoiceId = 0,
  });

  @override
  State<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends State<InvoicesScreen> {
  final InvoicesRepo _repo = InvoicesRepo();
  final SettingsService _settingsService = SettingsService();
  final TextEditingController _searchCtrl = TextEditingController();

  bool _loading = true;
  bool _didLoadOnce = false;
  bool _updatingStatus = false;
  String _currency = 'TND';
  String _statusFilter = 'all';
  List<Map<String, dynamic>> _invoices = [];

  List<Map<String, dynamic>> get _filteredInvoices {
    final query = _searchCtrl.text.trim().toLowerCase();

    final filtered = _invoices.where((inv) {
      final invoiceNumber = (inv['invoice'] ?? '').toString().toLowerCase();
      final email = (inv['custom_email'] ?? '').toString().toLowerCase();
      final code = (inv['custom_code'] ?? '').toString().toLowerCase();
      final invoiceType = (inv['invoice_type'] ?? '').toString().toLowerCase();
      final typeDoc = (inv['type_doc'] ?? '').toString().toLowerCase();
      final clientName = (
        inv['client_name'] ??
        inv['custom_name'] ??
        inv['customer_name'] ??
        inv['name'] ??
        ''
      ).toString().toLowerCase();
      final status = _normalizedStatus((inv['status'] ?? 'UNPAID').toString()).toLowerCase();

      final matchesStatus =
          _statusFilter == 'all' ? true : status == _statusFilter;

      final matchesQuery = query.isEmpty ||
          invoiceNumber.contains(query) ||
          email.contains(query) ||
          code.contains(query) ||
          invoiceType.contains(query) ||
          typeDoc.contains(query) ||
          clientName.contains(query);

      return matchesStatus && matchesQuery;
    }).toList();

    filtered.sort((a, b) {
      final aStatus = _normalizedStatus((a['status'] ?? 'UNPAID').toString());
      final bStatus = _normalizedStatus((b['status'] ?? 'UNPAID').toString());
      final aDue = _parseDate(a['invoice_due_date']);
      final bDue = _parseDate(b['invoice_due_date']);

      final aOverdue = _isOverdue(aStatus, aDue);
      final bOverdue = _isOverdue(bStatus, bDue);

      if (aOverdue != bOverdue) {
        return aOverdue ? -1 : 1;
      }

      if (aStatus == 'UNPAID' && bStatus != 'UNPAID') return -1;
      if (aStatus != 'UNPAID' && bStatus == 'UNPAID') return 1;

      return bDue.compareTo(aDue);
    });

    return filtered;
  }

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
      MaterialPageRoute(builder: (_) => CreateInvoiceScreen()),
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
      final currency = await _settingsService.getCurrency();

      if (!mounted) return;

      setState(() {
        _invoices = List<Map<String, dynamic>>.from(data);
        _currency = currency;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _invoices = [];
        _loading = false;
      });

      AppAlerts.error(
        context,
        '${l10n.loadFailed}: ${e.toString().replaceFirst('Exception: ', '')}',
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

  String _normalizedStatus(String status) {
    final s = status.trim().toUpperCase();
    if (s == 'OPEN' || s == 'DRAFT') return 'UNPAID';
    if (s == 'PAID') return 'PAID';
    if (s == 'CANCELLED' || s == 'CANCELED') return 'CANCELLED';
    return 'UNPAID';
  }

  String _statusLabel(String status, AppLocalizations l10n) {
    final s = _normalizedStatus(status);
    if (s == 'PAID') return l10n.paidLabel.toUpperCase();
    if (s == 'CANCELLED') return l10n.cancelledLabel.toUpperCase();
    return l10n.unpaidLabel.toUpperCase();
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
    final normalized = _normalizedStatus(status);
    final now = DateTime.now();
    final dueOnly = DateTime(due.year, due.month, due.day);
    final today = DateTime(now.year, now.month, now.day);

    return normalized != 'PAID' &&
        normalized != 'CANCELLED' &&
        dueOnly.isBefore(today);
  }

  bool _isDueSoon(String status, DateTime due) {
    final normalized = _normalizedStatus(status);
    if (normalized == 'PAID' || normalized == 'CANCELLED') return false;

    final now = DateTime.now();
    final d0 = DateTime(now.year, now.month, now.day);
    final d1 = DateTime(due.year, due.month, due.day);
    final diff = d1.difference(d0).inDays;

    return diff >= 0 && diff <= 3;
  }

  Color _statusBg(String status, bool isOverdue, ColorScheme cs) {
    final s = _normalizedStatus(status);
    if (s == 'PAID') return cs.primaryContainer;
    if (s == 'CANCELLED') return cs.surfaceContainerHighest;
    if (isOverdue) return cs.errorContainer;
    return cs.tertiaryContainer;
  }

  Color _statusFg(String status, bool isOverdue, ColorScheme cs) {
    final s = _normalizedStatus(status);
    if (s == 'PAID') return cs.onPrimaryContainer;
    if (s == 'CANCELLED') return cs.onSurfaceVariant;
    if (isOverdue) return cs.onErrorContainer;
    return cs.onTertiaryContainer;
  }

  Future<void> _updateInvoiceStatus(int invoiceId, String status) async {
    final l10n = AppLocalizations.of(context)!;

    if (_updatingStatus) return;

    setState(() {
      _updatingStatus = true;
    });

    try {
      await _repo.updateInvoiceStatus(invoiceId, status);
      if (!mounted) return;

      AppAlerts.success(context, l10n.invoiceStatusUpdated);

      await _load();
    } catch (e) {
      if (!mounted) return;
      AppAlerts.error(
        context,
        '${l10n.updateFailed}: ${e.toString().replaceFirst('Exception: ', '')}',
      );
    } finally {
      if (mounted) {
        setState(() {
          _updatingStatus = false;
        });
      }
    }
  }

  Future<void> _showStatusSheet(int invoiceId, String currentStatus) async {
    final l10n = AppLocalizations.of(context)!;
    final normalized = _normalizedStatus(currentStatus);

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.changeStatus,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 14),
                _StatusActionTile(
                  icon: Icons.check_circle_outline,
                  title: l10n.markAsPaid,
                  selected: normalized == 'PAID',
                  onTap: () async {
                    Navigator.pop(context);
                    await _updateInvoiceStatus(invoiceId, 'PAID');
                  },
                ),
                const SizedBox(height: 8),
                _StatusActionTile(
                  icon: Icons.schedule_outlined,
                  title: l10n.markAsUnpaid,
                  selected: normalized == 'UNPAID',
                  onTap: () async {
                    Navigator.pop(context);
                    await _updateInvoiceStatus(invoiceId, 'UNPAID');
                  },
                ),
                const SizedBox(height: 8),
                _StatusActionTile(
                  icon: Icons.cancel_outlined,
                  title: l10n.markAsCancelled,
                  selected: normalized == 'CANCELLED',
                  onTap: () async {
                    Navigator.pop(context);
                    await _updateInvoiceStatus(invoiceId, 'CANCELLED');
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final filteredInvoices = _filteredInvoices;

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
            : Column(
                children: [
                  TextField(
                    controller: _searchCtrl,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: l10n.searchInvoiceClientEmail,
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchCtrl.text.isEmpty
                          ? null
                          : IconButton(
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() {});
                              },
                              icon: const Icon(Icons.close),
                            ),
                      filled: true,
                      fillColor: cs.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: cs.outlineVariant.withOpacity(0.35),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: cs.primary,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _FilterChip(
                          label: l10n.all,
                          selected: _statusFilter == 'all',
                          onTap: () => setState(() => _statusFilter = 'all'),
                        ),
                        const SizedBox(width: 8),
                        _FilterChip(
                          label: l10n.unpaidLabel,
                          selected: _statusFilter == 'unpaid',
                          onTap: () => setState(() => _statusFilter = 'unpaid'),
                        ),
                        const SizedBox(width: 8),
                        _FilterChip(
                          label: l10n.paidLabel,
                          selected: _statusFilter == 'paid',
                          onTap: () => setState(() => _statusFilter = 'paid'),
                        ),
                        const SizedBox(width: 8),
                        _FilterChip(
                          label: l10n.cancelledLabel,
                          selected: _statusFilter == 'cancelled',
                          onTap: () => setState(() => _statusFilter = 'cancelled'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: _invoices.isEmpty
                        ? _EmptyInvoices(onCreate: _openCreate)
                        : filteredInvoices.isEmpty
                            ? ListView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                children: [
                                  const SizedBox(height: 80),
                                  Center(
                                    child: Text(l10n.noInvoicesMatchSearch),
                                  ),
                                ],
                              )
                            : RefreshIndicator(
                                onRefresh: _load,
                                child: ListView.separated(
                                  physics: const AlwaysScrollableScrollPhysics(),
                                  itemCount: filteredInvoices.length,
                                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                                  itemBuilder: (context, i) {
                                    final inv = filteredInvoices[i];

                                    final invoiceId = _toInt(inv['id']);
                                    final invNumber = (inv['invoice'] ?? '').toString();
                                    final status = _normalizedStatus((inv['status'] ?? 'UNPAID').toString());
                                    final totalValue = _toDouble(inv['total']);
                                    final subtotalValue = _toDouble(inv['subtotal']);
                                    final vatAmountValue = _toDouble(inv['montant_tva']);
                                    final total = CurrencyService.format(totalValue, _currency);
                                    final subtotal = CurrencyService.format(subtotalValue, _currency);
                                    final vatAmount = CurrencyService.format(vatAmountValue, _currency);
                                    final email = (inv['custom_email'] ?? '').toString();
                                    final code = (inv['custom_code'] ?? '').toString();
                                    final invoiceType = (inv['invoice_type'] ?? '').toString();
                                    final typeDoc = (inv['type_doc'] ?? '').toString();
                                    final clientName = (
                                      inv['client_name'] ??
                                      inv['custom_name'] ??
                                      inv['customer_name'] ??
                                      inv['name'] ??
                                      ''
                                    ).toString();

                                    final due = _parseDate(inv['invoice_due_date']);
                                    final issue = _parseDate(inv['invoice_date']);
                                    final overdue = _isOverdue(status, due);
                                    final dueSoon = _isDueSoon(status, due);

                                    return InkWell(
                                      borderRadius: BorderRadius.circular(22),
                                      onTap: () => _openEdit(invoiceId),
                                      child: Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: cs.surface,
                                          borderRadius: BorderRadius.circular(22),
                                          border: Border.all(
                                            color: overdue
                                                ? cs.error.withOpacity(0.30)
                                                : (dueSoon
                                                    ? cs.tertiary.withOpacity(0.28)
                                                    : cs.outlineVariant.withOpacity(0.28)),
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Theme.of(context).shadowColor.withOpacity(
                                                Theme.of(context).brightness == Brightness.dark ? 0.22 : 0.08,
                                              ),
                                              blurRadius: 20,
                                              offset: const Offset(0, 6),
                                            ),
                                          ],
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        invNumber.isEmpty ? l10n.invoice : invNumber,
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                        style: theme.textTheme.titleMedium?.copyWith(
                                                          fontWeight: FontWeight.w900,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 6),
                                                      if (clientName.trim().isNotEmpty)
                                                        Text(
                                                          clientName,
                                                          maxLines: 1,
                                                          overflow: TextOverflow.ellipsis,
                                                          style: theme.textTheme.bodyLarge?.copyWith(
                                                            fontWeight: FontWeight.w800,
                                                          ),
                                                        ),
                                                      if (email.isNotEmpty)
                                                        Padding(
                                                          padding: const EdgeInsets.only(top: 3),
                                                          child: Text(
                                                            email,
                                                            maxLines: 1,
                                                            overflow: TextOverflow.ellipsis,
                                                            style: theme.textTheme.bodyMedium?.copyWith(
                                                              color: cs.onSurfaceVariant,
                                                              fontWeight: FontWeight.w600,
                                                            ),
                                                          ),
                                                        ),
                                                    ],
                                                  ),
                                                ),
                                                const SizedBox(width: 10),
                                                Column(
                                                  crossAxisAlignment: CrossAxisAlignment.end,
                                                  children: [
                                                    _StatusPill(
                                                      text: overdue
                                                          ? l10n.overdue.toUpperCase()
                                                          : _statusLabel(status, l10n),
                                                      bg: _statusBg(status, overdue, cs),
                                                      fg: _statusFg(status, overdue, cs),
                                                    ),
                                                    const SizedBox(height: 10),
                                                    Text(
                                                      total,
                                                      style: theme.textTheme.titleMedium?.copyWith(
                                                        fontWeight: FontWeight.w900,
                                                      ),
                                                    ),
                                                    Text(
                                                      _currency,
                                                      style: theme.textTheme.bodySmall?.copyWith(
                                                        color: cs.onSurfaceVariant,
                                                        fontWeight: FontWeight.w700,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 14),
                                            Wrap(
                                              spacing: 8,
                                              runSpacing: 8,
                                              children: [
                                                if (code.isNotEmpty) _MetaChip(text: '${l10n.code}: $code'),
                                                if (invoiceType.isNotEmpty) _MetaChip(text: '${l10n.type}: $invoiceType'),
                                                if (typeDoc.isNotEmpty) _MetaChip(text: '${l10n.doc}: $typeDoc'),
                                                _MetaChip(
                                                  text: '${l10n.issued} ${issue.toLocal().toString().split(' ')[0]}',
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 12),
                                            Container(
                                              width: double.infinity,
                                              padding: const EdgeInsets.all(12),
                                              decoration: BoxDecoration(
                                                color: overdue
                                                    ? cs.errorContainer.withOpacity(0.55)
                                                    : (dueSoon
                                                        ? cs.tertiaryContainer.withOpacity(0.55)
                                                        : cs.surfaceContainerHighest.withOpacity(0.45)),
                                                borderRadius: BorderRadius.circular(16),
                                              ),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Icon(
                                                        overdue
                                                            ? Icons.warning_amber_rounded
                                                            : (dueSoon
                                                                ? Icons.schedule_rounded
                                                                : Icons.event_note_rounded),
                                                        size: 18,
                                                        color: overdue
                                                            ? cs.onErrorContainer
                                                            : (dueSoon
                                                                ? cs.onTertiaryContainer
                                                                : cs.onSurfaceVariant),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      Expanded(
                                                        child: Text(
                                                          _daysLeftText(due),
                                                          style: theme.textTheme.bodyMedium?.copyWith(
                                                            fontWeight: FontWeight.w800,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 8),
                                                  Align(
                                                    alignment: Alignment.centerRight,
                                                    child: Text(
                                                      'HT $subtotal • TVA $vatAmount',
                                                      style: theme.textTheme.bodySmall?.copyWith(
                                                        color: cs.onSurfaceVariant,
                                                        fontWeight: FontWeight.w700,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(height: 12),
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: OutlinedButton.icon(
                                                    onPressed: () => _openEdit(invoiceId),
                                                    icon: const Icon(Icons.edit_outlined),
                                                    label: Text(l10n.edit),
                                                  ),
                                                ),
                                                const SizedBox(width: 10),
                                                Expanded(
                                                  child: FilledButton.icon(
                                                    onPressed: _updatingStatus
                                                        ? null
                                                        : () => _showStatusSheet(invoiceId, status),
                                                    icon: const Icon(Icons.autorenew_rounded),
                                                    label: Text(l10n.changeStatus),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                  ),
                ],
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

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final String text;

  const _MetaChip({required this.text});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withOpacity(0.55),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _StatusActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool selected;
  final VoidCallback onTap;

  const _StatusActionTile({
    required this.icon,
    required this.title,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: selected ? cs.primaryContainer.withOpacity(0.65) : cs.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? cs.primary.withOpacity(0.4) : cs.outlineVariant.withOpacity(0.25),
          ),
        ),
        child: Row(
          children: [
            Icon(icon),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ),
            if (selected) const Icon(Icons.check_circle_rounded),
          ],
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