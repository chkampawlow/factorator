import 'package:flutter/material.dart';

class ActionTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color bg;
  final Color? fg;
  final VoidCallback onTap;

  const ActionTile({
    super.key,
    required this.label,
    required this.icon,
    required this.bg,
    this.fg,
    required this.onTap,
  });

  bool _isDarkColor(Color color) {
    return color.computeLuminance() < 0.5;
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    final textColor = fg ?? (_isDarkColor(bg) ? Colors.white : Colors.black87);

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 20,
              color: textColor,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              softWrap: true,
              style: t.labelMedium?.copyWith(
                fontWeight: FontWeight.w900,
                color: textColor,
                height: 1.05,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
