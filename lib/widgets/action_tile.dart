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

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final tone = bg;
    final textColor = cs.onSurface;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              tone.withValues(alpha: 0.24),
              tone.withValues(alpha: 0.10),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: tone.withValues(alpha: 0.28)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: tone.withValues(alpha: 0.20),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, size: 19, color: tone),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              softWrap: true,
              style: t.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
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
