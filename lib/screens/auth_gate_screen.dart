import 'package:flutter/material.dart';
import 'package:my_app/screens/login_screen.dart';
import 'package:my_app/services/auth_service.dart';
import 'package:my_app/themes/app_theme.dart';

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
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              height: 76,
              width: 76,
              decoration: BoxDecoration(
                color: AppTheme.mintSoft.withOpacity(isDark ? 0.15 : 1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.verified_user_outlined,
                color: AppTheme.mint,
                size: 34,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Checking session...',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 14),
            const SizedBox(
              height: 26,
              width: 26,
              child: CircularProgressIndicator(
                strokeWidth: 2.6,
                color: AppTheme.mint,
              ),
            ),
          ],
        ),
      ),
    );
  }
}