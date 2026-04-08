import 'package:flutter/material.dart';
import 'package:my_app/l10n/app_localizations.dart';
import 'package:my_app/screens/app_top_bar.dart'; // your AppTopBar (from split files)
import 'package:my_app/storage/connections_repo.dart';
import 'package:my_app/storage/received_invoices_repo.dart';
import 'package:my_app/widgets/action_tile.dart';

import 'package:my_app/screens/connections_search_sheet.dart';
import 'package:my_app/screens/notifications.dart';
import 'client_received_invoices_screen.dart';
import 'connections_screen.dart';

import 'package:my_app/services/currency_service.dart';
import 'package:my_app/services/settings_service.dart';

class ClientDashboardScreen extends StatefulWidget {
  const ClientDashboardScreen({super.key});

  @override
  State<ClientDashboardScreen> createState() => _ClientDashboardScreenState();
}

class _ClientDashboardScreenState extends State<ClientDashboardScreen> {
  final ConnectionsRepo _connectionsRepo = ConnectionsRepo();
  final ReceivedInvoicesRepo _receivedInvoicesRepo = ReceivedInvoicesRepo();

  final SettingsService _settingsService = SettingsService();

  bool _loading = true;

  String _currency = 'TND';

  int _receivedCount = 0;
  int _connectionsCount = 0;

  double _receivedTotalAmount = 0.0;
  double _receivedRemainingAmount = 0.0;

  List<Map<String, dynamic>> _recentReceived = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);

    try {
      final received = await _receivedInvoicesRepo.listReceivedInvoices(limit: 200, offset: 0);

      final currency = await _settingsService.getCurrency();

      double totalAmount = 0.0;
      double remainingAmount = 0.0;

      for (final i in received) {
        final st = (i['status'] ?? '').toString().toUpperCase().trim();
        final rawTotal = i['total'];

        final amt = (rawTotal is num)
            ? rawTotal.toDouble()
            : double.tryParse(rawTotal?.toString().replaceAll(',', '.') ?? '0') ?? 0.0;

        totalAmount += amt;

        final isUnpaid = st == '' || st == 'OPEN' || st == 'UNPAID' || st == 'PENDING';
        if (isUnpaid) {
          remainingAmount += amt;
        }
      }

      // 2) Accepted connections (optional, if your client uses connections)
      int acceptedCount = 0;
      try {
        final accepted = await _connectionsRepo.accepted();
        acceptedCount = accepted.length;
      } catch (_) {
        acceptedCount = 0;
      }

      if (!mounted) return;
      setState(() {
        _currency = currency;

        _receivedCount = received.length;
        _connectionsCount = acceptedCount;

        _receivedTotalAmount = totalAmount;
        _receivedRemainingAmount = remainingAmount;

        _loading = false;
        _recentReceived = received.take(5).toList();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _go(Widget page) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    if (!mounted) return;
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppTopBar(
        title: l10n.dashboard,
        subtitle: null,
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
                  // Top cards
                  Row(
                    children: [
                      Expanded(
                        child: _MiniStatCard(
                          title: l10n.total,
                          value: CurrencyService.format(_receivedTotalAmount, _currency),
                          subtitle: '${l10n.receivedInvoices} • $_receivedCount',
                          icon: Icons.payments_outlined,
                          color: cs.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _MiniStatCard(
                          title: l10n.pending,
                          value: CurrencyService.format(_receivedRemainingAmount, _currency),
                          subtitle: _currency,
                          icon: Icons.hourglass_bottom_rounded,
                          color: cs.tertiary,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),
                  const SizedBox(height: 4),

                  Text(
                    l10n.receivedInvoices,
                    style: t.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 10),

                  if (_recentReceived.isEmpty)
                    Card(
                      child: Padding(
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
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _recentReceived.length,
                          separatorBuilder: (_, __) => Divider(
                            height: 1,
                            color: cs.outlineVariant.withOpacity(0.25),
                          ),
                          itemBuilder: (context, i) {
                            final inv = _recentReceived[i];
                            final from = (inv['from'] is Map)
                                ? Map<String, dynamic>.from(inv['from'] as Map)
                                : <String, dynamic>{};

                            final fromName = (from['name'] ?? '').toString().trim();
                            final status = (inv['status'] ?? '').toString().toUpperCase().trim();
                            final invoiceNo = (inv['invoice'] ?? '').toString().trim();
                            final date = (inv['invoice_date'] ?? '').toString().trim();

                            return ListTile(
                              dense: true,
                              leading: Icon(
                                (from['type'] ?? '') == 'organization'
                                    ? Icons.business_rounded
                                    : Icons.person_rounded,
                                color: cs.primary,
                              ),
                              title: Text(
                                fromName.isEmpty ? l10n.unknown : fromName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: t.titleSmall?.copyWith(fontWeight: FontWeight.w900),
                              ),
                              subtitle: Text(
                                '$invoiceNo • $date',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: cs.surfaceContainerHighest.withOpacity(0.55),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: cs.outlineVariant.withOpacity(0.25),
                                  ),
                                ),
                                child: Text(
                                  status.isEmpty ? '—' : status,
                                  style: t.labelSmall?.copyWith(fontWeight: FontWeight.w900),
                                ),
                              ),
                              onTap: () => _go(const ClientReceivedInvoicesScreen()),
                            );
                          },
                        ),
                      ),
                    ),

                  const SizedBox(height: 18),

                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: cs.onSurfaceVariant),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              l10n.receivedInvoicesSubtitle,
                              style: t.bodyMedium?.copyWith(
                                color: cs.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _MiniStatCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _MiniStatCard({
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
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: t.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                  ),
                  if (subtitle.trim().isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.labelSmall?.copyWith(
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}