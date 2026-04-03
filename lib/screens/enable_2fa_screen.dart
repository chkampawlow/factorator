import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:my_app/l10n/app_localizations.dart';
import 'package:my_app/services/auth_service.dart';
import 'package:qr_flutter/qr_flutter.dart';

class Enable2FAScreen extends StatefulWidget {
  const Enable2FAScreen({super.key});

  @override
  State<Enable2FAScreen> createState() => _Enable2FAScreenState();
}

class _Enable2FAScreenState extends State<Enable2FAScreen> {
  final AuthService _authService = AuthService();
  final TextEditingController _codeCtrl = TextEditingController();

  bool _loading = true;
  bool _confirming = false;
  String? _error;

  String? _qrUrl;
  String? _secret;
  bool _enabled = false;
  bool _checkingStatus = true;
  bool _disabling = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    setState(() {
      _checkingStatus = true;
      _error = null;
    });

    try {
      final enabled = await _authService.get2faStatus();

      if (!mounted) return;

      setState(() {
        _enabled = enabled;
        _checkingStatus = false;
      });

      if (!_enabled) {
        await _load2FASetup();
      } else {
        setState(() {
          _loading = false;
          _qrUrl = null;
          _secret = null;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _checkingStatus = false;
        _loading = false;
      });
    }
  }

  Future<void> _toggle2FA(bool value) async {
    if (value) {
      setState(() {
        _enabled = false;
      });
      await _load2FASetup();
      return;
    }

    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(l10n.twoFactorDisableTitle),
            content: Text(l10n.twoFactorDisableMessage),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(l10n.twoFactorDisableButton),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed || !mounted) {
      setState(() {
        _enabled = true;
      });
      return;
    }

    final code = await _askDisableCode();
    if (code == null || code.isEmpty || !mounted) {
      setState(() {
        _enabled = true;
      });
      return;
    }

    setState(() {
      _disabling = true;
      _error = null;
    });

    try {
      await _authService.disable2fa(code);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.twoFactorDisabledSuccess)),
      );

      setState(() {
        _enabled = false;
        _qrUrl = null;
        _secret = null;
      });

      await _load2FASetup();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _enabled = true;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _disabling = false;
        });
      }
    }
  }

  Future<String?> _askDisableCode() async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.twoFactorDisableCodeTitle),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          maxLength: 6,
          decoration: InputDecoration(
            labelText: l10n.twoFactorCode,
            counterText: '',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: Text(l10n.twoFactorDisableButton),
          ),
        ],
      ),
    );

    await Future<void>.delayed(const Duration(milliseconds: 250));
    controller.dispose();
    return result;
  }

  Future<void> _load2FASetup() async {
    setState(() {
      _loading = true;
      _error = null;
      _enabled = false;
    });

    try {
      final response = await _authService.enable2fa();

      if (!mounted) return;

      setState(() {
        _qrUrl = (response['qr_url'] ?? '').toString();
        _secret = (response['secret'] ?? '').toString();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _confirm2FA() async {
    final l10n = AppLocalizations.of(context)!;
    final code = _codeCtrl.text.trim();

    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.twoFactorCodeRequired)),
      );
      return;
    }

    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.twoFactorCodeInvalid)),
      );
      return;
    }

    setState(() {
      _confirming = true;
      _error = null;
    });

    try {
      await _authService.confirm2fa(code);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.twoFactorEnabledSuccess)),
      );

      setState(() {
        _enabled = true;
      });

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _confirming = false;
        });
      }
    }
  }

  Widget _buildLoading(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 14),
          Text(
            _checkingStatus
                ? l10n.twoFactorLoadingStatus
                : (_disabling ? l10n.twoFactorDisabling : l10n.twoFactorPreparing),
          ),
        ],
      ),
    );
  }

  Widget _buildError(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 42,
              color: cs.error,
            ),
            const SizedBox(height: 12),
            Text(
              _error ?? l10n.somethingWentWrong,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: cs.error,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _initialize,
              icon: const Icon(Icons.refresh),
              label: Text(l10n.retry),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPremiumQrCard(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            cs.primaryContainer.withOpacity(0.9),
            cs.surface,
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: cs.outlineVariant.withOpacity(0.28),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: _qrUrl == null || _qrUrl!.isEmpty
                  ? Text(
                      l10n.twoFactorQrUnavailable,
                      textAlign: TextAlign.center,
                    )
                  : QrImageView(
                      data: _qrUrl!,
                      size: 220,
                      backgroundColor: Colors.white,
                      eyeStyle: QrEyeStyle(
                        eyeShape: QrEyeShape.square,
                        color: cs.primary,
                      ),
                      dataModuleStyle: const QrDataModuleStyle(
                        dataModuleShape: QrDataModuleShape.square,
                        color: Colors.black,
                      ),
                    ),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: cs.surface.withOpacity(0.85),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: cs.outlineVariant.withOpacity(0.25),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.twoFactorManualKey,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    (_secret == null || _secret!.isEmpty)
                        ? l10n.twoFactorManualKeyUnavailable
                        : _secret!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: OutlinedButton.icon(
                      onPressed: (_secret == null || _secret!.isEmpty)
                          ? null
                          : () async {
                              await Clipboard.setData(
                                ClipboardData(text: _secret!),
                              );
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(l10n.twoFactorManualKeyCopied),
                                ),
                              );
                            },
                      icon: const Icon(Icons.copy_rounded),
                      label: Text(l10n.copy),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.twoFactorSetupTitle),
      ),
      body: (_loading || _checkingStatus || _disabling)
          ? _buildLoading(context)
          : _error != null && (_qrUrl == null || _qrUrl!.isEmpty)
              ? _buildError(context)
              : SafeArea(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 22,
                        vertical: 18,
                      ),
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
                                  color: cs.primaryContainer,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.shield_outlined,
                                  size: 34,
                                  color: cs.onPrimaryContainer,
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              l10n.twoFactorSetupTitle,
                              style: theme.textTheme.headlineSmall,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              l10n.twoFactorSetupSubtitle,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 22),
                            Card(
                              child: ListTile(
                                leading: Icon(
                                  _enabled
                                      ? Icons.verified_user_rounded
                                      : Icons.shield_outlined,
                                ),
                                title: Text(l10n.twoFactorToggleTitle),
                                subtitle: Text(
                                  _enabled
                                      ? l10n.twoFactorToggleOn
                                      : l10n.twoFactorToggleOff,
                                ),
                                trailing: _enabled
                                    ? FilledButton(
                                        onPressed: (_loading || _confirming || _disabling)
                                            ? null
                                            : () => _toggle2FA(false),
                                        child: Text(l10n.twoFactorDisableButton),
                                      )
                                    : null,
                              ),
                            ),
                            const SizedBox(height: 16),
                            if (!_enabled) Card(
                              child: Padding(
                                padding: const EdgeInsets.all(18),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      l10n.twoFactorStep1,
                                      style: theme.textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      l10n.twoFactorScanQr,
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        color: cs.onSurfaceVariant,
                                      ),
                                    ),
                                    const SizedBox(height: 18),
                                    _buildPremiumQrCard(context),
                                  ],
                                ),
                              ),
                            ),
                            if (!_enabled) ...[
                              const SizedBox(height: 16),
                              Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(18),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        l10n.twoFactorStep2,
                                        style: theme.textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        l10n.twoFactorEnterSetupCode,
                                        style: theme.textTheme.bodyMedium?.copyWith(
                                          color: cs.onSurfaceVariant,
                                        ),
                                      ),
                                      const SizedBox(height: 14),
                                      TextField(
                                        controller: _codeCtrl,
                                        keyboardType: TextInputType.number,
                                        maxLength: 6,
                                        decoration: InputDecoration(
                                          labelText: l10n.twoFactorCode,
                                          prefixIcon: const Icon(Icons.numbers_rounded),
                                          border: const OutlineInputBorder(),
                                          counterText: '',
                                        ),
                                      ),
                                      if (_error != null) ...[
                                        const SizedBox(height: 12),
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
                                          onPressed: _confirming ? null : _confirm2FA,
                                          child: _confirming
                                              ? const SizedBox(
                                                  height: 22,
                                                  width: 22,
                                                  child: CircularProgressIndicator(
                                                    strokeWidth: 2.4,
                                                    color: Colors.white,
                                                  ),
                                                )
                                              : Text(l10n.twoFactorEnableButton),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
    );
  }
}
