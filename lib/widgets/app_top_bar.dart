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
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

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
      titleSpacing: 24,
      title: Text(
        title,
        style: theme.textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.w500,
          letterSpacing: 0.2,
        ),
      ),
      actions: [
        ...actions,
        if (showProfileAction)
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 16, start: 4),
            child: FutureBuilder<String?>(
              future: _profileImagePath(),
              builder: (context, snapshot) {
                final path = snapshot.data;

                return InkWell(
                  onTap: () => _openProfile(context),
                  customBorder: const CircleBorder(),
                  child: CircleAvatar(
                    radius: 20,
                    backgroundColor: cs.primaryContainer,
                    foregroundColor: cs.onPrimaryContainer,
                    backgroundImage: path == null ? null : FileImage(File(path)),
                    child: path == null
                        ? const Icon(Icons.person_outline_rounded)
                        : null,
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}
