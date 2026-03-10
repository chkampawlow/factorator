import 'package:flutter/material.dart';
import 'package:my_app/services/auth_service.dart';
import 'package:my_app/themes/app_theme.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final PageController _pageController = PageController();
  final AuthService _authService = AuthService();

  final _formKey = GlobalKey<FormState>();

  final TextEditingController _firstNameCtrl = TextEditingController();
  final TextEditingController _lastNameCtrl = TextEditingController();
  final TextEditingController _organizationCtrl = TextEditingController();
  final TextEditingController _fiscalIdCtrl = TextEditingController();
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _phoneCtrl = TextEditingController();
  final TextEditingController _passwordCtrl = TextEditingController();
  final TextEditingController _confirmPasswordCtrl = TextEditingController();

  int _currentPage = 0;
  bool _loading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _error;

  final int _totalPages = 5;

  @override
  void dispose() {
    _pageController.dispose();
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _organizationCtrl.dispose();
    _fiscalIdCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  InputDecoration _decoration({
    required String label,
    required IconData icon,
    String? hint,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon),
      suffixIcon: suffixIcon,
    );
  }

  void _nextPage() {
    FocusScope.of(context).unfocus();

    if (_currentPage < _totalPages - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeInOut,
      );
    }
  }

  void _prevPage() {
    FocusScope.of(context).unfocus();

    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeInOut,
      );
    }
  }

  bool _validateCurrentStep() {
    switch (_currentPage) {
      case 0:
        if (_firstNameCtrl.text.trim().isEmpty) {
          _setError('First name is required');
          return false;
        }
        if (_lastNameCtrl.text.trim().isEmpty) {
          _setError('Last name is required');
          return false;
        }
        break;

      case 1:
        final fiscalId = _fiscalIdCtrl.text.trim().toUpperCase();
        if (_fiscalIdCtrl.text.trim().isEmpty) {
          _setError('Fiscal ID is required');
          return false;
        }
        if (!RegExp(r'^[0-9]{7}[A-Z]{3}[0-9]{3}$').hasMatch(fiscalId)) {
          _setError('Fiscal ID must match 1234567ABC123');
          return false;
        }
        break;

      case 2:
        final email = _emailCtrl.text.trim();
        if (email.isEmpty) {
          _setError('Email is required');
          return false;
        }
        if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(email)) {
          _setError('Enter a valid email');
          return false;
        }
        break;

      case 3:
        final password = _passwordCtrl.text;
        final confirm = _confirmPasswordCtrl.text;

        if (password.isEmpty) {
          _setError('Password is required');
          return false;
        }
        if (password.length < 6) {
          _setError('Password must be at least 6 characters');
          return false;
        }
        if (confirm.isEmpty) {
          _setError('Please confirm your password');
          return false;
        }
        if (password != confirm) {
          _setError('Passwords do not match');
          return false;
        }
        break;
    }

    setState(() => _error = null);
    return true;
  }

  void _setError(String message) {
    setState(() {
      _error = message;
    });
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    if (!_validateCurrentStep()) return;

    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await _authService.signup(
        firstName: _firstNameCtrl.text.trim(),
        lastName: _lastNameCtrl.text.trim(),
        organizationName: _organizationCtrl.text.trim(),
        fiscalId: _fiscalIdCtrl.text.trim().toUpperCase(),
        email: _emailCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        password: _passwordCtrl.text,
        confirmPassword: _confirmPasswordCtrl.text,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Account created successfully'),
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Widget _dot(int index, ThemeData theme) {
    final bool active = index == _currentPage;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      height: 8,
      width: active ? 20 : 8,
      decoration: BoxDecoration(
        color: active ? AppTheme.mint : theme.colorScheme.outlineVariant,
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }

  Widget _stepHeader({
    required ThemeData theme,
    required String title,
    required String subtitle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: theme.textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text(subtitle, style: theme.textTheme.bodySmall),
      ],
    );
  }

  Widget _stepCard({
    required List<Widget> children,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: children,
        ),
      ),
    );
  }

  Widget _buildStep0(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stepHeader(
          theme: theme,
          title: 'Who are you?',
          subtitle: 'Start with your personal information.',
        ),
        const SizedBox(height: 18),
        _stepCard(
          children: [
            TextFormField(
              controller: _firstNameCtrl,
              textInputAction: TextInputAction.next,
              decoration: _decoration(
                label: 'Prénom',
                icon: Icons.person_outline,
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Prénom is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _lastNameCtrl,
              textInputAction: TextInputAction.done,
              decoration: _decoration(
                label: 'Nom',
                icon: Icons.badge_outlined,
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Nom is required';
                }
                return null;
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStep1(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stepHeader(
          theme: theme,
          title: 'Company details',
          subtitle: 'Add your organization and fiscal information.',
        ),
        const SizedBox(height: 18),
        _stepCard(
          children: [
            TextFormField(
              controller: _organizationCtrl,
              textInputAction: TextInputAction.next,
              decoration: _decoration(
                label: "Nom de l'Organisation",
                icon: Icons.business_outlined,
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _fiscalIdCtrl,
              textCapitalization: TextCapitalization.characters,
              textInputAction: TextInputAction.done,
              decoration: _decoration(
                label: 'Matricule Fiscale*',
                hint: '1234567ABC123',
                icon: Icons.confirmation_number_outlined,
              ),
              validator: (value) {
                final v = value?.trim().toUpperCase() ?? '';
                if (v.isEmpty) return 'Fiscal ID is required';
                if (!RegExp(r'^[0-9]{7}[A-Z]{3}[0-9]{3}$').hasMatch(v)) {
                  return 'Format: 1234567ABC123';
                }
                return null;
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStep2(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stepHeader(
          theme: theme,
          title: 'Contact information',
          subtitle: 'How can we reach you?',
        ),
        const SizedBox(height: 18),
        _stepCard(
          children: [
            TextFormField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              decoration: _decoration(
                label: 'Adresse Email',
                hint: 'name@example.com',
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
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.done,
              decoration: _decoration(
                label: 'Numéro de Téléphone',
                hint: '+216 XX XXX XXX',
                icon: Icons.phone_outlined,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStep3(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stepHeader(
          theme: theme,
          title: 'Secure your account',
          subtitle: 'Choose a strong password.',
        ),
        const SizedBox(height: 18),
        _stepCard(
          children: [
            TextFormField(
              controller: _passwordCtrl,
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.next,
              decoration: _decoration(
                label: 'Mot de Passe',
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
            const SizedBox(height: 14),
            TextFormField(
              controller: _confirmPasswordCtrl,
              obscureText: _obscureConfirmPassword,
              textInputAction: TextInputAction.done,
              decoration: _decoration(
                label: 'Confirmer le Mot de Passe',
                icon: Icons.lock_reset_outlined,
                suffixIcon: IconButton(
                  onPressed: () {
                    setState(() {
                      _obscureConfirmPassword = !_obscureConfirmPassword;
                    });
                  },
                  icon: Icon(
                    _obscureConfirmPassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                  ),
                ),
              ),
              validator: (value) {
                final v = value ?? '';
                if (v.isEmpty) return 'Please confirm password';
                if (v != _passwordCtrl.text) return 'Passwords do not match';
                return null;
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStep4(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stepHeader(
          theme: theme,
          title: 'Review & create',
          subtitle: 'Make sure everything looks good before creating the account.',
        ),
        const SizedBox(height: 18),
        _stepCard(
          children: [
            _reviewRow('Prénom', _firstNameCtrl.text),
            _reviewRow('Nom', _lastNameCtrl.text),
            _reviewRow("Organisation", _organizationCtrl.text.isEmpty ? '-' : _organizationCtrl.text),
            _reviewRow('Matricule Fiscale', _fiscalIdCtrl.text.toUpperCase()),
            _reviewRow('Email', _emailCtrl.text),
            _reviewRow('Téléphone', _phoneCtrl.text.isEmpty ? '-' : _phoneCtrl.text),
          ],
        ),
      ],
    );
  }

  Widget _reviewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 6,
            child: Text(value),
          ),
        ],
      ),
    );
  }

  void _continueAction() {
    if (!_validateCurrentStep()) return;
    _nextPage();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create account'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 8),
            Container(
              height: 72,
              width: 72,
              decoration: BoxDecoration(
                color: AppTheme.mintSoft.withOpacity(isDark ? 0.15 : 1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.person_add_alt_1_outlined,
                color: AppTheme.mint,
                size: 34,
              ),
            ),
            const SizedBox(height: 16),

            Expanded(
              child: Form(
                key: _formKey,
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (index) {
                    setState(() {
                      _currentPage = index;
                      _error = null;
                    });
                  },
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(22, 8, 22, 0),
                      child: _buildStep0(theme),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(22, 8, 22, 0),
                      child: _buildStep1(theme),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(22, 8, 22, 0),
                      child: _buildStep2(theme),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(22, 8, 22, 0),
                      child: _buildStep3(theme),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(22, 8, 22, 0),
                      child: _buildStep4(theme),
                    ),
                  ],
                ),
              ),
            ),

            if (_error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 0, 22, 10),
                child: Container(
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
              ),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _totalPages,
                (index) => _dot(index, theme),
              ),
            ),

            const SizedBox(height: 16),

            Padding(
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 22),
              child: Row(
                children: [
                  if (_currentPage > 0)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _loading ? null : _prevPage,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text('Back'),
                      ),
                    ),
                  if (_currentPage > 0) const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _loading
                          ? null
                          : (_currentPage == _totalPages - 1
                              ? _submit
                              : _continueAction),
                      child: _loading
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              _currentPage == _totalPages - 1
                                  ? 'Create account'
                                  : 'Continue',
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}