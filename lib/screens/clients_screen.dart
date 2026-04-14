import 'package:flutter/material.dart';
import 'dart:async';
import 'package:my_app/l10n/app_localizations.dart';
import 'package:my_app/widgets/app_alerts.dart';
import 'package:my_app/widgets/app_top_bar.dart';
import '../storage/clients_repo.dart';
import 'add_client_screen.dart';

class ClientsScreen extends StatefulWidget {
  final VoidCallback onToggleTheme;
  final void Function(Color color) onChangePrimaryColor;
  final void Function(String code) onChangeLanguage;
  final Color currentPrimaryColor;

  const ClientsScreen({
    super.key,
    required this.onToggleTheme,
    required this.onChangePrimaryColor,
    required this.onChangeLanguage,
    required this.currentPrimaryColor,
  });

  @override
  State<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends State<ClientsScreen> {
  final ClientsRepo _repo = ClientsRepo();
  final TextEditingController _searchCtrl = TextEditingController();

  List<Map<String, dynamic>> _clients = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _loading = true;

  String _filter = 'ALL'; // ALL | COMPANY | INDIVIDUAL

  bool _matchesFilter(Map<String, dynamic> c) {
    if (_filter == 'ALL') return true;
    final isCompany = _isCompany(c);
    return _filter == 'COMPANY' ? isCompany : !isCompany;
  }

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
      final base = _clients.where(_matchesFilter).toList();

      if (q.isEmpty) {
        _filtered = List<Map<String, dynamic>>.from(base);
      } else {
        _filtered = base.where((c) {
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

      final l10n = AppLocalizations.of(context)!;
      AppAlerts.error(
        context,
        '${l10n.failedToLoadCustomers}: ${e.toString().replaceFirst('Exception: ', '')}',
      );
    }
  }

  bool _isCompany(Map<String, dynamic> c) {
    return (c['type']?.toString().trim().toLowerCase() ?? 'individual') ==
        'company';
  }

  String _getFiscalId(Map<String, dynamic> c) {
    return (c['fiscalId'] ?? c['fiscal_id'] ?? '').toString();
  }

  int? _clientId(Map<String, dynamic> c) {
    final raw = c['id'] ?? c['client_id'] ?? c['clientId'];
    if (raw == null) return null;
    if (raw is int) return raw;
    return int.tryParse(raw.toString());
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
        builder: (_) => AddClientScreen(
          client: client,
        ),
      ),
    );

    if (saved == true) {
      await _loadClients();
    }
  }

  Future<bool> _confirmDelete(Map<String, dynamic> client) async {
    final name = (client['name'] ?? '').toString();
    final int? id = _clientId(client);
    if (id == null || id <= 0) {
      final l10n = AppLocalizations.of(context)!;
      AppAlerts.error(context, l10n.invalidClientId);
      return false;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.deleteCustomerQuestion),
        content:
            Text(AppLocalizations.of(context)!.areYouSureDeleteCustomer(name)),
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

      // Remove locally so it disappears immediately (even if backend uses soft delete).
      setState(() {
        _clients.removeWhere((c) => _clientId(c) == id);
        _filtered.removeWhere((c) => _clientId(c) == id);
      });

      final l10n = AppLocalizations.of(context)!;
      AppAlerts.success(context, l10n.customerDeletedSuccessfully);

      // Optional: reload in background to stay consistent with server.
      // ignore: unawaited_futures
      _loadClients();

      return true;
    } catch (e) {
      if (!mounted) return false;

      final l10n = AppLocalizations.of(context)!;
      AppAlerts.error(
        context,
        '${l10n.deleteFailed}: ${e.toString().replaceFirst('Exception: ', '')}',
      );
      return false;
    }
  }

  Widget _premiumClientCard(BuildContext context, Map<String, dynamic> c) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
            color:
                Theme.of(context).shadowColor.withOpacity(isDark ? 0.22 : 0.08),
            blurRadius: 20,
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
                  name.isEmpty
                      ? AppLocalizations.of(context)!.unnamedCustomer
                      : name,
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
        mainAxisAlignment:
            alignLeft ? MainAxisAlignment.start : MainAxisAlignment.end,
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

  Widget _emptyState(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 90),
        Center(
          child: Icon(
            Icons.people_alt_outlined,
            size: 74,
            color: cs.onSurfaceVariant.withOpacity(0.55),
          ),
        ),
        const SizedBox(height: 18),
        Center(
          child: Text(
            l10n.noCustomersYet,
            style: t.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              l10n.createFirstCustomerToSeeHere,
              style: t.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        const SizedBox(height: 22),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: SizedBox(
            height: 52,
            child: FilledButton.icon(
              icon: const Icon(Icons.person_add_alt_1),
              label: Text(
                l10n.createCustomer,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              onPressed: () async {
                final saved = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AddClientScreen()),
                );
                if (saved == true) {
                  await _loadClients();
                }
              },
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppTopBar(
        title: l10n.customers,
        onToggleTheme: widget.onToggleTheme,
        onChangePrimaryColor: widget.onChangePrimaryColor,
        onChangeLanguage: widget.onChangeLanguage,
        currentPrimaryColor: widget.currentPrimaryColor,
      ),
      floatingActionButton: _filtered.isEmpty
          ? null
          : FloatingActionButton.extended(
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
              label: Text(l10n.newCustomer),
            ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      hintText: l10n.searchCustomerNameIdEmail,
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchCtrl.text.isEmpty
                          ? null
                          : IconButton(
                              onPressed: () {
                                _searchCtrl.clear();
                                _applySearch();
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
                  Row(
                    children: [
                      ChoiceChip(
                        label: Text(l10n.all),
                        selected: _filter == 'ALL',
                        onSelected: (_) {
                          setState(() => _filter = 'ALL');
                          _applySearch();
                        },
                      ),
                      const SizedBox(width: 10),
                      ChoiceChip(
                        label: Text(l10n.companies),
                        selected: _filter == 'COMPANY',
                        onSelected: (_) {
                          setState(() => _filter = 'COMPANY');
                          _applySearch();
                        },
                      ),
                      const SizedBox(width: 10),
                      ChoiceChip(
                        label: Text(l10n.individuals),
                        selected: _filter == 'INDIVIDUAL',
                        onSelected: (_) {
                          setState(() => _filter = 'INDIVIDUAL');
                          _applySearch();
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: _filtered.isEmpty
                        ? _emptyState(context)
                        : RefreshIndicator(
                            onRefresh: _loadClients,
                            child: ListView.builder(
                              physics: const AlwaysScrollableScrollPhysics(),
                              itemCount: _filtered.length,
                              itemBuilder: (context, index) {
                                final c = _filtered[index];
                                final keyId =
                                    (_clientId(c) ?? UniqueKey().toString())
                                        .toString();

                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Dismissible(
                                    key: ValueKey('client_$keyId'),
                                    confirmDismiss: (direction) async {
                                      if (direction ==
                                          DismissDirection.startToEnd) {
                                        await _editClient(c);
                                        return false;
                                      }
                                      if (direction ==
                                          DismissDirection.endToStart) {
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
