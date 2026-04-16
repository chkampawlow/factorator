import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:my_app/l10n/app_localizations.dart';
import 'package:my_app/screens/add_client_screen.dart';
import 'package:my_app/screens/create_expense_note_screen.dart';
import 'package:my_app/screens/clients_screen.dart';
import 'package:my_app/screens/invoice_edit_screen.dart';
import 'package:my_app/screens/invoices_screen.dart';
import 'package:my_app/screens/scan_invoice_screen.dart';

import '../storage/invoices_repo.dart';

import 'package:my_app/services/currency_service.dart';
import '../services/settings_service.dart';
import '../storage/clients_repo.dart';
import '../storage/dashboard_repo.dart';
import '../storage/expense_notes_repo.dart';
import '../widgets/action_tile.dart';
import '../widgets/app_top_bar.dart';

enum _ExpenseEntryMode { manual, scan }

class DashboardScreen extends StatefulWidget {
  final VoidCallback onToggleTheme;
  final void Function(Color color) onChangePrimaryColor;
  final void Function(String code) onChangeLanguage;
  final Color currentPrimaryColor;

  const DashboardScreen({
    super.key,
    required this.onToggleTheme,
    required this.onChangePrimaryColor,
    required this.onChangeLanguage,
    required this.currentPrimaryColor,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _repo = DashboardRepo();
  final _clientsRepo = ClientsRepo();
  final _settingsService = SettingsService();
  final _expenseRepo = ExpenseNotesRepo();
  final _invoicesRepo = InvoicesRepo();

  bool _loading = true;

  int _customersCount = 0;
  String _currency = 'TND';
  double _pendingAmount = 0;
  double _monthlyExpenses = 0;
  int _paidCount = 0;
  int _unpaidCount = 0;
  List<double> _monthlyRevenue = List.filled(6, 0);
  List<double> _growth = [];
  double _paymentRate = 0;

  double _avgInvoice = 0;
  List<MapEntry<String, double>> _topClients = [];

  bool _didLoadOnce = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didLoadOnce) {
      _didLoadOnce = true;
      _load();
    }
  }

  Future<int> _countCustomers() async {
    final clients = await _clientsRepo.getAllClients();
    return clients.length;
  }

  Future<Map<String, dynamic>?> _pickClientForNewInvoice() async {
    return showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _DashboardClientPickerSheet(clientsRepo: _clientsRepo),
    );
  }

  Future<void> _createInvoiceAndOpenEditor() async {
    final l10n = AppLocalizations.of(context)!;

    final selectedClient = await _pickClientForNewInvoice();
    if (!mounted) return;

    if (selectedClient == null) {
      // Either no clients or user dismissed
      return;
    }

    final clientId =
        int.tryParse((selectedClient['id'] ?? '0').toString()) ?? 0;
    if (clientId <= 0) return;

    try {
      final now = DateTime.now();
      final draftId = await _invoicesRepo.createInvoiceHeader(
        clientId: clientId,
        issueDate: now,
        dueDate: now.add(const Duration(days: 7)),
        status: 'DRAFT',
        subtotal: 0,
        totalVat: 0,
        total: 0,
      );

      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => InvoiceEditScreen(
            invoiceId: draftId,
            onToggleTheme: widget.onToggleTheme,
            onChangePrimaryColor: widget.onChangePrimaryColor,
            onChangeLanguage: widget.onChangeLanguage,
            currentPrimaryColor: widget.currentPrimaryColor,
          ),
        ),
      );

      if (!mounted) return;
      await _load();
    } catch (e) {
      if (!mounted) return;
      // Keep it simple: show backend message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                '${l10n.saveFailed}: ${e.toString().replaceFirst('Exception: ', '')}')),
      );
    }
  }

  void _computeStats(List<Map<String, dynamic>> invoices) {
    double totalRevenue = 0;
    double pendingAmount = 0;
    int paidCount = 0;
    int unpaidCount = 0;

    final now = DateTime.now();
    final monthBuckets = <String, double>{};
    for (int i = 5; i >= 0; i--) {
      final d = DateTime(now.year, now.month - i, 1);
      final key = '${d.year}-${d.month.toString().padLeft(2, '0')}';
      monthBuckets[key] = 0;
    }

    for (final inv in invoices) {
      final status = (inv['status'] ?? 'UNPAID').toString().toUpperCase();
      final total = double.tryParse((inv['total'] ?? '0').toString()) ?? 0.0;
      final invoiceDate = _parseDate((inv['invoice_date'] ?? '').toString());
      final key =
          '${invoiceDate.year}-${invoiceDate.month.toString().padLeft(2, '0')}';

      if (status == 'PAID') {
        totalRevenue += total;
        paidCount++;
        if (monthBuckets.containsKey(key)) {
          monthBuckets[key] = (monthBuckets[key] ?? 0) + total;
        }
      } else {
        pendingAmount += total;
        unpaidCount++;
      }
    }

    _pendingAmount = pendingAmount;
    _paidCount = paidCount;
    _unpaidCount = unpaidCount;
    _monthlyRevenue = monthBuckets.values.toList();

    _computeGrowth();

    final totalInvoices = paidCount + unpaidCount;
    _paymentRate = totalInvoices == 0 ? 0 : (paidCount / totalInvoices) * 100;

    // avg invoice
    _avgInvoice =
        invoices.isEmpty ? 0 : (totalRevenue + pendingAmount) / invoices.length;

    // top clients (by revenue)
    final clientTotals = <String, double>{};
    for (final inv in invoices) {
      final client = (inv['client_name'] ?? 'Unknown').toString();
      final total = double.tryParse((inv['total'] ?? '0').toString()) ?? 0.0;
      clientTotals[client] = (clientTotals[client] ?? 0) + total;
    }

    final sorted = clientTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    _topClients = sorted.take(3).toList();
  }

  void _computeGrowth() {
    _growth = [];

    for (int i = 1; i < _monthlyRevenue.length; i++) {
      final prev = _monthlyRevenue[i - 1];
      final current = _monthlyRevenue[i];

      if (prev == 0) {
        _growth.add(0);
      } else {
        _growth.add(((current - prev) / prev) * 100);
      }
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);

    try {
      final invoices = await _repo.getRecentInvoices(limit: 500);
      final customers = await _countCustomers();
      final currency = await _settingsService.getCurrency();

      final expenses = await _expenseRepo.listExpenseNotes();

      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);
      final startOfNextMonth = DateTime(now.year, now.month + 1, 1);

      double monthlyExpenses = 0.0;
      for (final e in expenses) {
        final rawDate = (e['expense_date'] ?? e['date'] ?? '').toString();
        final d = DateTime.tryParse(rawDate);
        if (d == null) continue;
        if (d.isBefore(startOfMonth) || !d.isBefore(startOfNextMonth)) continue;

        final st = (e['status'] ?? '').toString().trim().toLowerCase();
        if (st == 'cancelled' || st == 'canceled' || st == 'rejected') continue;

        final amt = (e['amount'] is num)
            ? (e['amount'] as num).toDouble()
            : double.tryParse(e['amount'].toString().replaceAll(',', '.'));
        if (amt == null) continue;

        monthlyExpenses += amt;
      }

      setState(() {
        _customersCount = customers;
        _currency = currency;
        _computeStats(invoices);
        _monthlyExpenses = monthlyExpenses;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
      });
    }
  }

  DateTime _parseDate(String s) => DateTime.tryParse(s) ?? DateTime.now();

  Future<void> _go(Widget page) async {
    final res = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => page),
    );
    if (res == true) await _load();
  }

  Future<void> _openAddClient() async {
    await _go(const AddClientScreen());
  }

  Future<void> _openNewExpenseOptions() async {
    final l10n = AppLocalizations.of(context)!;

    final mode = await showModalBottomSheet<_ExpenseEntryMode>(
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
                  l10n.createExpenseNoteTitle,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: const Icon(Icons.edit_note_rounded),
                  title: const Text('Enter manually'),
                  subtitle: Text(l10n.createExpenseNoteSubtitle),
                  onTap: () => Navigator.pop(context, _ExpenseEntryMode.manual),
                ),
                const SizedBox(height: 8),
                ListTile(
                  leading: const Icon(Icons.document_scanner_outlined),
                  title: Text(l10n.scanInvoiceTitle),
                  subtitle: Text(l10n.scanInvoiceSubtitle),
                  onTap: () => Navigator.pop(context, _ExpenseEntryMode.scan),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted || mode == null) return;

    switch (mode) {
      case _ExpenseEntryMode.manual:
        await _go(const CreateExpenseNoteScreen());
        break;
      case _ExpenseEntryMode.scan:
        await _go(
          ScanInvoiceScreen(
            onToggleTheme: widget.onToggleTheme,
            onChangePrimaryColor: widget.onChangePrimaryColor,
            onChangeLanguage: widget.onChangeLanguage,
            currentPrimaryColor: widget.currentPrimaryColor,
          ),
        );
        break;
    }
  }

  Future<void> _openInvoicesWithStatus(String status) async {
    // Open invoices list and pass initialStatus as a constructor parameter.
    final res = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InvoicesScreen(
          initialStatus: status,
          onToggleTheme: widget.onToggleTheme,
          onChangePrimaryColor: widget.onChangePrimaryColor,
          onChangeLanguage: widget.onChangeLanguage,
          currentPrimaryColor: widget.currentPrimaryColor,
        ),
      ),
    );
    if (!mounted) return;
    if (res == true) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final screenWidth = MediaQuery.of(context).size.width;
    final statsColumns = screenWidth < 360 ? 1 : (screenWidth < 520 ? 2 : 3);
    final quickActionColumns = screenWidth < 430 ? 2 : 3;
    final stackCharts = screenWidth < 700;

    return Scaffold(
      appBar: AppTopBar(
        title: l10n.dashboard,
        onToggleTheme: widget.onToggleTheme,
        onChangePrimaryColor: widget.onChangePrimaryColor,
        onChangeLanguage: widget.onChangeLanguage,
        currentPrimaryColor: widget.currentPrimaryColor,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const SizedBox(height: 18),
                  Text(l10n.quickActions, style: t.headlineSmall),
                  const SizedBox(height: 12),
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: quickActionColumns,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: quickActionColumns == 2 ? 1.35 : 1.05,
                    children: [
                      ActionTile(
                        label: l10n.createInvoice,
                        icon: Icons.add_circle_outline,
                        bg: cs.primary,
                        fg: cs.onPrimary,
                        onTap: _createInvoiceAndOpenEditor,
                      ),
                      ActionTile(
                        label: l10n.createExpenseNoteTitle,
                        icon: Icons.account_balance_wallet_outlined,
                        bg: cs.tertiaryContainer.withValues(alpha: .40),
                        onTap: _openNewExpenseOptions,
                      ),
                      ActionTile(
                        label: l10n.newCustomer,
                        icon: Icons.person_add_alt_1_outlined,
                        bg: cs.secondary,
                        fg: cs.onSecondary,
                        onTap: _openAddClient,
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(
                    l10n.recentTransactions,
                    style: t.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 10),
                  // ===== SUMMARY (non-clickable) =====
                  LayoutBuilder(
                    builder: (context, c) {
                      final isNarrow = c.maxWidth < 720;

                      final items = <Widget>[
                        _MiniStatRect(
                          title: l10n.netMonthlyRevenue,
                          value: CurrencyService.format(
                            (_monthlyRevenue.isNotEmpty
                                    ? _monthlyRevenue.last
                                    : 0) -
                                _monthlyExpenses,
                            _currency,
                          ),
                          subtitle: '',
                          icon: Icons.payments_outlined,
                        ),
                        _MiniStatRect(
                          title: l10n.monthlyRevenue,
                          value: CurrencyService.format(
                            _monthlyRevenue.isNotEmpty
                                ? _monthlyRevenue.last
                                : 0,
                            _currency,
                          ),
                          subtitle: '',
                          icon: Icons.trending_up_rounded,
                        ),
                        _MiniStatRect(
                          title: l10n.averageInvoice,
                          value: CurrencyService.format(_avgInvoice, _currency),
                          subtitle: '',
                          icon: Icons.bar_chart_rounded,
                        ),
                      ];

                      if (isNarrow) {
                        return SizedBox(
                          height: 110,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: items.length,
                            padding: EdgeInsets.zero,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 10),
                            itemBuilder: (context, i) => SizedBox(
                              width: 235,
                              child: items[i],
                            ),
                          ),
                        );
                      }

                      return Row(
                        children: [
                          Expanded(child: items[0]),
                          const SizedBox(width: 10),
                          Expanded(child: items[1]),
                          const SizedBox(width: 10),
                          Expanded(child: items[2]),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 10),

                  // ===== ACTION CARDS (clickable) =====
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: statsColumns,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: statsColumns == 1
                        ? 2.2
                        : (statsColumns == 2 ? 1.25 : 1.0),
                    children: [
                      // Pending card (open unpaid invoices), subtitle is ''
                      _ActionStatCard(
                        title: l10n.pending,
                        value:
                            CurrencyService.format(_pendingAmount, _currency),
                        subtitle: '',
                        icon: Icons.hourglass_bottom_rounded,
                        color: cs.tertiary,
                        onTap: () => _openInvoicesWithStatus('UNPAID'),
                      ),
                      // New expense note card, subtitle is ''
                      _ActionStatCard(
                        title: l10n.createExpenseNoteTitle,
                        value:
                            CurrencyService.format(_monthlyExpenses, _currency),
                        subtitle: '',
                        icon: Icons.account_balance_wallet_outlined,
                        color: cs.tertiary,
                        onTap: _openNewExpenseOptions,
                      ),
                      // Paid card, subtitle shows invoices + unpaid count
                      _ActionStatCard(
                        title: l10n.paidLabel,
                        value: '$_paidCount',
                        subtitle:
                            '${l10n.invoices} • ${l10n.unpaidLabel}: $_unpaidCount',
                        icon: Icons.check_circle_outline_rounded,
                        color: cs.secondary,
                        onTap: () => _openInvoicesWithStatus('PAID'),
                      ),
                      // Clients card replaces unpaid card
                      _ActionStatCard(
                        title: l10n.client,
                        value: '$_customersCount',
                        subtitle: '',
                        icon: Icons.people_alt_outlined,
                        color: cs.primary,
                        onTap: () => _go(
                          ClientsScreen(
                            onToggleTheme: widget.onToggleTheme,
                            onChangePrimaryColor: widget.onChangePrimaryColor,
                            onChangeLanguage: widget.onChangeLanguage,
                            currentPrimaryColor: widget.currentPrimaryColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // ===== NEW STATS SECTION =====
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.topClients,
                            style: t.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 12),
                          ..._topClients.map((e) => Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 4),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        e.key,
                                        overflow: TextOverflow.ellipsis,
                                        style: t.bodyMedium,
                                      ),
                                    ),
                                    Text(
                                      CurrencyService.format(
                                          e.value, _currency),
                                      style: t.bodyMedium?.copyWith(
                                          fontWeight: FontWeight.w800),
                                    ),
                                  ],
                                ),
                              )),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 18),

                  stackCharts
                      ? Column(
                          children: [
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      l10n.growthCurve,
                                      style: t.titleSmall?.copyWith(
                                          fontWeight: FontWeight.w900),
                                    ),
                                    const SizedBox(height: 12),
                                    SizedBox(
                                      height: 180,
                                      child: _growth.isEmpty
                                          ? Center(
                                              child: Text(
                                                l10n.noInvoicesYet,
                                                style: t.bodyMedium?.copyWith(
                                                  color: cs.onSurfaceVariant,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            )
                                          : CustomPaint(
                                              painter: _RevenueLineChartPainter(
                                                values: _growth,
                                                lineColor: cs.primary,
                                                fillColor: cs.primary
                                                    .withValues(alpha: 0.10),
                                                gridColor: cs.outlineVariant
                                                    .withValues(alpha: 0.25),
                                              ),
                                              child: const SizedBox.expand(),
                                            ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      l10n.paymentRate,
                                      style: t.titleSmall?.copyWith(
                                          fontWeight: FontWeight.w900),
                                    ),
                                    const SizedBox(height: 12),
                                    SizedBox(
                                      height: 180,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            l10n.paymentRate,
                                            style: t.titleSmall?.copyWith(
                                                fontWeight: FontWeight.w900),
                                          ),
                                          const SizedBox(height: 12),
                                          LinearProgressIndicator(
                                            value: _paymentRate / 100,
                                            minHeight: 10,
                                            borderRadius:
                                                BorderRadius.circular(20),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            '${_paymentRate.toStringAsFixed(1)}%',
                                            style: t.titleMedium?.copyWith(
                                                fontWeight: FontWeight.w900),
                                          ),
                                          Text(
                                            '$_paidCount ${l10n.paidLabel} / $_unpaidCount ${l10n.unpaidLabel}',
                                            style: t.bodySmall,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        )
                      : Row(
                          children: [
                            Expanded(
                              child: Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        l10n.growthCurve,
                                        style: t.titleSmall?.copyWith(
                                            fontWeight: FontWeight.w900),
                                      ),
                                      const SizedBox(height: 12),
                                      SizedBox(
                                        height: 180,
                                        child: _growth.isEmpty
                                            ? Center(
                                                child: Text(
                                                  l10n.noInvoicesYet,
                                                  style: t.bodyMedium?.copyWith(
                                                    color: cs.onSurfaceVariant,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              )
                                            : CustomPaint(
                                                painter:
                                                    _RevenueLineChartPainter(
                                                  values: _growth,
                                                  lineColor: cs.primary,
                                                  fillColor: cs.primary
                                                      .withValues(alpha: 0.10),
                                                  gridColor: cs.outlineVariant
                                                      .withValues(alpha: 0.25),
                                                ),
                                                child: const SizedBox.expand(),
                                              ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        l10n.paymentRate,
                                        style: t.titleSmall?.copyWith(
                                            fontWeight: FontWeight.w900),
                                      ),
                                      const SizedBox(height: 12),
                                      SizedBox(
                                        height: 180,
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              l10n.paymentRate,
                                              style: t.titleSmall?.copyWith(
                                                  fontWeight: FontWeight.w900),
                                            ),
                                            const SizedBox(height: 12),
                                            LinearProgressIndicator(
                                              value: _paymentRate / 100,
                                              minHeight: 10,
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              '${_paymentRate.toStringAsFixed(1)}%',
                                              style: t.titleMedium?.copyWith(
                                                  fontWeight: FontWeight.w900),
                                            ),
                                            Text(
                                              '$_paidCount ${l10n.paidLabel} / $_unpaidCount ${l10n.unpaidLabel}',
                                              style: t.bodySmall,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }
}

class _DashboardClientPickerSheet extends StatefulWidget {
  final ClientsRepo clientsRepo;

  const _DashboardClientPickerSheet({required this.clientsRepo});

  @override
  State<_DashboardClientPickerSheet> createState() =>
      _DashboardClientPickerSheetState();
}

class _DashboardClientPickerSheetState
    extends State<_DashboardClientPickerSheet> {
  final TextEditingController _searchCtrl = TextEditingController();

  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _clients = [];
  List<Map<String, dynamic>> _filtered = [];

  @override
  void initState() {
    super.initState();
    _load();
    _searchCtrl.addListener(_apply);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _apply() {
    final q = _searchCtrl.text.trim().toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? _clients
          : _clients.where((c) {
              final name = (c['name'] ?? '').toString().toLowerCase();
              final email = (c['email'] ?? '').toString().toLowerCase();
              final mf = (c['fiscalId'] ?? c['fiscal_id'] ?? '')
                  .toString()
                  .toLowerCase();
              final cin = (c['cin'] ?? '').toString().toLowerCase();
              return name.contains(q) ||
                  email.contains(q) ||
                  mf.contains(q) ||
                  cin.contains(q);
            }).toList();
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final data = await widget.clientsRepo.getAllClientsarchived();
      if (!mounted) return;
      setState(() {
        _clients = List<Map<String, dynamic>>.from(data);
        _filtered = List<Map<String, dynamic>>.from(data);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  bool _looksLikeCin(String s) {
    final v = s.trim();
    return v.length == 8;
  }

  bool _looksLikeFiscalId(String s) {
    final v = s.trim().toUpperCase();
    return RegExp(r'^\d{7}[A-Z]$').hasMatch(v);
  }

  Future<void> _addClientFromSearch(String value) async {
    final q = value.trim();
    final saved = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddClientScreen(
          prefilledName:
              q.isNotEmpty && !_looksLikeCin(q) && !_looksLikeFiscalId(q)
                  ? q
                  : null,
          prefilledCin: _looksLikeCin(q) ? q : null,
          prefilledFiscalId: _looksLikeFiscalId(q) ? q : null,
        ),
      ),
    );

    if (saved != true) return;

    await _load();
    if (!mounted) return;

    final lookup = q.toLowerCase();
    if (lookup.isEmpty) {
      if (_clients.isNotEmpty) {
        Navigator.pop(context, _clients.first);
      }
      return;
    }

    final match = _clients.firstWhere(
      (c) {
        final name = (c['name'] ?? '').toString().trim().toLowerCase();
        final mf = (c['fiscalId'] ?? c['fiscal_id'] ?? '')
            .toString()
            .trim()
            .toLowerCase();
        final cin = (c['cin'] ?? '').toString().trim().toLowerCase();
        return lookup.isNotEmpty &&
            (name == lookup || mf == lookup || cin == lookup);
      },
      orElse: () => <String, dynamic>{},
    );

    if (match.isNotEmpty) {
      Navigator.pop(context, match);
    }
  }

  Widget _clientEmptyState(BuildContext context, String searchValue) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final hasSearch = searchValue.trim().isNotEmpty;

    return Center(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(28, 42, 28, 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.person_add_alt_1_outlined,
              size: 72,
              color: cs.primary,
            ),
            const SizedBox(height: 18),
            Text(
              _clients.isEmpty ? l10n.noCustomersYet : l10n.noResults,
              textAlign: TextAlign.center,
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              hasSearch
                  ? '${l10n.addNewClient}: ${searchValue.trim()}'
                  : l10n.createFirstCustomerToSeeHere,
              textAlign: TextAlign.center,
              style: textTheme.titleSmall?.copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w800,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    final q = _searchCtrl.text.trim();

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: bottom),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * .80,
          child: Column(
            children: [
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: l10n.searchNameMfCin,
                    prefixIcon: const Icon(Icons.search),
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                        ? Padding(
                            padding: const EdgeInsets.all(16),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color:
                                    cs.errorContainer.withValues(alpha: 0.55),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                    color: cs.error.withValues(alpha: 0.25)),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(Icons.error_rounded,
                                      color: cs.onErrorContainer),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      '${l10n.loadFailed}: ${_error ?? ''}',
                                      style: TextStyle(
                                        color: cs.onErrorContainer,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : _filtered.isEmpty
                            ? _clientEmptyState(context, q)
                            : ListView.separated(
                                itemCount: _filtered.length,
                                separatorBuilder: (_, __) =>
                                    const Divider(height: 1),
                                itemBuilder: (_, i) {
                                  final c = _filtered[i];
                                  final name = (c['name'] ?? '').toString();
                                  final email = (c['email'] ?? '').toString();
                                  final mf =
                                      (c['fiscalId'] ?? c['fiscal_id'] ?? '')
                                          .toString();
                                  final cin = (c['cin'] ?? '').toString();

                                  final parts = <String>[];
                                  if (email.trim().isNotEmpty) {
                                    parts.add(email.trim());
                                  }
                                  if (mf.trim().isNotEmpty) {
                                    parts.add('MF: ${mf.trim()}');
                                  }
                                  if (cin.trim().isNotEmpty) {
                                    parts.add('CIN: ${cin.trim()}');
                                  }

                                  return ListTile(
                                    title: Text(
                                      name.isEmpty ? l10n.client : name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    subtitle: parts.isEmpty
                                        ? null
                                        : Text(
                                            parts.join(' • '),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                    onTap: () => Navigator.pop(context, c),
                                  );
                                },
                              ),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.person_add_alt_1_rounded),
                    label: Text(
                      q.isEmpty
                          ? l10n.addNewClient
                          : '${l10n.addNewClient}: $q',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onPressed: () => _addClientFromSearch(q),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

class _RevenueLineChartPainter extends CustomPainter {
  final List<double> values;
  final Color lineColor;
  final Color fillColor;
  final Color gridColor;

  _RevenueLineChartPainter({
    required this.values,
    required this.lineColor,
    required this.fillColor,
    required this.gridColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const leftPad = 8.0;
    const bottomPad = 12.0;
    final chartWidth = size.width - leftPad;
    final chartHeight = size.height - bottomPad;

    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;

    for (int i = 0; i < 4; i++) {
      final y = (chartHeight / 3) * i;
      canvas.drawLine(Offset(leftPad, y), Offset(size.width, y), gridPaint);
    }

    final maxValue = values.reduce(math.max);
    if (maxValue <= 0 || values.length < 2) return;

    final dx = chartWidth / (values.length - 1);
    final path = Path();
    final fillPath = Path();

    for (int i = 0; i < values.length; i++) {
      final x = leftPad + (dx * i);
      final y = chartHeight - ((values[i] / maxValue) * (chartHeight - 8));
      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, chartHeight);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }

    fillPath.lineTo(leftPad + (dx * (values.length - 1)), chartHeight);
    fillPath.close();

    final fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;
    canvas.drawPath(fillPath, fillPaint);

    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, linePaint);

    final pointPaint = Paint()..color = lineColor;
    for (int i = 0; i < values.length; i++) {
      final x = leftPad + (dx * i);
      final y = chartHeight - ((values[i] / maxValue) * (chartHeight - 8));
      canvas.drawCircle(Offset(x, y), 3.8, pointPaint);
      final textPainter = TextPainter(
        text: TextSpan(
          text: '${values[i].toStringAsFixed(0)}%',
          style: TextStyle(
            color: values[i] >= 0 ? Colors.green : Colors.red,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      textPainter.paint(
        canvas,
        Offset(x - textPainter.width / 2, y - 16),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RevenueLineChartPainter oldDelegate) {
    return oldDelegate.values != values ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.fillColor != fillColor ||
        oldDelegate.gridColor != gridColor;
  }
}

class _MiniStatRect extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;

  const _MiniStatRect({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(18),
        border: Border(
          left: BorderSide(
            color: cs.primary.withValues(alpha: 0.45),
            width: 3,
          ),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: cs.primaryContainer.withValues(alpha: 0.30),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, size: 20, color: cs.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: t.labelMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionStatCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionStatCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Ink(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: cs.outlineVariant.withValues(alpha: 0.25),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Align(
                alignment: Alignment.topCenter,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: t.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: t.titleMedium?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: t.labelSmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
