import 'package:flutter/material.dart';
import 'package:my_app/l10n/app_localizations.dart';
import 'package:my_app/services/auth_service.dart';
import 'package:my_app/services/location_service.dart';
import 'package:my_app/widgets/app_alerts.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final PageController _pageController = PageController();
  final AuthService _authService = AuthService();
  final LocationService _locationService = LocationService();

  final _formKey = GlobalKey<FormState>();

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

  String _phonePrefix = '+216';

  final int _totalPages = 4;

  @override
  void initState() {
    super.initState();
    _loadPhonePrefixFromRegion();
  }

  Future<void> _loadPhonePrefixFromRegion() async {
    try {
      final address = await _locationService.getCurrentAddress();
      final prefix = _detectPhonePrefix(address);

      if (!mounted) return;

      setState(() {
        _phonePrefix = prefix;
      });

      if (_phoneCtrl.text.trim().isEmpty) {
        _phoneCtrl.text = '$prefix ';
      }
    } catch (_) {
      if (_phoneCtrl.text.trim().isEmpty) {
        _phoneCtrl.text = '$_phonePrefix ';
      }
    }
  }

  String _detectPhonePrefix(String address) {
    final lower = address.toLowerCase();

    if (lower.contains('tunisia') || lower.contains('tunisie')) return '+216';
    if (lower.contains('france')) return '+33';
    if (lower.contains('algeria') || lower.contains('algérie')) return '+213';
    if (lower.contains('morocco') || lower.contains('maroc')) return '+212';
    if (lower.contains('libya') || lower.contains('libye')) return '+218';
    if (lower.contains('egypt') || lower.contains('égypte')) return '+20';
    if (lower.contains('saudi')) return '+966';
    if (lower.contains('uae')) return '+971';

    return '+216';
  }

  @override
  void dispose() {
    _pageController.dispose();
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
    final l10n = AppLocalizations.of(context)!;

    switch (_currentPage) {
      case 0:
        final fiscalId = _fiscalIdCtrl.text.trim().toUpperCase();
        if (fiscalId.isEmpty) {
          _setError(l10n.fiscalIdRequired);
          return false;
        }
        if (!RegExp(r'^[0-9]{7}[A-Z]{3}[0-9]{3}$').hasMatch(fiscalId)) {
          _setError(l10n.invalidFiscalId);
          return false;
        }
        break;

      case 1:
        final email = _emailCtrl.text.trim();
        final phone = _phoneCtrl.text.trim();
        if (email.isEmpty) {
          _setError(l10n.emailRequired);
          return false;
        }
        if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(email)) {
          _setError(l10n.enterValidEmail);
          return false;
        }
        if (phone.isEmpty || phone == _phonePrefix || phone == '$_phonePrefix ') {
          _setError(l10n.phoneNumberRequired);
          return false;
        }
        if (!RegExp(r'^\+\d{1,3}\s\d{6,12}$').hasMatch(phone)) {
          _setError(l10n.phoneNumberInvalid);
          return false;
        }
        break;

      case 2:
        final password = _passwordCtrl.text;
        final confirm = _confirmPasswordCtrl.text;

        if (password.isEmpty) {
          _setError(l10n.passwordRequired);
          return false;
        }
        if (password.length < 6) {
          _setError(l10n.passwordMinLength);
          return false;
        }
        if (confirm.isEmpty) {
          _setError(l10n.pleaseConfirmPassword);
          return false;
        }
        if (password != confirm) {
          _setError(l10n.passwordsDoNotMatch);
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
    final l10n = AppLocalizations.of(context)!;

    FocusScope.of(context).unfocus();

    if (!_validateCurrentStep()) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await _authService.signup(
        organizationName: _organizationCtrl.text.trim(),
        fiscalId: _fiscalIdCtrl.text.trim().toUpperCase(),
        email: _emailCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        password: _passwordCtrl.text,
        confirmPassword: _confirmPasswordCtrl.text,
      );

      if (!mounted) return;

      AppAlerts.success(context, l10n.accountCreatedSuccessfully);

      Navigator.pop(context);
    } catch (e) {
      final msg = e.toString().replaceFirst('Exception: ', '');
      setState(() {
        _error = msg;
      });
      if (mounted) {
        AppAlerts.error(context, msg);
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Widget _dot(int index, ThemeData theme) {
    final active = index == _currentPage;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      height: 8,
      width: active ? 20 : 8,
      decoration: BoxDecoration(
        color: active ? theme.colorScheme.primary : theme.colorScheme.outlineVariant,
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
    final l10n = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stepHeader(
          theme: theme,
          title: l10n.companyDetails,
          subtitle: l10n.addOrganizationAndFiscalInfo,
        ),
        const SizedBox(height: 18),
        _stepCard(
          children: [
            TextFormField(
              controller: _organizationCtrl,
              textInputAction: TextInputAction.next,
              decoration: _decoration(
                label: l10n.organizationName,
                icon: Icons.business_outlined,
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _fiscalIdCtrl,
              textCapitalization: TextCapitalization.characters,
              textInputAction: TextInputAction.done,
              decoration: _decoration(
                label: l10n.fiscalIdRequiredLabel,
                hint: '**************',
                icon: Icons.confirmation_number_outlined,
              ),
              validator: (value) {
                final v = value?.trim().toUpperCase() ?? '';
                if (v.isEmpty) return l10n.fiscalIdRequired;
                if (!RegExp(r'^[0-9]{7}[A-Z]{3}[0-9]{3}$').hasMatch(v)) {
                  return l10n.invalidFiscalId;
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
    final l10n = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stepHeader(
          theme: theme,
          title: l10n.contactInformation,
          subtitle: l10n.howCanWeReachYou,
        ),
        const SizedBox(height: 18),
        _stepCard(
          children: [
            TextFormField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              decoration: _decoration(
                label: l10n.emailAddressLabel,
                hint: 'name@example.com',
                icon: Icons.mail_outline_rounded,
              ),
              validator: (value) {
                final v = value?.trim() ?? '';
                if (v.isEmpty) return l10n.emailRequired;
                if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(v)) {
                  return l10n.enterValidEmail;
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
                label: l10n.phoneNumber,
                hint: _phonePrefix,
                icon: Icons.phone_outlined,
              ),
              validator: (value) {
                final v = value?.trim() ?? '';
                if (v.isEmpty || v == _phonePrefix || v == '$_phonePrefix ') {
                  return l10n.phoneNumberRequired;
                }
                if (!RegExp(r'^\+\d{1,3}\s\d{6,12}$').hasMatch(v)) {
                  return l10n.phoneNumberInvalid;
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
    final l10n = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stepHeader(
          theme: theme,
          title: l10n.secureYourAccount,
          subtitle: l10n.chooseStrongPassword,
        ),
        const SizedBox(height: 18),
        _stepCard(
          children: [
            TextFormField(
              controller: _passwordCtrl,
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.next,
              decoration: _decoration(
                label: l10n.passwordLabel,
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
                if (v.isEmpty) return l10n.passwordRequired;
                if (v.length < 6) return l10n.minimum6Characters;
                return null;
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _confirmPasswordCtrl,
              obscureText: _obscureConfirmPassword,
              textInputAction: TextInputAction.done,
              decoration: _decoration(
                label: l10n.confirmPassword,
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
                if (v.isEmpty) return l10n.pleaseConfirmPassword;
                if (v != _passwordCtrl.text) return l10n.passwordsDoNotMatch;
                return null;
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStep3(ThemeData theme) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stepHeader(
          theme: theme,
          title: l10n.reviewAndCreate,
          subtitle: l10n.reviewBeforeCreate,
        ),
        const SizedBox(height: 18),
        _stepCard(
          children: [
            _reviewRow(
              l10n.organization,
              _organizationCtrl.text.isEmpty ? '-' : _organizationCtrl.text,
            ),
            _reviewRow(l10n.fiscalIdLabel, _fiscalIdCtrl.text.toUpperCase()),
            _reviewRow(l10n.email, _emailCtrl.text),
            _reviewRow(
              l10n.phone,
              _phoneCtrl.text.isEmpty ? '-' : _phoneCtrl.text,
            ),
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
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.createAccount),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 8),
            Container(
              height: 72,
              width: 72,
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.person_add_alt_1_outlined,
                color: cs.onPrimaryContainer,
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
                        child: Text(l10n.back),
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
                          ? SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                                color: cs.onPrimary,
                              ),
                            )
                          : Text(
                              _currentPage == _totalPages - 1
                                  ? l10n.createAccount
                                  : l10n.continueText,
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