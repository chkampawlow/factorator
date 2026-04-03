import 'package:flutter/material.dart';
import 'package:my_app/screens/login_screen.dart';
import 'package:my_app/l10n/app_localizations.dart';
import 'package:my_app/services/auth_service.dart';

class AuthGateScreen extends StatefulWidget {
  final Widget home;

  const AuthGateScreen({
    super.key,
    required this.home,
  });

  @override
  State<AuthGateScreen> createState() => _AuthGateScreenState();
}

class _AuthGateScreenState extends State<AuthGateScreen> {
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    try {
      final shouldAutoLogin = await _authService.shouldAutoLogin();

      if (!shouldAutoLogin) {
        _goToLogin();
        return;
      }

      await _authService.me();

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => widget.home),
      );
    } catch (_) {
      await _authService.logout();
      _goToLogin();
    }
  }

  void _goToLogin() {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              height: 76,
              width: 76,
              decoration: BoxDecoration(
                color: cs.primaryContainer.withOpacity(0.60),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.verified_user_outlined,
                color: cs.primary,
                size: 34,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              l10n.checkingSession,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 26,
              width: 26,
              child: CircularProgressIndicator(
                strokeWidth: 2.6,
                color: cs.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}