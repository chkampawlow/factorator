// lib/screens/dashboard_screen.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:my_app/l10n/app_localizations.dart';
import 'package:my_app/screens/app_top_bar.dart';
import 'package:my_app/screens/connections_search_sheet.dart';
import 'package:my_app/screens/create_invoice_screen.dart';
import 'package:my_app/screens/create_expense_note_screen.dart';
import 'package:my_app/screens/connections_screen.dart';
import 'package:my_app/screens/notifications.dart';

import 'package:my_app/services/currency_service.dart';
import '../services/settings_service.dart';
import '../storage/dashboard_repo.dart';
import '../storage/expense_notes_repo.dart';
import '../storage/connections_repo.dart';
import '../widgets/action_tile.dart';

class DashboardScreen extends StatefulWidget {
  final VoidCallback onToggleTheme;

  const DashboardScreen({super.key, required this.onToggleTheme});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _repo = DashboardRepo();
  final _settingsService = SettingsService();
  final _expenseRepo = ExpenseNotesRepo();
  final _connectionsRepo = ConnectionsRepo();

  bool _loading = true;

  int _customersCount = 0;
  List<Map<String, dynamic>> _allInvoices = [];

  String _currency = 'TND';
  double _totalRevenue = 0;
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
      final status = (inv['status'] ?? 'UNPAID').toString().toUpperCase().trim();
      final total = double.tryParse((inv['total'] ?? '0').toString()) ?? 0.0;
      final invoiceDate = _parseDate((inv['invoice_date'] ?? '').toString());
      final key = '${invoiceDate.year}-${invoiceDate.month.toString().padLeft(2, '0')}';

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

    _totalRevenue = totalRevenue;
    _pendingAmount = pendingAmount;
    _paidCount = paidCount;
    _unpaidCount = unpaidCount;
    _monthlyRevenue = monthBuckets.values.toList();

    _computeGrowth();

    final totalInvoices = paidCount + unpaidCount;
    _paymentRate = totalInvoices == 0 ? 0 : (paidCount / totalInvoices) * 100;

    _avgInvoice =
        invoices.isEmpty ? 0 : (totalRevenue + pendingAmount) / invoices.length;

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
    if (!mounted) return;
    setState(() => _loading = true);

    try {
      final invoices = await _repo.getRecentInvoices(limit: 500);
      if (!mounted) return;

      final currency = await _settingsService.getCurrency();
      if (!mounted) return;

      final expenses = await _expenseRepo.listExpenseNotes();
      if (!mounted) return;

      int acceptedCount = 0;
      try {
        final accepted = await _connectionsRepo.accepted();
        acceptedCount = accepted.length;
      } catch (_) {
        acceptedCount = 0;
      }
      if (!mounted) return;

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

      if (!mounted) return;
      setState(() {
        _allInvoices = invoices;
        _currency = currency;
        _computeStats(invoices);
        _monthlyExpenses = monthlyExpenses;
        _customersCount = acceptedCount;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  DateTime _parseDate(String s) => DateTime.tryParse(s) ?? DateTime.now();

  Future<void> _go(Widget page) async {
    final res = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => page),
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
    final stackCharts = screenWidth < 700;

    return Scaffold(
      appBar: AppTopBar(
        title: l10n.dashboard,
        subtitle: l10n.quickActions,
        actions: [
          IconButton(
            onPressed: () => showConnectionsSearchSheet(context),
            icon: const Icon(Icons.search),
            tooltip: l10n.searchUsers,
          ),
          const NotificationsBellButton(),
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
                  const SizedBox(height: 12),
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 3,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 1.05,
                    children: [
                      ActionTile(
                        label: l10n.createInvoice,
                        icon: Icons.add_circle_outline,
                        bg: cs.primaryContainer.withOpacity(.40),
                        onTap: () => _go(const CreateInvoiceScreen()),
                      ),
                      ActionTile(
                        label: l10n.createExpenseNoteTitle,
                        icon: Icons.account_balance_wallet_outlined,
                        bg: cs.tertiaryContainer.withOpacity(.40),
                        onTap: () => _go(const CreateExpenseNoteScreen()),
                      ),
                      ActionTile(
                        label: '${l10n.customers} ($_customersCount)',
                        icon: Icons.people_alt_outlined,
                        bg: cs.secondaryContainer.withOpacity(.40),
                        onTap: () => _go(const ConnectionsScreen()),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(
                    l10n.recentTransactions,
                    style: t.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 10),
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
                      _StatCard(
                        title: l10n.netMonthlyRevenue,
                        value: CurrencyService.format(
                          (_monthlyRevenue.isNotEmpty ? _monthlyRevenue.last : 0) -
                              _monthlyExpenses,
                          _currency,
                        ),
                        subtitle: _currency,
                        icon: Icons.payments_outlined,
                        color: cs.primary,
                      ),
                      _StatCard(
                        title: l10n.monthlyRevenue,
                        value: CurrencyService.format(
                          _monthlyRevenue.isNotEmpty ? _monthlyRevenue.last : 0,
                          _currency,
                        ),
                        subtitle: _currency,
                        icon: Icons.payments_outlined,
                        color: cs.primaryContainer,
                      ),
                      _StatCard(
                        title: l10n.pending,
                        value: CurrencyService.format(_pendingAmount, _currency),
                        subtitle: _currency,
                        icon: Icons.hourglass_bottom_rounded,
                        color: cs.tertiary,
                      ),
                      _StatCard(
                        title: l10n.totalExpenses,
                        value: CurrencyService.format(_monthlyExpenses, _currency),
                        subtitle: _currency,
                        icon: Icons.account_balance_wallet_outlined,
                        color: cs.tertiaryContainer,
                      ),
                      _StatCard(
                        title: l10n.invoices,
                        value: '$_paidCount ${l10n.paidLabel}',
                        subtitle: '$_unpaidCount ${l10n.unpaidLabel}',
                        icon: Icons.receipt_long_outlined,
                        color: cs.secondary,
                      ),
                      _StatCard(
                        title: l10n.averageInvoice,
                        value: CurrencyService.format(_avgInvoice, _currency),
                        subtitle: _currency,
                        icon: Icons.bar_chart_rounded,
                        color: cs.secondaryContainer,
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.topClients,
                            style: t.titleSmall?.copyWith(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 12),
                          ..._topClients.map(
                            (e) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
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
                                    CurrencyService.format(e.value, _currency),
                                    style: t.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
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
                                        fontWeight: FontWeight.w900,
                                      ),
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
                                                fillColor: cs.primary.withOpacity(0.10),
                                                gridColor:
                                                    cs.outlineVariant.withOpacity(0.25),
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
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    SizedBox(
                                      height: 180,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          LinearProgressIndicator(
                                            value: _paymentRate / 100,
                                            minHeight: 10,
                                            borderRadius: BorderRadius.circular(20),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            '${_paymentRate.toStringAsFixed(1)}%',
                                            style: t.titleMedium?.copyWith(
                                              fontWeight: FontWeight.w900,
                                            ),
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
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        l10n.growthCurve,
                                        style: t.titleSmall?.copyWith(
                                          fontWeight: FontWeight.w900,
                                        ),
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
                                                  fillColor: cs.primary.withOpacity(0.10),
                                                  gridColor:
                                                      cs.outlineVariant.withOpacity(0.25),
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
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        l10n.paymentRate,
                                        style: t.titleSmall?.copyWith(
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      SizedBox(
                                        height: 180,
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            LinearProgressIndicator(
                                              value: _paymentRate / 100,
                                              minHeight: 10,
                                              borderRadius: BorderRadius.circular(20),
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              '${_paymentRate.toStringAsFixed(1)}%',
                                              style: t.titleMedium?.copyWith(
                                                fontWeight: FontWeight.w900,
                                              ),
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

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Card(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 110 || constraints.maxHeight < 110;
          final ultraCompact = constraints.maxWidth < 90 || constraints.maxHeight < 90;

          final padding = ultraCompact ? 10.0 : (compact ? 12.0 : 14.0);
          final iconPad = ultraCompact ? 6.0 : (compact ? 8.0 : 10.0);
          final iconSize = ultraCompact ? 16.0 : (compact ? 20.0 : 24.0);

          final titleStyle = (ultraCompact ? t.labelSmall : t.bodySmall)?.copyWith(
            color: cs.onSurfaceVariant,
            fontWeight: FontWeight.w700,
            height: 1.0,
          );
          final valueStyle = (ultraCompact ? t.titleSmall : t.titleMedium)?.copyWith(
            fontWeight: FontWeight.w900,
            height: 1.0,
          );
          final subtitleStyle = (ultraCompact ? t.labelSmall : t.bodySmall)?.copyWith(
            color: cs.onSurfaceVariant,
            fontWeight: FontWeight.w600,
            height: 1.0,
          );

          return Padding(
            padding: EdgeInsets.all(padding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: EdgeInsets.all(iconPad),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(ultraCompact ? 10 : 14),
                  ),
                  child: Icon(icon, color: color, size: iconSize),
                ),
                const SizedBox(height: 6),
                Expanded(
                  child: Align(
                    alignment: Alignment.bottomLeft,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: ultraCompact ? 1 : 2,
                          overflow: TextOverflow.ellipsis,
                          style: titleStyle,
                        ),
                        SizedBox(height: ultraCompact ? 2 : 4),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            value,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: valueStyle,
                          ),
                        ),
                        SizedBox(height: ultraCompact ? 1 : 3),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: subtitleStyle,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
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
          style: const TextStyle(
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