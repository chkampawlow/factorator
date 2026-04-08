// lib/screens/app_top_bar.dart
import 'package:flutter/material.dart';

import 'package:my_app/screens/notifications.dart'; // NotificationsBellButton

/// Reusable AppBar with title + optional subtitle (stacked like Facebook),
/// plus optional actions.
class AppTopBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String? subtitle;
  final List<Widget>? actions;
  final bool centerTitle;

  const AppTopBar({
    super.key,
    required this.title,
    this.subtitle,
    this.actions,
    this.centerTitle = false,
  });

  @override
  Size get preferredSize {
    final hasSubtitle = (subtitle ?? '').trim().isNotEmpty;
    // Slightly taller when we show a second line.
    return Size.fromHeight(hasSubtitle ? 72 : kToolbarHeight);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    final hasSubtitle = (subtitle ?? '').trim().isNotEmpty;

    return AppBar(
      centerTitle: centerTitle,
      titleSpacing: 16,
      toolbarHeight: hasSubtitle ? 72 : kToolbarHeight,
      title: hasSubtitle
          ? Column(
              crossAxisAlignment: centerTitle
                  ? CrossAxisAlignment.center
                  : CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 1),
                Text(
                  subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.labelSmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            )
          : Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: t.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
      actions: actions,
    );
  }
}

/// AppBar variant for connections: search + notification bell.
class ConnectionsTopBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String? subtitle;
  final VoidCallback onSearch;

  const ConnectionsTopBar({
    super.key,
    required this.title,
    this.subtitle,
    required this.onSearch,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppTopBar(
      title: title,
      subtitle: subtitle,
      actions: [
        IconButton(
          onPressed: onSearch,
          icon: const Icon(Icons.search),
        ),
        const NotificationsBellButton(),
        const SizedBox(width: 6),
      ],
    );
  }
}