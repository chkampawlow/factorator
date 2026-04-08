// lib/screens/connections_screen.dart
// Backward-compatible: ClientsScreen is kept as an alias.

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:my_app/l10n/app_localizations.dart';
import 'package:my_app/storage/connections_repo.dart';
import 'package:my_app/widgets/app_alerts.dart';

class ConnectionsScreen extends StatefulWidget {
  const ConnectionsScreen({super.key});

  @override
  State<ConnectionsScreen> createState() => _ConnectionsScreenState();
}

// Backward-compatible alias so you don't have to change the navbar immediately.
class ClientsScreen extends StatelessWidget {
  const ClientsScreen({super.key});

  @override
  Widget build(BuildContext context) => const ConnectionsScreen();
}

class _ConnectionsScreenState extends State<ConnectionsScreen>
    with SingleTickerProviderStateMixin {
  final ConnectionsRepo _repo = ConnectionsRepo();
  final TextEditingController _searchCtrl = TextEditingController();

  bool _loading = true;
  bool _sending = false;

  List<Map<String, dynamic>> _accepted = [];
  List<Map<String, dynamic>> _inbox = [];
  List<Map<String, dynamic>> _sent = [];

  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tab.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);

    try {
      final accepted = await _repo.accepted();
      final inbox = await _repo.inbox();
      final sent = await _repo.sent();

      if (!mounted) return;
      setState(() {
        _accepted = accepted;
        _inbox = inbox;
        _sent = sent;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      final l10n = AppLocalizations.of(context)!;
      AppAlerts.error(
        context,
        '${l10n.loadFailed}: ${e.toString().replaceFirst('Exception: ', '')}',
      );
    }
  }

  String _bestName(Map<String, dynamic> u) {
    final dn = (u['other_display_name'] ??
            u['requester_display_name'] ??
            u['target_display_name'] ??
            '')
        .toString()
        .trim();
    final org = (u['other_organization_name'] ??
            u['requester_organization_name'] ??
            u['target_organization_name'] ??
            '')
        .toString()
        .trim();
    return dn.isNotEmpty ? dn : (org.isNotEmpty ? org : '—');
  }

  String _bestEmail(Map<String, dynamic> u) {
    return (u['other_email'] ??
            u['requester_email'] ??
            u['target_email'] ??
            '')
        .toString()
        .trim();
  }

  int _toInt(dynamic v) {
    if (v is int) return v;
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }

  Future<void> _openInviteSheet() async {
    final l10n = AppLocalizations.of(context)!;
    _searchCtrl.clear();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return _InviteSheet(
          controller: _searchCtrl,
          loading: _sending,
          onSearch: (q) => _repo.searchUsers(q),
          onInvite: (targetId) async {
            if (_sending) return;

            setState(() => _sending = true);
            try {
              await _repo.sendInvitation(targetId: targetId);
              if (!mounted) return;
              AppAlerts.success(ctx, l10n.invitationSent);
              Navigator.pop(ctx);
              await _load();
            } catch (e) {
              if (!mounted) return;
              AppAlerts.error(
                ctx,
                e.toString().replaceFirst('Exception: ', ''),
              );
            } finally {
              if (mounted) setState(() => _sending = false);
            }
          },
        );
      },
    );
  }

  Future<void> _respond(int id, String action) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      await _repo.respond(id: id, action: action);
      if (!mounted) return;
      AppAlerts.success(context, l10n.updated);
      await _load();
    } catch (e) {
      if (!mounted) return;
      AppAlerts.error(
        context,
        e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  Future<void> _remove(int id) async {
    final l10n = AppLocalizations.of(context)!;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l10n.remove),
        content: Text(l10n.areYouSure),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.remove),
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      await _repo.remove(id);
      if (!mounted) return;
      AppAlerts.success(context, l10n.removed);
      await _load();
    } catch (e) {
      if (!mounted) return;
      AppAlerts.error(
        context,
        e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  Widget _topHeader(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context)!;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            cs.primaryContainer.withOpacity(0.45),
            cs.surface,
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Container(
            height: 44,
            width: 44,
            decoration: BoxDecoration(
              color: cs.surface.withOpacity(0.7),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: cs.outlineVariant.withOpacity(0.18)),
            ),
            child: Icon(Icons.people_alt_outlined, color: cs.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.customers,
                  style: t.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.connectionsSubtitle,
                  style: t.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          FilledButton.icon(
            onPressed: _openInviteSheet,
            icon: const Icon(Icons.person_add_alt_1),
            label: Text(l10n.invite),
          ),
        ],
      ),
    );
  }

  Widget _cardTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
    List<Widget> actions = const [],
  }) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withOpacity(.45),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: cs.outlineVariant.withOpacity(.18)),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context)
                  .shadowColor
                  .withOpacity(isDark ? 0.22 : 0.08),
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
                    title.isEmpty ? '—' : title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle.isEmpty ? '—' : subtitle,
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
            if (actions.isEmpty)
              Icon(Icons.chevron_right,
                  size: 30, color: cs.onSurface.withOpacity(.55))
            else
              Row(mainAxisSize: MainAxisSize.min, children: actions),
          ],
        ),
      ),
    );
  }

  Widget _empty(String text) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 80),
        Icon(Icons.inbox_outlined, size: 70, color: cs.onSurfaceVariant),
        const SizedBox(height: 14),
        Center(
          child: Text(
            text,
            style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.customers),
        actions: [
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
            tooltip: l10n.refresh,
          ),
        ],
        bottom: TabBar(
          controller: _tab,
          tabs: [
            Tab(text: l10n.accepted),
            Tab(text: l10n.requests),
            Tab(text: l10n.sentInvites),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _topHeader(context),
                  const SizedBox(height: 14),
                  Expanded(
                    child: TabBarView(
                      controller: _tab,
                      children: [
                        // Accepted
                        _accepted.isEmpty
                            ? _empty(l10n.noAcceptedConnections)
                            : RefreshIndicator(
                                onRefresh: _load,
                                child: ListView.separated(
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  itemCount: _accepted.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(height: 12),
                                  itemBuilder: (context, i) {
                                    final c = _accepted[i];
                                    final title = _bestName(c);
                                    final subtitle = _bestEmail(c);
                                    final id = _toInt(c['id']);

                                    return _cardTile(
                                      title: title,
                                      subtitle: subtitle,
                                      icon: Icons.verified_user_outlined,
                                      onTap: () {},
                                      actions: [
                                        IconButton(
                                          onPressed: () => _remove(id),
                                          icon: const Icon(Icons.link_off),
                                          tooltip: l10n.remove,
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ),

                        // Inbox (requests)
                        _inbox.isEmpty
                            ? _empty(l10n.noRequests)
                            : RefreshIndicator(
                                onRefresh: _load,
                                child: ListView.separated(
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  itemCount: _inbox.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(height: 12),
                                  itemBuilder: (context, i) {
                                    final r = _inbox[i];
                                    final title = _bestName(r);
                                    final subtitle = _bestEmail(r);
                                    final id = _toInt(r['id']);

                                    return _cardTile(
                                      title: title,
                                      subtitle: subtitle,
                                      icon: Icons.mail_outline,
                                      onTap: () {},
                                      actions: [
                                        IconButton(
                                          onPressed: () =>
                                              _respond(id, 'ACCEPT'),
                                          icon: const Icon(Icons.check_circle),
                                          tooltip: l10n.accept,
                                        ),
                                        IconButton(
                                          onPressed: () =>
                                              _respond(id, 'DECLINE'),
                                          icon: const Icon(Icons.cancel),
                                          tooltip: l10n.decline,
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ),

                        // Sent
                        _sent.isEmpty
                            ? _empty(l10n.noSentInvites)
                            : RefreshIndicator(
                                onRefresh: _load,
                                child: ListView.separated(
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  itemCount: _sent.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(height: 12),
                                  itemBuilder: (context, i) {
                                    final s = _sent[i];
                                    final title = _bestName(s);
                                    final subtitle = _bestEmail(s);
                                    final id = _toInt(s['id']);

                                    return _cardTile(
                                      title: title,
                                      subtitle: subtitle,
                                      icon: Icons.outbox_outlined,
                                      onTap: () {},
                                      actions: [
                                        IconButton(
                                          onPressed: () => _remove(id),
                                          icon: const Icon(Icons.close),
                                          tooltip: l10n.cancel,
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _InviteSheet extends StatefulWidget {
  final TextEditingController controller;
  final bool loading;
  final Future<List<Map<String, dynamic>>> Function(String q) onSearch;
  final Future<void> Function(int targetId) onInvite;

  const _InviteSheet({
    required this.controller,
    required this.loading,
    required this.onSearch,
    required this.onInvite,
  });

  @override
  State<_InviteSheet> createState() => _InviteSheetState();
}

class _InviteSheetState extends State<_InviteSheet> {
  List<Map<String, dynamic>> _results = [];
  bool _searching = false;

  Future<void> _runSearch(String q) async {
    final query = q.trim();
    if (query.length < 2) {
      setState(() => _results = []);
      return;
    }

    setState(() => _searching = true);

    try {
      final data = await widget.onSearch(query);
      if (!mounted) return;
      setState(() => _results = data);
    } catch (_) {
      if (!mounted) return;
      setState(() => _results = []);
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context)!;
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.inviteUser, style: t.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: TextField(
                    controller: widget.controller,
                    onChanged: _runSearch,
                    decoration: InputDecoration(
                      hintText: l10n.searchUsersHint,
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: widget.controller.text.isEmpty
                          ? null
                          : IconButton(
                              onPressed: () {
                                widget.controller.clear();
                                _runSearch('');
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
                        borderSide: BorderSide(color: cs.outlineVariant.withOpacity(0.35)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: cs.primary, width: 1.5),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 320,
                child: _searching
                    ? const Center(child: CircularProgressIndicator())
                    : _results.isEmpty
                        ? Center(
                            child: Text(
                              l10n.noResults,
                              style: t.bodyMedium?.copyWith(
                                color: cs.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          )
                        : ListView.separated(
                            itemCount: _results.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (context, i) {
                              final u = _results[i];
                              final raw = u['id'] ?? u['user_id'] ?? u['target_id'] ?? u['targetId'] ?? 0;
                              final targetId = raw is int ? raw : int.tryParse(raw.toString()) ?? 0;
                              final name = (u['display_name'] ?? u['displayName'] ?? '').toString();
                              final email = (u['email'] ?? '').toString();

                              return Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: cs.surfaceContainerHighest.withOpacity(0.55),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(color: cs.outlineVariant.withOpacity(0.25)),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            name.isEmpty ? '—' : name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: t.titleSmall?.copyWith(fontWeight: FontWeight.w900),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            email,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: t.bodySmall?.copyWith(
                                              color: cs.onSurfaceVariant,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    if (targetId <= 0)
                                      Icon(Icons.error_outline, color: cs.error),
                                    if (targetId <= 0) const SizedBox(width: 8),
                                    FilledButton(
                                      onPressed: (widget.loading || targetId <= 0)
                                          ? null
                                          : () => widget.onInvite(targetId),
                                      child: Text(l10n.invite),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}