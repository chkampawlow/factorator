import 'dart:io';

import 'package:flutter/material.dart';
import 'package:my_app/screens/profile_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppTopBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget> actions;
  final VoidCallback onToggleTheme;
  final void Function(Color color) onChangePrimaryColor;
  final void Function(String code) onChangeLanguage;
  final Color currentPrimaryColor;
  final bool showProfileAction;

  const AppTopBar({
    super.key,
    required this.title,
    required this.onToggleTheme,
    required this.onChangePrimaryColor,
    required this.onChangeLanguage,
    required this.currentPrimaryColor,
    this.showProfileAction = true,
    this.actions = const [],
  });

  @override
  Size get preferredSize => const Size.fromHeight(68);

  Future<String?> _profileImagePath() async {
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString('profile_image_path');
    if (path == null || path.trim().isEmpty) return null;

    final file = File(path);
    if (!await file.exists()) return null;
    return path;
  }

  void _openProfile(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProfileScreen(
          onToggleTheme: onToggleTheme,
          onChangePrimaryColor: onChangePrimaryColor,
          onChangeLanguage: onChangeLanguage,
          currentPrimaryColor: currentPrimaryColor,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return AppBar(
      titleSpacing: 18,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: cs.primary.withValues(alpha: 0.22),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Image.asset(
              'assets/icons/el-fatoura-icon.png',
              fit: BoxFit.cover,
              filterQuality: FilterQuality.high,
            ),
          ),
          const SizedBox(width: 11),
          Flexible(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
              ),
            ),
          ),
        ],
      ),
      actions: [
        ...actions,
        if (showProfileAction)
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 14, start: 4),
            child: FutureBuilder<String?>(
              future: _profileImagePath(),
              builder: (context, snapshot) {
                final path = snapshot.data;

                return InkWell(
                  onTap: () => _openProfile(context),
                  customBorder: const CircleBorder(),
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: cs.primary.withValues(alpha: 0.22),
                      ),
                    ),
                    child: CircleAvatar(
                      radius: 18,
                      backgroundColor: cs.primaryContainer,
                      foregroundColor: cs.primary,
                      backgroundImage:
                          path == null ? null : FileImage(File(path)),
                      child: path == null
                          ? const Icon(Icons.person_outline_rounded, size: 20)
                          : null,
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}
