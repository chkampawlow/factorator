// lib/screens/connections_search_sheet.dart
import 'package:flutter/material.dart';

import 'package:my_app/l10n/app_localizations.dart';
import 'package:my_app/storage/connections_repo.dart';
import 'package:my_app/widgets/app_alerts.dart';

// In-memory recent searches for the connections search sheet.
// Keeps the last queries during the app session.
final List<String> connectionsRecentSearches = <String>[];
// In-memory cache of targets already invited during this app session.
final Set<int> connectionsInvitedTargets = <int>{};

/// Opens a bottom sheet that lets the user search other users and send invitations.
Future<void> showConnectionsSearchSheet(BuildContext context) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const ConnectionsSearchSheet(),
  );
}

class ConnectionsSearchSheet extends StatefulWidget {
  const ConnectionsSearchSheet({super.key});

  @override
  State<ConnectionsSearchSheet> createState() => _ConnectionsSearchSheetState();
}

class _ConnectionsSearchSheetState extends State<ConnectionsSearchSheet> {
  final ConnectionsRepo _repo = ConnectionsRepo();

  late final TextEditingController _ctrl;

  bool _loading = false;
  bool _sending = false;
  bool _loadingAccepted = false;
  List<Map<String, dynamic>> _results = [];
  List<Map<String, dynamic>> _accepted = [];

  List<String> get _recent => List<String>.from(connectionsRecentSearches);

  bool _alreadyInvited(int targetId) => connectionsInvitedTargets.contains(targetId);

  String _connStatus(Map<String, dynamic> u) {
    return (u['connection_status'] ?? u['connectionStatus'] ?? '')
        .toString()
        .trim()
        .toUpperCase();
  }

  bool _isPending(Map<String, dynamic> u) => _connStatus(u) == 'PENDING';
  bool _isAccepted(Map<String, dynamic> u) => _connStatus(u) == 'ACCEPTED';

  void _pushRecent(String q) {
    final v = q.trim();
    if (v.length < 2) return;

    connectionsRecentSearches.removeWhere(
      (e) => e.toLowerCase() == v.toLowerCase(),
    );
    connectionsRecentSearches.insert(0, v);

    // keep max 8
    if (connectionsRecentSearches.length > 8) {
      connectionsRecentSearches.removeRange(8, connectionsRecentSearches.length);
    }
  }

  void _clearRecents() {
    connectionsRecentSearches.clear();
    if (!mounted) return;
    setState(() {});
  }

  void _applyRecent(String q) {
    _ctrl.text = q;
    _ctrl.selection = TextSelection.fromPosition(
      TextPosition(offset: _ctrl.text.length),
    );
    if (mounted) setState(() {});
    _search(q);
  }

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController();
    _loadAccepted();
  }

  @override
  void dispose() {
    // IMPORTANT: we do NOT dispose _ctrl here because this sheet can still
    // rebuild during the closing transition and the TextField would crash.
    super.dispose();
  }

  Future<void> _loadAccepted() async {
    if (_loadingAccepted) return;
    if (!mounted) return;
    setState(() => _loadingAccepted = true);

    try {
      final items = await _repo.accepted();
      if (!mounted) return;
      setState(() => _accepted = items);
    } catch (_) {
      if (!mounted) return;
      setState(() => _accepted = []);
    } finally {
      if (mounted) setState(() => _loadingAccepted = false);
    }
  }

  List<Map<String, dynamic>> _acceptedForEmptySearch() {
    if (_ctrl.text.trim().isNotEmpty) return const [];
    if (_accepted.isEmpty) return const [];
    return _accepted;
  }

  Future<void> _search(String q) async {
    final query = q.trim();

    if (query.length < 2) {
      if (!mounted) return;
      setState(() {
        _results = [];
        _loading = false;
      });
      await _loadAccepted();
      return;
    }

    if (_loading) return;

    setState(() => _loading = true);

    try {
      final items = await _repo.searchUsers(query);
      _pushRecent(query);
      if (!mounted) return;
      setState(() => _results = items);
    } catch (e) {
      if (!mounted) return;
      setState(() => _results = []);
      AppAlerts.error(context, e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    return int.tryParse(v.toString()) ?? 0;
  }

  String _firstNonEmpty(Map<String, dynamic> u, List<String> keys) {
    for (final k in keys) {
      final v = (u[k] ?? '').toString().trim();
      if (v.isNotEmpty) return v;
    }
    return '';
  }

  String _name(Map<String, dynamic> u) {
    final direct = _firstNonEmpty(u, const [
      'organization_name',
      'organizationName',
      'display_name',
      'displayName',
    ]);
    if (direct.isNotEmpty) return direct;

    final prefixed = _firstNonEmpty(u, const [
      'target_organization_name',
      'targetOrganizationName',
      'target_display_name',
      'targetDisplayName',
      'requester_organization_name',
      'requesterOrganizationName',
      'requester_display_name',
      'requesterDisplayName',
      'other_organization_name',
      'otherOrganizationName',
      'other_display_name',
      'otherDisplayName',
    ]);
    if (prefixed.isNotEmpty) return prefixed;

    final email = _firstNonEmpty(u, const [
      'email',
      'target_email',
      'requester_email',
      'other_email',
    ]);
    return email.isEmpty ? '—' : email;
  }

  String _sub(Map<String, dynamic> u) {
    final websiteRaw = _firstNonEmpty(u, const [
      'website',
      'site',
      'url',
      'target_website',
      'target_site',
      'target_url',
      'requester_website',
      'requester_site',
      'requester_url',
      'other_website',
      'other_site',
      'other_url',
    ]);

    var website = websiteRaw;
    if (website.isNotEmpty) {
      website = website
          .replaceFirst(RegExp(r'^https?://'), '')
          .replaceFirst(RegExp(r'^www\.'), '');
    }
    return website;
  }

  bool _isOrg(Map<String, dynamic> u) {
    final org = _firstNonEmpty(u, const [
      'organization_name',
      'organizationName',
      'target_organization_name',
      'targetOrganizationName',
      'requester_organization_name',
      'requesterOrganizationName',
      'other_organization_name',
      'otherOrganizationName',
    ]);
    return org.isNotEmpty;
  }

  Future<void> _invite(int targetId) async {
    final l10n = AppLocalizations.of(context)!;

    final existing = _results.where((u) => _toInt(u['id'] ?? u['user_id']) == targetId);
    if (existing.isNotEmpty) {
      final u = existing.first;
      if (_isAccepted(u)) {
        AppAlerts.success(context, l10n.accepted);
        return;
      }
      if (_isPending(u)) {
        AppAlerts.success(context, l10n.invitationSent);
        return;
      }
    }

    if (_alreadyInvited(targetId)) {
      AppAlerts.success(context, l10n.invitationSent);
      return;
    }
    if (_sending || targetId <= 0) return;

    setState(() => _sending = true);

    try {
      await _repo.sendInvitation(targetId: targetId);
      connectionsInvitedTargets.add(targetId);

      for (final u in _results) {
        final id = _toInt(u['id'] ?? u['user_id']);
        if (id == targetId) {
          u['connection_status'] = 'PENDING';
          break;
        }
      }

      if (!mounted) return;
      setState(() {});
      AppAlerts.success(context, l10n.invitationSent);
    } catch (e) {
      if (!mounted) return;
      AppAlerts.error(context, e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;

    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final screenH = MediaQuery.of(context).size.height;
    final maxH = screenH * 0.85;

    final acceptedList = _acceptedForEmptySearch();

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        width: double.infinity,
        constraints: BoxConstraints(maxHeight: maxH),
        decoration: BoxDecoration(
          color: cs.surface.withOpacity(0.25),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              children: [
                // Search box
                Container(
                  decoration: BoxDecoration(
                    color: cs.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: cs.outlineVariant.withOpacity(0.30)),
                  ),
                  child: TextField(
                    controller: _ctrl,
                    autofocus: true,
                    onChanged: _search,
                    decoration: InputDecoration(
                      hintText: l10n.searchUsersHint,
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _ctrl.text.isEmpty
                          ? null
                          : IconButton(
                              onPressed: () {
                                _ctrl.clear();
                                if (mounted) setState(() {});
                                _search('');
                              },
                              icon: const Icon(Icons.close),
                            ),
                      filled: true,
                      fillColor: cs.surface,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide(color: cs.primary, width: 1.5),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Recent chips row (chips + clear on same line)
                if (_ctrl.text.trim().isEmpty && _recent.isNotEmpty)
                  SizedBox(
                    height: 40,
                    child: Row(
                      children: [
                        Expanded(
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: _recent.length,
                            separatorBuilder: (_, __) => const SizedBox(width: 8),
                            itemBuilder: (_, i) {
                              final q = _recent[i];
                              return ActionChip(
                                label: Text(q, overflow: TextOverflow.ellipsis),
                                onPressed: () => _applyRecent(q),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 6),
                        TextButton(
                          onPressed: _clearRecents,
                          child: Text(l10n.clear),
                        ),
                      ],
                    ),
                  ),

                if (_ctrl.text.trim().isEmpty && _recent.isNotEmpty) const SizedBox(height: 10),

                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : (_ctrl.text.trim().length < 2)
                          ? (_loadingAccepted
                              ? const Center(child: CircularProgressIndicator())
                              : acceptedList.isEmpty
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
                                      itemCount: acceptedList.length,
                                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                                      itemBuilder: (_, i) {
                                        final u = acceptedList[i];
                                        final sub = _sub(u);

                                        return _UserRowCard(
                                          name: _name(u),
                                          subtitle: sub,
                                          isOrg: _isOrg(u),
                                          trailing: OutlinedButton.icon(
                                            onPressed: null,
                                            icon: const Icon(Icons.verified_rounded),
                                            label: Text(l10n.accepted),
                                          ),
                                        );
                                      },
                                    ))
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
                                  itemBuilder: (_, i) {
                                    final u = _results[i];
                                    final id = _toInt(u['id'] ?? u['user_id'] ?? u['userId']);
                                    final sub = _sub(u);

                                    final status = _connStatus(u);
                                    final isAccepted = status == 'ACCEPTED';
                                    final isPending = status == 'PENDING';
                                    final invited = _alreadyInvited(id) || isPending;

                                    Widget trailing;
                                    if (isAccepted) {
                                      trailing = OutlinedButton.icon(
                                        onPressed: null,
                                        icon: const Icon(Icons.verified_rounded),
                                        label: Text(l10n.accepted),
                                      );
                                    } else if (invited) {
                                      trailing = OutlinedButton.icon(
                                        onPressed: null,
                                        icon: const Icon(Icons.check_rounded),
                                        label: Text(l10n.invitationSent),
                                      );
                                    } else {
                                      trailing = FilledButton(
                                        onPressed: (_sending || id <= 0) ? null : () => _invite(id),
                                        child: Text(l10n.invite),
                                      );
                                    }

                                    return _UserRowCard(
                                      name: _name(u),
                                      subtitle: sub,
                                      isOrg: _isOrg(u),
                                      trailing: trailing,
                                    );
                                  },
                                ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _UserRowCard extends StatelessWidget {
  final String name;
  final String subtitle;
  final bool isOrg;
  final Widget trailing;

  const _UserRowCard({
    required this.name,
    required this.subtitle,
    required this.isOrg,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withOpacity(0.55),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Container(
            height: 42,
            width: 42,
            decoration: BoxDecoration(
              color: cs.surface.withOpacity(0.85),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: cs.outlineVariant.withOpacity(0.22)),
            ),
            child: Icon(
              isOrg ? Icons.business_rounded : Icons.person_rounded,
              color: cs.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.titleSmall?.copyWith(fontWeight: FontWeight.w900),
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }
}