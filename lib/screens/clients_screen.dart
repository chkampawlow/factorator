import 'package:flutter/material.dart';
import 'package:my_app/l10n/app_localizations.dart';
import '../storage/clients_repo.dart';
import 'add_client_screen.dart';

class ClientsScreen extends StatefulWidget {
  const ClientsScreen({super.key});

  @override
  State<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends State<ClientsScreen> {
  final ClientsRepo _repo = ClientsRepo();
  final TextEditingController _searchCtrl = TextEditingController();

  List<Map<String, dynamic>> _clients = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadClients();
    _searchCtrl.addListener(_applySearch);
  }

  @override
  void dispose() {
    _searchCtrl.removeListener(_applySearch);
    _searchCtrl.dispose();
    super.dispose();
  }

  void _applySearch() {
    final q = _searchCtrl.text.trim().toLowerCase();

    setState(() {
      if (q.isEmpty) {
        _filtered = List<Map<String, dynamic>>.from(_clients);
      } else {
        _filtered = _clients.where((c) {
          final name = (c['name'] ?? '').toString().toLowerCase();
          final fiscalId = _getFiscalId(c).toLowerCase();
          final cin = (c['cin'] ?? '').toString().toLowerCase();
          final email = (c['email'] ?? '').toString().toLowerCase();
          final phone = (c['phone'] ?? '').toString().toLowerCase();

          return name.contains(q) ||
              fiscalId.contains(q) ||
              cin.contains(q) ||
              email.contains(q) ||
              phone.contains(q);
        }).toList();
      }
    });
  }

  Future<void> _loadClients() async {
    setState(() => _loading = true);

    try {
      final data = await _repo.getAllClients();

      if (!mounted) return;

      setState(() {
        _clients = List<Map<String, dynamic>>.from(data);
        _filtered = List<Map<String, dynamic>>.from(data);
        _loading = false;
      });

      _applySearch();
    } catch (e) {
      if (!mounted) return;

      setState(() => _loading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${AppLocalizations.of(context)!.failedToLoadCustomers}: ${e.toString().replaceFirst('Exception: ', '')}'),
        ),
      );
    }
  }

  bool _isCompany(Map<String, dynamic> c) {
    return (c['type']?.toString().trim().toLowerCase() ?? 'individual') == 'company';
  }

  String _getFiscalId(Map<String, dynamic> c) {
    return (c['fiscalId'] ?? c['fiscal_id'] ?? '').toString();
  }

  String _clientSubtitle(Map<String, dynamic> c) {
    if (_isCompany(c)) {
      final mf = _getFiscalId(c);
      return '${AppLocalizations.of(context)!.mfLabel}: ${mf.isEmpty ? '-' : mf}';
    } else {
      final cin = (c['cin'] ?? '').toString();
      return '${AppLocalizations.of(context)!.cin}: ${cin.isEmpty ? '-' : cin}';
    }
  }

  IconData _clientIcon(Map<String, dynamic> c) {
    return _isCompany(c) ? Icons.business_outlined : Icons.person_outline;
  }

  Future<void> _editClient(Map<String, dynamic> client) async {
    final saved = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddClientScreen(client: client),
      ),
    );

    if (saved == true) {
      await _loadClients();
    }
  }

  Future<bool> _confirmDelete(Map<String, dynamic> client) async {
    final name = (client['name'] ?? '').toString();
    final rawId = client['id'];

    if (rawId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.missingClientId)),
      );
      return false;
    }

    final int? id = rawId is int ? rawId : int.tryParse(rawId.toString());
    if (id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.invalidClientId)),
      );
      return false;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.deleteCustomerQuestion),
        content: Text(AppLocalizations.of(context)!.areYouSureDeleteCustomer(name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(AppLocalizations.of(context)!.delete),
          ),
        ],
      ),
    );

    if (ok != true) return false;

    try {
      await _repo.deleteClient(id);

      if (!mounted) return false;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.customerDeletedSuccessfully)),
      );

      await _loadClients();
      return true;
    } catch (e) {
      if (!mounted) return false;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${AppLocalizations.of(context)!.deleteFailed}: ${e.toString().replaceFirst('Exception: ', '')}'),
        ),
      );
      return false;
    }
  }

  Widget _premiumClientCard(BuildContext context, Map<String, dynamic> c) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    final name = (c['name'] ?? '').toString();
    final subtitle = _clientSubtitle(c);
    final icon = _clientIcon(c);

    final cardBg = cs.surfaceContainerHighest.withOpacity(.45);
    final border = cs.outlineVariant.withOpacity(.18);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.05),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            height: 46,
            width: 46,
            decoration: BoxDecoration(
              color: cs.surface.withOpacity(.65),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: cs.outlineVariant.withOpacity(.18)),
            ),
            child: Icon(icon, color: cs.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.isEmpty ? AppLocalizations.of(context)!.unnamedCustomer : name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right,
            size: 30,
            color: cs.onSurface.withOpacity(.55),
          ),
        ],
      ),
    );
  }

  Widget _swipeBg(
    BuildContext context, {
    required IconData icon,
    required String label,
    required bool alignLeft,
    required Color color,
    required Color fg,
  }) {
    final t = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        color: color.withOpacity(.75),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        mainAxisAlignment: alignLeft ? MainAxisAlignment.start : MainAxisAlignment.end,
        children: [
          Icon(icon, color: fg),
          const SizedBox(width: 8),
          Text(
            label,
            style: t.bodyMedium?.copyWith(
              fontWeight: FontWeight.w900,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.customers,
          style: t.titleMedium?.copyWith(fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            onPressed: _loadClients,
            icon: const Icon(Icons.refresh),
            tooltip: l10n.refresh,
          ),
          const SizedBox(width: 6),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final saved = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddClientScreen()),
          );

          if (saved == true) {
            await _loadClients();
          }
        },
        icon: const Icon(Icons.person_add_alt_1),
        label: Text(l10n.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadClients,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest.withOpacity(.55),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: cs.outlineVariant.withOpacity(.25),
                      ),
                    ),
                    child: TextField(
                      controller: _searchCtrl,
                      decoration: InputDecoration(
                        hintText: l10n.searchNameMfCin,
                        prefixIcon: const Icon(Icons.search),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          l10n.allCustomers,
                          style: t.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                        ),
                      ),
                      Text(
                        '${_filtered.length}',
                        style: t.titleSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: cs.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_filtered.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 30),
                      child: Center(
                        child: Text(
                          l10n.noCustomersYet,
                          style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                    )
                  else
                    ..._filtered.map((c) {
                      final rawId = c['id'];
                      final keyId = rawId?.toString() ?? UniqueKey().toString();

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Dismissible(
                          key: ValueKey('client_$keyId'),
                          confirmDismiss: (direction) async {
                            if (direction == DismissDirection.startToEnd) {
                              await _editClient(c);
                              return false;
                            }

                            if (direction == DismissDirection.endToStart) {
                              return await _confirmDelete(c);
                            }

                            return false;
                          },
                          background: _swipeBg(
                            context,
                            icon: Icons.edit,
                            label: l10n.edit,
                            alignLeft: true,
                            color: cs.primaryContainer,
                            fg: cs.onPrimaryContainer,
                          ),
                          secondaryBackground: _swipeBg(
                            context,
                            icon: Icons.delete_outline,
                            label: l10n.delete,
                            alignLeft: false,
                            color: cs.errorContainer,
                            fg: cs.onErrorContainer,
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(22),
                            onTap: () async => _editClient(c),
                            child: _premiumClientCard(context, c),
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