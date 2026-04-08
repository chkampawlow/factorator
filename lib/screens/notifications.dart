// lib/screens/notifications.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:my_app/l10n/app_localizations.dart';
import 'package:my_app/storage/connections_repo.dart';
import 'package:my_app/storage/notifications_repo.dart';
import 'package:my_app/widgets/app_alerts.dart';

/// Opens the full notifications sheet (optional if you still want it somewhere).
Future<void> showNotificationsSheet(BuildContext context) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const NotificationsSheet(),
  );
}

/// Bell button that opens a Facebook-like anchored popover under the icon.
class NotificationsBellButton extends StatefulWidget {
  const NotificationsBellButton({super.key});

  @override
  State<NotificationsBellButton> createState() => _NotificationsBellButtonState();
}

class _NotificationsBellButtonState extends State<NotificationsBellButton> {
  final LayerLink _link = LayerLink();
  OverlayEntry? _entry;

  void _close() {
    _entry?.remove();
    _entry = null;
  }

  void _toggle() {
    if (_entry != null) {
      _close();
      return;
    }

    final overlay = Overlay.of(context);
    if (overlay == null) return;

    final cs = Theme.of(context).colorScheme;

    _entry = OverlayEntry(
      builder: (_) {
        return Positioned.fill(
          child: Stack(
            children: [
              // Tap outside closes
              GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _close,
                child: const SizedBox.expand(),
              ),
              // Anchored popover
              CompositedTransformFollower(
                link: _link,
                showWhenUnlinked: false,
                followerAnchor: Alignment.topRight,
                targetAnchor: Alignment.bottomRight,
                offset: const Offset(0, 8),
                child: Material(
                  color: Colors.transparent,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: 360,
                      maxHeight: 420,
                    ),
                    child: NotificationsPopoverCard(
                      maxHeight: 420,
                      borderColor: cs.outlineVariant.withOpacity(0.25),
                      onClose: _close,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );

    overlay.insert(_entry!);
  }

  @override
  void dispose() {
    _close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _link,
      child: IconButton(
        tooltip: AppLocalizations.of(context)!.notifications,
        icon: const Icon(Icons.notifications_none_rounded),
        onPressed: _toggle,
      ),
    );
  }
}

class NotificationsPopoverCard extends StatefulWidget {
  final double maxHeight;
  final Color borderColor;
  final VoidCallback? onClose;

  const NotificationsPopoverCard({
    super.key,
    required this.maxHeight,
    required this.borderColor,
    this.onClose,
  });

  @override
  State<NotificationsPopoverCard> createState() => _NotificationsPopoverCardState();
}

class _NotificationsPopoverCardState extends State<NotificationsPopoverCard> {
  final NotificationsRepo _repo = NotificationsRepo();
  final ConnectionsRepo _connectionsRepo = ConnectionsRepo();
  final Set<int> _actingNotifIds = <int>{};

  bool _loading = true;
  bool _marking = false;
  List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    return int.tryParse(v.toString()) ?? 0;
  }

  bool _isRead(Map<String, dynamic> n) => (n['is_read'] == true);

  bool _isInvite(Map<String, dynamic> n) =>
      (n['type'] ?? '').toString().toUpperCase().trim() == 'CONNECTION_INVITE';

  String _lbl(BuildContext context, String fr, String en, String ar) {
    final code = Localizations.localeOf(context).languageCode.toLowerCase();
    if (code == 'ar') return ar;
    if (code == 'fr') return fr;
    return en;
  }

  String _title(Map<String, dynamic> n) => (n['title'] ?? '').toString().trim();
  String _body(Map<String, dynamic> n) => (n['body'] ?? '').toString().trim();

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);

    try {
      final items = await _repo.list(limit: 20, unreadOnly: false);
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _items = [];
        _loading = false;
      });
    }
  }

  Future<void> _markRead(int id) async {
    if (_marking || id <= 0) return;
    if (!mounted) return;
    setState(() => _marking = true);

    try {
      await _repo.markRead(id);
      if (!mounted) return;
      setState(() {
        for (final n in _items) {
          final nid = _toInt(n['id']);
          if (nid == id) {
            n['is_read'] = true;
            break;
          }
        }
      });
    } finally {
      if (mounted) setState(() => _marking = false);
    }
  }

  Future<void> _markAll() async {
    if (_marking) return;
    if (!mounted) return;
    setState(() => _marking = true);

    try {
      await _repo.markAllRead();
      if (!mounted) return;
      setState(() {
        for (final n in _items) {
          n['is_read'] = true;
        }
      });
    } finally {
      if (mounted) setState(() => _marking = false);
    }
  }

  int _extractConnectionId(Map<String, dynamic> n) {
    final data = n['data_json'];
    try {
      if (data is Map) {
        final m = Map<String, dynamic>.from(data);
        return _toInt(m['connection_id'] ?? m['connectionId']);
      }
      if (data is String && data.trim().isNotEmpty) {
        final decoded = jsonDecode(data);
        if (decoded is Map) {
          final m = Map<String, dynamic>.from(decoded);
          return _toInt(m['connection_id'] ?? m['connectionId']);
        }
      }
    } catch (_) {}
    return 0;
  }

  String _extractInviteName(Map<String, dynamic> n) {
    final data = n['data_json'];
    try {
      if (data is Map) {
        final m = Map<String, dynamic>.from(data);
        final v = (m['requester_display_name'] ??
                m['requesterDisplayName'] ??
                m['from_display_name'] ??
                m['fromDisplayName'] ??
                m['from_name'] ??
                m['fromName'] ??
                '')
            .toString()
            .trim();
        if (v.isNotEmpty) return v;
      }
      if (data is String && data.trim().isNotEmpty) {
        final decoded = jsonDecode(data);
        if (decoded is Map) {
          final m = Map<String, dynamic>.from(decoded);
          final v = (m['requester_display_name'] ??
                  m['requesterDisplayName'] ??
                  m['from_display_name'] ??
                  m['fromDisplayName'] ??
                  m['from_name'] ??
                  m['fromName'] ??
                  '')
              .toString()
              .trim();
          if (v.isNotEmpty) return v;
        }
      }
    } catch (_) {}

    final body = (n['body'] ?? '').toString();
    final match =
        RegExp(r'Invitation\s+de\s+(.+)$', caseSensitive: false).firstMatch(body);
    if (match != null) return (match.group(1) ?? '').trim();

    return (n['title'] ?? '').toString().trim();
  }

  String _extractInviteEmail(Map<String, dynamic> n) {
    final data = n['data_json'];
    try {
      if (data is Map) {
        final m = Map<String, dynamic>.from(data);
        final v = (m['requester_email'] ??
                m['requesterEmail'] ??
                m['from_email'] ??
                m['fromEmail'] ??
                '')
            .toString()
            .trim();
        if (v.isNotEmpty) return v;
      }
      if (data is String && data.trim().isNotEmpty) {
        final decoded = jsonDecode(data);
        if (decoded is Map) {
          final m = Map<String, dynamic>.from(decoded);
          final v = (m['requester_email'] ??
                  m['requesterEmail'] ??
                  m['from_email'] ??
                  m['fromEmail'] ??
                  '')
              .toString()
              .trim();
          if (v.isNotEmpty) return v;
        }
      }
    } catch (_) {}
    return '';
  }

  Future<void> _respondInvite({
    required Map<String, dynamic> n,
    required String action, // ACCEPT / REJECT
  }) async {
    final notifId = _toInt(n['id']);
    final connectionId = _extractConnectionId(n);

    if (notifId <= 0 || connectionId <= 0) return;
    if (_actingNotifIds.contains(notifId)) return;

    if (!mounted) return;
    setState(() => _actingNotifIds.add(notifId));

    try {
      await _connectionsRepo.respondInvitation(
        connectionId: connectionId,
        action: action,
      );

      await _repo.markRead(notifId);

      if (!mounted) return;
      n['is_read'] = true;
      await _load();

      if (!mounted) return;
      AppAlerts.success(
        context,
        action == 'ACCEPT'
            ? _lbl(context, 'Invitation acceptée', 'Invitation accepted', 'تم قبول الدعوة')
            : _lbl(context, 'Invitation refusée', 'Invitation declined', 'تم رفض الدعوة'),
      );
    } catch (e) {
      if (!mounted) return;
      AppAlerts.error(context, e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _actingNotifIds.remove(notifId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;

    return Container(
      constraints: BoxConstraints(maxHeight: widget.maxHeight),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: widget.borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Column(
          children: [
            // header
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.notifications,
                      style: t.titleSmall?.copyWith(fontWeight: FontWeight.w900),
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      FocusManager.instance.primaryFocus?.unfocus();
                      widget.onClose?.call();
                    },
                    icon: const Icon(Icons.close_rounded),
                    tooltip: l10n.close,
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // list
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _items.isEmpty
                      ? Center(
                          child: Text(
                            l10n.noNotifications,
                            style: t.bodyMedium?.copyWith(
                              color: cs.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: ListView.separated(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
                            itemCount: _items.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (_, i) {
                              final n = _items[i];
                              final read = _isRead(n);

                              final notifId = _toInt(n['id']);
                              final connId = _extractConnectionId(n);

                              final isInvite = _isInvite(n);
                              final acting = _actingNotifIds.contains(notifId);

                              final inviteName = isInvite ? _extractInviteName(n) : '';
                              final inviteEmail = isInvite ? _extractInviteEmail(n) : '';

                              final title = _title(n);
                              final body = _body(n);

                              final onTap = (isInvite && !read)
                                  ? null
                                  : (read ? null : () => _markRead(notifId));

                              return InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: onTap,
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: read
                                        ? cs.surfaceContainerHighest.withOpacity(0.45)
                                        : cs.primaryContainer.withOpacity(0.35),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: cs.outlineVariant.withOpacity(0.25),
                                    ),
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      Container(
                                        height: 46,
                                        width: 46,
                                        decoration: BoxDecoration(
                                          color: cs.surface.withOpacity(0.90),
                                          borderRadius: BorderRadius.circular(16),
                                          border: Border.all(
                                            color: cs.outlineVariant.withOpacity(0.22),
                                          ),
                                        ),
                                        child: Icon(
                                          isInvite
                                              ? Icons.mail_outline_rounded
                                              : Icons.notifications_rounded,
                                          color: read ? cs.onSurfaceVariant : cs.primary,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              isInvite
                                                  ? (inviteName.isEmpty
                                                      ? _lbl(context, 'Invitation', 'Invitation', 'دعوة')
                                                      : inviteName)
                                                  : (title.isEmpty ? l10n.notifications : title),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: t.titleSmall?.copyWith(
                                                fontWeight: FontWeight.w900,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              isInvite
                                                  ? (inviteEmail.isEmpty
                                                      ? (body.isEmpty ? l10n.notifications : body)
                                                      : inviteEmail)
                                                  : (body.isEmpty ? '' : body),
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

                                      // right actions
                                      if (isInvite && !read && connId > 0)
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            _CircleIconAction(
                                              icon: Icons.check_rounded,
                                              tooltip: _lbl(context, 'Accepter', 'Accept', 'قبول'),
                                              onPressed: acting
                                                  ? null
                                                  : () => _respondInvite(n: n, action: 'ACCEPT'),
                                            ),
                                            const SizedBox(width: 10),
                                            _CircleIconAction(
                                              icon: Icons.close_rounded,
                                              tooltip: _lbl(context, 'Refuser', 'Decline', 'رفض'),
                                              onPressed: acting
                                                  ? null
                                                  : () => _respondInvite(n: n, action: 'REJECT'),
                                            ),
                                          ],
                                        )
                                      else if (!read)
                                        Container(
                                          width: 10,
                                          height: 10,
                                          margin: const EdgeInsets.only(left: 10),
                                          decoration: BoxDecoration(
                                            color: cs.primary,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
            ),

            // footer
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
              child: Row(
                children: [
                  if (_marking)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  const Spacer(),
                  FilledButton.tonal(
                    onPressed: (_items.isEmpty || _marking) ? null : _markAll,
                    child: Text(l10n.markAllRead),
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

/// Optional full-screen bottom sheet.
class NotificationsSheet extends StatefulWidget {
  const NotificationsSheet({super.key});

  @override
  State<NotificationsSheet> createState() => _NotificationsSheetState();
}

class _NotificationsSheetState extends State<NotificationsSheet> {
  final NotificationsRepo _repo = NotificationsRepo();
  final ConnectionsRepo _connectionsRepo = ConnectionsRepo();
  final Set<int> _actingNotifIds = <int>{};

  bool _loading = true;
  bool _marking = false;
  List<Map<String, dynamic>> _items = [];

  int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    return int.tryParse(v.toString()) ?? 0;
  }

  bool _isInvite(Map<String, dynamic> n) =>
      (n['type'] ?? '').toString().toUpperCase().trim() == 'CONNECTION_INVITE';

  bool _isRead(Map<String, dynamic> n) => (n['is_read'] == true);

  String _lbl(BuildContext context, String fr, String en, String ar) {
    final code = Localizations.localeOf(context).languageCode.toLowerCase();
    if (code == 'ar') return ar;
    if (code == 'fr') return fr;
    return en;
  }

  int _extractConnectionId(Map<String, dynamic> n) {
    final data = n['data_json'];
    try {
      if (data is Map) {
        final m = Map<String, dynamic>.from(data);
        return _toInt(m['connection_id'] ?? m['connectionId']);
      }
      if (data is String && data.trim().isNotEmpty) {
        final decoded = jsonDecode(data);
        if (decoded is Map) {
          final m = Map<String, dynamic>.from(decoded);
          return _toInt(m['connection_id'] ?? m['connectionId']);
        }
      }
    } catch (_) {}
    return 0;
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);

    try {
      final items = await _repo.list(limit: 50, unreadOnly: false);
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _items = [];
        _loading = false;
      });
      AppAlerts.error(context, e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _markRead(int id) async {
    if (_marking || id <= 0) return;
    setState(() => _marking = true);

    try {
      await _repo.markRead(id);
      if (!mounted) return;
      setState(() {
        for (final n in _items) {
          if (_toInt(n['id']) == id) {
            n['is_read'] = true;
            break;
          }
        }
      });
    } finally {
      if (mounted) setState(() => _marking = false);
    }
  }

  Future<void> _markAll() async {
    if (_marking) return;
    setState(() => _marking = true);

    try {
      await _repo.markAllRead();
      if (!mounted) return;
      setState(() {
        for (final n in _items) {
          n['is_read'] = true;
        }
      });
    } finally {
      if (mounted) setState(() => _marking = false);
    }
  }

  Future<void> _respondInvite({
    required Map<String, dynamic> n,
    required String action,
  }) async {
    final notifId = _toInt(n['id']);
    final connectionId = _extractConnectionId(n);

    if (notifId <= 0 || connectionId <= 0) return;
    if (_actingNotifIds.contains(notifId)) return;

    if (!mounted) return;
    setState(() => _actingNotifIds.add(notifId));

    try {
      await _connectionsRepo.respondInvitation(connectionId: connectionId, action: action);
      await _repo.markRead(notifId);

      if (!mounted) return;
      n['is_read'] = true;
      await _load();

      if (!mounted) return;
      AppAlerts.success(
        context,
        action == 'ACCEPT'
            ? _lbl(context, 'Invitation acceptée', 'Invitation accepted', 'تم قبول الدعوة')
            : _lbl(context, 'Invitation refusée', 'Invitation declined', 'تم رفض الدعوة'),
      );
    } catch (e) {
      if (!mounted) return;
      AppAlerts.error(context, e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _actingNotifIds.remove(notifId));
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;

    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final screenH = MediaQuery.of(context).size.height;
    final maxH = screenH * 0.85;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxH),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.notifications, style: t.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 10),

                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : _items.isEmpty
                          ? Center(
                              child: Text(
                                l10n.noNotifications,
                                style: t.bodyMedium?.copyWith(
                                  color: cs.onSurfaceVariant,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            )
                          : RefreshIndicator(
                              onRefresh: _load,
                              child: ListView.separated(
                                physics: const AlwaysScrollableScrollPhysics(),
                                itemCount: _items.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 10),
                                itemBuilder: (_, i) {
                                  final n = _items[i];
                                  final id = _toInt(n['id']);
                                  final read = _isRead(n);
                                  final isInvite = _isInvite(n);
                                  final connId = _extractConnectionId(n);
                                  final acting = _actingNotifIds.contains(id);

                                  final title = (n['title'] ?? '').toString();
                                  final body = (n['body'] ?? '').toString();

                                  return InkWell(
                                    borderRadius: BorderRadius.circular(18),
                                    onTap: read ? null : () => _markRead(id),
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: read
                                            ? cs.surfaceContainerHighest.withOpacity(0.45)
                                            : cs.primaryContainer.withOpacity(0.35),
                                        borderRadius: BorderRadius.circular(18),
                                        border: Border.all(color: cs.outlineVariant.withOpacity(0.25)),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            title.isEmpty ? l10n.notifications : title,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: t.titleSmall?.copyWith(fontWeight: FontWeight.w900),
                                          ),
                                          if (body.trim().isNotEmpty) ...[
                                            const SizedBox(height: 4),
                                            Text(
                                              body,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: t.bodySmall?.copyWith(
                                                color: cs.onSurfaceVariant,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                          if (isInvite && !read && connId > 0) ...[
                                            const SizedBox(height: 10),
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: FilledButton.tonal(
                                                    onPressed: acting ? null : () => _respondInvite(n: n, action: 'ACCEPT'),
                                                    child: Text(_lbl(context, 'Accepter', 'Accept', 'قبول')),
                                                  ),
                                                ),
                                                const SizedBox(width: 10),
                                                Expanded(
                                                  child: OutlinedButton(
                                                    onPressed: acting ? null : () => _respondInvite(n: n, action: 'REJECT'),
                                                    child: Text(_lbl(context, 'Refuser', 'Decline', 'رفض')),
                                                  ),
                                                ),
                                                if (acting) ...[
                                                  const SizedBox(width: 10),
                                                  const SizedBox(
                                                    width: 16,
                                                    height: 16,
                                                    child: CircularProgressIndicator(strokeWidth: 2),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                ),

                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                  child: Row(
                    children: [
                      if (_marking)
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      const Spacer(),
                      FilledButton.tonal(
                        onPressed: (_items.isEmpty || _marking) ? null : _markAll,
                        child: Text(l10n.markAllRead),
                      ),
                    ],
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

// Circle icon action for popover invitation actions (accept/decline)
class _CircleIconAction extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  const _CircleIconAction({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final enabled = onPressed != null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest.withOpacity(enabled ? 0.55 : 0.25),
            shape: BoxShape.circle,
            border: Border.all(color: cs.outlineVariant.withOpacity(0.25)),
          ),
          child: Tooltip(
            message: tooltip,
            child: Icon(
              icon,
              size: 20,
              color: enabled ? cs.onSurface : cs.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}