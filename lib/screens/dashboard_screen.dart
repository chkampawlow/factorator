import 'package:flutter/material.dart';
import 'package:my_app/l10n/app_localizations.dart';
import 'package:my_app/screens/add_client_screen.dart';
import 'package:my_app/screens/clients_screen.dart';

import '../services/auth_service.dart';
import '../storage/clients_repo.dart';
import '../storage/dashboard_repo.dart';
import '../widgets/action_tile.dart';


class DashboardScreen extends StatefulWidget {
  final VoidCallback onToggleTheme;

  const DashboardScreen({super.key, required this.onToggleTheme});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _repo = DashboardRepo();
  final _clientsRepo = ClientsRepo();
  final _authService = AuthService();

  bool _loading = true;

  int _customersCount = 0;
  List<Map<String, dynamic>> _recent = [];

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

Future<void> _load() async {
  setState(() => _loading = true);

  try {
    final recent = await _repo.getRecentInvoices(limit: 6);
    final customers = await _countCustomers();
    setState(() {
      _recent = recent;
      _customersCount = customers;
      _loading = false;
    });
  } catch (e) {
    setState(() {
      _loading = false;
    });
    // Optionally, handle the error (e.g., show a snackbar)
  }
}

DateTime _parseDate(String s) => DateTime.tryParse(s) ?? DateTime.now();

String _dateOnly(DateTime d) => d.toLocal().toString().split(' ')[0];

Future<void> _go(Widget page) async {
  final res = await Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => page),
  );
  if (res == true) await _load();
}

Future<void> _logout() async {
  final l10n = AppLocalizations.of(context)!;

  final confirm = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(l10n.logout),
      content: Text(l10n.logoutQuestion),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(l10n.logout),
        ),
      ],
    ),
  );

  if (confirm != true) return;

  await _authService.logout();

  if (!mounted) return;

  Navigator.pushNamedAndRemoveUntil(
    context,
    '/login',
    (route) => false,
  );
}

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.dashboard,
          style: t.titleMedium?.copyWith(fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            onPressed: widget.onToggleTheme,
            icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
            tooltip: l10n.toggleTheme,
          ),
          IconButton(
            onPressed: _logout,
            icon: const Icon(Icons.logout),
            tooltip: l10n.logout,
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
                  const SizedBox(height: 18),
                  Text(l10n.quickActions, style: t.headlineSmall),
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
onTap: () => _go(AddClientScreen()),                      ),
                      ActionTile(
                        label: l10n.advanceInvoice,
                        icon: Icons.request_quote_outlined,
                        bg: const Color(0xFFFFF3CD),
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(l10n.advanceInvoiceComingSoon),
                            ),
                          );
                        },
                      ),
                      ActionTile(
                        label: '${l10n.customers} ($_customersCount)',
                        icon: Icons.people_alt_outlined,
                        bg: const Color(0xFFEAF2FF),
                        onTap: () => _go(const ClientsScreen()),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          l10n.recentTransactions,
                          style: t.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                        ),
                      ),
                      TextButton(
                        onPressed: () {},
                        child: Text(l10n.all),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (_recent.isEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          l10n.noInvoicesYet,
                          style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                    )
                  else
                    Card(
                      child: Column(
                        children: _recent.map((inv) {
                          final status = (inv['status'] ?? 'UNPAID').toString().toUpperCase();
                          final total = double.tryParse(inv['total'].toString()) ?? 0.0;
                          final issue = _parseDate((inv['invoice_date'] ?? '').toString());

                          final isPaid = status == 'PAID';
                          final tagBg = isPaid ? cs.primaryContainer : cs.tertiaryContainer;
                          final tagFg = isPaid ? cs.onPrimaryContainer : cs.onTertiaryContainer;

                          return Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            '${inv['invoice']} • ${_dateOnly(issue)}',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: t.bodyLarge?.copyWith(
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        minWidth: 90,
                                        maxWidth: 140,
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              color: tagBg,
                                              borderRadius: BorderRadius.circular(999),
                                            ),
                                            child: Text(
                                              status,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontWeight: FontWeight.w900,
                                                color: tagFg,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          FittedBox(
                                            fit: BoxFit.scaleDown,
                                            alignment: Alignment.centerRight,
                                            child: Text(
                                              '+${total.toStringAsFixed(2)}',
                                              style: t.bodyLarge?.copyWith(
                                                fontWeight: FontWeight.w900,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (inv != _recent.last) const Divider(height: 1),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }
}