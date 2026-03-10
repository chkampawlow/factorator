import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../storage/clients_repo.dart';
import '../storage/dashboard_repo.dart';
import '../widgets/action_tile.dart';

import 'clients_screen.dart';
import 'create_invoice_screen.dart';

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

  @override
  void initState() {
    super.initState();
    _load();
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

      if (!mounted) return;

      setState(() {
        _customersCount = customers;
        _recent = recent;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _customersCount = 0;
        _recent = [];
        _loading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Load failed: ${e.toString().replaceFirst('Exception: ', '')}'),
        ),
      );
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
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Do you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Logout'),
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

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Dashboard',
          style: t.titleMedium?.copyWith(fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            onPressed: widget.onToggleTheme,
            icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
            tooltip: 'Toggle theme',
          ),
          IconButton(
            onPressed: _logout,
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
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
                  Text('Quick actions', style: t.headlineSmall),
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
                        label: 'Create invoice',
                        icon: Icons.add_circle_outline,
                        bg: cs.primaryContainer.withOpacity(.40),
                        onTap: () => _go(const CreateInvoiceScreen()),
                      ),
                      ActionTile(
                        label: 'Advance invoice',
                        icon: Icons.request_quote_outlined,
                        bg: const Color(0xFFFFF3CD),
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Advance invoice: coming soon'),
                            ),
                          );
                        },
                      ),
                      ActionTile(
                        label: 'Customers (${_customersCount})',
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
                          'Recent transactions',
                          style: t.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                        ),
                      ),
                      TextButton(
                        onPressed: () {},
                        child: const Text('All'),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  if (_recent.isEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          'No invoices yet.',
                          style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                    )
                  else
                    Card(
                      child: Column(
                        children: _recent.map((inv) {
  final name = (inv['custom_email'] ?? 'Client').toString();
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
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.bodyLarge?.copyWith(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${inv['invoice']} • ${_dateOnly(issue)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 90, maxWidth: 140),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                      style: t.bodyLarge?.copyWith(fontWeight: FontWeight.w900),
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