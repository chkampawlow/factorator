import 'package:flutter/material.dart';

class ActionTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color bg;
  final VoidCallback onTap;

  const ActionTile({
    super.key,
    required this.label,
    required this.icon,
    required this.bg,
    required this.onTap,
  });

  bool _isDarkColor(Color color) {
    return color.computeLuminance() < 0.5;
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    final textColor = _isDarkColor(bg) ? Colors.white : Colors.black87;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              size: 22,
              color: textColor,
            ),

            const Spacer(),

            Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              softWrap: true,
              style: t.bodyMedium?.copyWith(
                fontWeight: FontWeight.w900,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}