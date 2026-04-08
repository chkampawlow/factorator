import 'package:flutter/material.dart';

enum AlertTone { success, info, warning, error }

class AppAlerts {
  static void show(
    BuildContext context, {
    required String message,
    AlertTone tone = AlertTone.info,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final (bg, fg, icon) = switch (tone) {
      AlertTone.success => (
        cs.primaryContainer,
        cs.onPrimaryContainer,
        Icons.check_circle_rounded,
      ),
      AlertTone.info => (
        cs.secondaryContainer,
        cs.onSecondaryContainer,
        Icons.info_rounded,
      ),
      AlertTone.warning => (
        cs.tertiaryContainer,
        cs.onTertiaryContainer,
        Icons.warning_amber_rounded,
      ),
      AlertTone.error => (
        cs.errorContainer,
        cs.onErrorContainer,
        Icons.error_rounded,
      ),
    };

    // Use the root navigator context so SnackBars appear above modal bottom sheets.
    final rootContext = Navigator.of(context, rootNavigator: true).context;
    final messenger = ScaffoldMessenger.maybeOf(rootContext) ?? ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: bg,
        showCloseIcon: true,
        closeIconColor: fg,
        content: Row(
          children: [
            Icon(icon, color: fg),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: fg, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        action: (actionLabel != null && onAction != null)
            ? SnackBarAction(
                label: actionLabel,
                onPressed: onAction,
                textColor: fg,
              )
            : null,
      ),
    );
  }

  static void success(BuildContext context, String message) =>
      show(context, message: message, tone: AlertTone.success);

  static void error(BuildContext context, String message) =>
      show(context, message: message, tone: AlertTone.error);

  static void warning(BuildContext context, String message) =>
      show(context, message: message, tone: AlertTone.warning);

  static void info(BuildContext context, String message) =>
      show(context, message: message, tone: AlertTone.info);
}