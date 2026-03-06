import 'package:flutter/material.dart';
import '../storage/clients_repo.dart';
import 'add_client_screen.dart';

class ClientsScreen extends StatefulWidget {
  const ClientsScreen({super.key});

  @override
  State<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends State<ClientsScreen> {
  final _repo = ClientsRepo();
  final _searchCtrl = TextEditingController();

  List<Map<String, dynamic>> _clients = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadClients();

    _searchCtrl.addListener(() {
      final q = _searchCtrl.text.trim().toLowerCase();
      setState(() {
        _filtered = q.isEmpty
            ? _clients
            : _clients.where((c) {
                final name = (c['name'] ?? '').toString().toLowerCase();
                final fiscalId = (c['fiscalId'] ?? '').toString().toLowerCase();
                final cin = (c['cin'] ?? '').toString().toLowerCase();
                return name.contains(q) || fiscalId.contains(q) || cin.contains(q);
              }).toList();
      });
    });
  }

  Future<void> _loadClients() async {
    setState(() => _loading = true);
    final data = await _repo.getAllClients();
    setState(() {
      _clients = data;
      _filtered = data;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  bool _isCompany(Map<String, dynamic> c) =>
      (c['type']?.toString() ?? 'individual') == 'company';

  String _clientSubtitle(Map<String, dynamic> c) {
    if (_isCompany(c)) {
      final mf = (c['fiscalId'] ?? '-').toString();
      return "MF: $mf";
    } else {
      final cin = (c['cin'] ?? '-').toString();
      return "CIN: $cin";
    }
  }

  IconData _clientIcon(Map<String, dynamic> c) {
    return _isCompany(c) ? Icons.business_outlined : Icons.person_outline;
  }

  Future<void> _editClient(Map<String, dynamic> client) async {
    final saved = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AddClientScreen(client: client)),
    );
    if (saved == true) await _loadClients();
  }

  Future<bool> _confirmDelete(Map<String, dynamic> client) async {
    final name = (client['name'] ?? '').toString();

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Delete customer?"),
        content: Text('Are you sure you want to delete "$name"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (ok == true) {
      await _repo.deleteClient(client['id'] as int);
      if (!mounted) return false;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Customer deleted ✅")),
      );

      await _loadClients();
      return true;
    }

    return false;
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
                  name.isEmpty ? "Unnamed customer" : name,
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

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Customers",
          style: t.titleMedium?.copyWith(fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            onPressed: _loadClients,
            icon: const Icon(Icons.refresh),
            tooltip: "Refresh",
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
          if (saved == true) await _loadClients();
        },
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text("Add"),
      ),

      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadClients,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  // search
                  Container(
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest.withOpacity(.55),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: cs.outlineVariant.withOpacity(.25)),
                    ),
                    child: TextField(
                      controller: _searchCtrl,
                      decoration: const InputDecoration(
                        hintText: "Search (name / MF / CIN)...",
                        prefixIcon: Icon(Icons.search),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          "All customers",
                          style: t.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                        ),
                      ),
                      Text(
                        "${_filtered.length}",
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
                          "No customers yet",
                          style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                    )
                  else
                    ..._filtered.map((c) {
                      final id = c['id'] as int;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Dismissible(
                          key: ValueKey("client_$id"),

                          // ✅ swipe right => edit
                          confirmDismiss: (direction) async {
                            if (direction == DismissDirection.startToEnd) {
                              // open edit, don't dismiss
                              await _editClient(c);
                              return false;
                            }

                            if (direction == DismissDirection.endToStart) {
                              // delete with confirm
                              final deleted = await _confirmDelete(c);
                              return deleted; // if true, dismiss animation happens
                            }

                            return false;
                          },

                          // backgrounds
                          background: _swipeBg(
                            context,
                            icon: Icons.edit,
                            label: "Edit",
                            alignLeft: true,
                            color: cs.primaryContainer,
                            fg: cs.onPrimaryContainer,
                          ),
                          secondaryBackground: _swipeBg(
                            context,
                            icon: Icons.delete_outline,
                            label: "Delete",
                            alignLeft: false,
                            color: cs.errorContainer,
                            fg: cs.onErrorContainer,
                          ),

                          child: InkWell(
                            borderRadius: BorderRadius.circular(22),
                            onTap: () async {
                              // optional: tap opens edit too
                              await _editClient(c);
                            },
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
            style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w900, color: fg),
          ),
        ],
      ),
    );
  }
}