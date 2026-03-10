import 'package:flutter/material.dart';
import 'package:my_app/services/auth_service.dart';
import 'package:my_app/themes/app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final AuthService _authService = AuthService();

  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _passwordCtrl = TextEditingController();

  bool _rememberMe = true;
  bool _obscurePassword = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

Future<void> _login() async {
  FocusScope.of(context).unfocus();

  if (!_formKey.currentState!.validate()) return;

  setState(() {
    _loading = true;
    _error = null;
  });

  debugPrint('===== LOGIN START =====');
  debugPrint('Email: ${_emailCtrl.text.trim()}');
  debugPrint('Remember me: $_rememberMe');

  try {
    debugPrint('Calling AuthService.login() ...');

    final response = await _authService.login(
      email: _emailCtrl.text.trim(),
      password: _passwordCtrl.text,
      rememberMe: _rememberMe,
    );

    debugPrint('Login response received: $response');

    if (!mounted) {
      debugPrint('Widget not mounted anymore, stopping.');
      return;
    }

    final user = response['user'] as Map<String, dynamic>?;
    final firstName = (user?['first_name'] ?? '').toString();

    debugPrint('Parsed user: $user');
    debugPrint('First name: $firstName');
    debugPrint('Navigating to /home ...');

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          firstName.isNotEmpty ? 'Welcome $firstName' : 'Login success',
        ),
      ),
    );

    Navigator.pushReplacementNamed(context, '/dashboard');
  } catch (e, stackTrace) {
    debugPrint('===== LOGIN ERROR =====');
    debugPrint('Error: $e');
    debugPrint('StackTrace: $stackTrace');

    setState(() {
      _error = e.toString().replaceFirst('Exception: ', '');
    });
  } finally {
    debugPrint('===== LOGIN END =====');

    if (mounted) {
      setState(() {
        _loading = false;
      });
    }
  }
}
  InputDecoration _decoration({
    required String label,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      suffixIcon: suffixIcon,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  Center(
                    child: Container(
                      height: 74,
                      width: 74,
                      decoration: BoxDecoration(
                        color: AppTheme.mintSoft.withOpacity(isDark ? 0.15 : 1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.lock_outline_rounded,
                        size: 34,
                        color: AppTheme.mint,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Welcome back',
                    style: theme.textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Login to manage your clients, products and invoices.',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 22),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _emailCtrl,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              decoration: _decoration(
                                label: 'Email address',
                                icon: Icons.mail_outline_rounded,
                              ),
                              validator: (value) {
                                final v = value?.trim() ?? '';
                                if (v.isEmpty) return 'Email is required';
                                if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(v)) {
                                  return 'Enter a valid email';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _passwordCtrl,
                              obscureText: _obscurePassword,
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) => _login(),
                              decoration: _decoration(
                                label: 'Password',
                                icon: Icons.lock_outline_rounded,
                                suffixIcon: IconButton(
                                  onPressed: () {
                                    setState(() {
                                      _obscurePassword = !_obscurePassword;
                                    });
                                  },
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                  ),
                                ),
                              ),
                              validator: (value) {
                                final v = value ?? '';
                                if (v.isEmpty) return 'Password is required';
                                if (v.length < 6) return 'Minimum 6 characters';
                                return null;
                              },
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Checkbox(
                                  value: _rememberMe,
                                  activeColor: AppTheme.mint,
                                  onChanged: (value) {
                                    setState(() {
                                      _rememberMe = value ?? false;
                                    });
                                  },
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    'Remember me',
                                    style: theme.textTheme.bodyMedium,
                                  ),
                                ),
                                TextButton(
                                  onPressed: () {},
                                  child: const Text('Forgot password?'),
                                ),
                              ],
                            ),
                            if (_error != null) ...[
                              const SizedBox(height: 8),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: cs.errorContainer.withOpacity(0.7),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  _error!,
                                  style: TextStyle(
                                    color: cs.onErrorContainer,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton(
                                onPressed: _loading ? null : _login,
                                child: _loading
                                    ? const SizedBox(
                                        height: 22,
                                        width: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.4,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text('Login'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Center(
                    child: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          "Don't have an account? ",
                          style: theme.textTheme.bodySmall,
                        ),
                        TextButton(
                          onPressed: () {
Navigator.pushNamed(context, '/signup');                          },
                          child: const Text('Create one'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}