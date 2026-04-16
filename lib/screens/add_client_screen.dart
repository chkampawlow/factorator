import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:my_app/l10n/app_localizations.dart';
import 'package:my_app/storage/clients_repo.dart';
import 'package:my_app/widgets/app_alerts.dart';

class AddClientScreen extends StatefulWidget {
  final Map<String, dynamic>? client;
  final String? prefilledId;
  final String? prefilledName;
  final String? prefilledCin;
  final String? prefilledFiscalId;

  const AddClientScreen({
    super.key,
    this.client,
    this.prefilledId,
    this.prefilledName,
    this.prefilledCin,
    this.prefilledFiscalId,
  });

  @override
  State<AddClientScreen> createState() => _AddClientScreenState();
}

class _AddClientScreenState extends State<AddClientScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _repo = ClientsRepo();

  late String _type; // company | individual

  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phoneCode = TextEditingController(text: '+216');
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _fiscalId = TextEditingController();
  final _cin = TextEditingController();

  bool _loading = false;

  late final AnimationController _animController;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  int get _clientId {
    final raw = widget.client?['id'];
    if (raw is int) return raw;
    return int.tryParse(raw?.toString() ?? '') ?? 0;
  }

  bool get isEdit => widget.client != null;

  bool _looksLikeFiscalId(String value) {
    final v = value.trim().toUpperCase();
    if (v.isEmpty) return false;

    return RegExp(r'^[0-9]{7}[A-Z]$').hasMatch(v);
  }

  bool _looksLikeCin(String value) {
    final v = value.trim();
    return RegExp(r'^[0-9]{6,12}$').hasMatch(v);
  }

  @override
  void initState() {
    super.initState();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fade =
        CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );

    final c = widget.client;
    _type = (c?['type']?.toString() ?? 'individual');

    _name.text = (c?['name'] ?? '').toString();
    _email.text = (c?['email'] ?? '').toString();

    final rawPhone = (c?['phone'] ?? '').toString().trim();
    if (rawPhone.isNotEmpty) {
      final compact = rawPhone.replaceAll(RegExp(r'\s+'), '');
      // Accept: +21612345678, 21612345678, +216 12345678, 12345678
      final m = RegExp(r'^\+?(\d{1,3})(\d{6,12})$').firstMatch(compact);
      if (m != null) {
        _phoneCode.text = '+${m.group(1)}';
        _phone.text = m.group(2) ?? '';
      } else {
        // fallback: keep digits only in local field
        _phone.text = compact.replaceAll(RegExp(r'\D'), '');
      }
    }

    _address.text = (c?['address'] ?? '').toString();
    _fiscalId.text = (c?['fiscalId'] ?? c?['fiscal_id'] ?? '').toString();
    _cin.text = (c?['cin'] ?? '').toString();

    // Apply direct prefills (create only)
    if (widget.client == null) {
      final name = (widget.prefilledName ?? '').trim();
      final cin = (widget.prefilledCin ?? '').trim();
      final mf = (widget.prefilledFiscalId ?? '').trim();

      if (name.isNotEmpty) {
        _name.text = name;
      }

      if (cin.isNotEmpty) {
        _type = 'individual';
        _cin.text = cin;
      }

      if (mf.isNotEmpty) {
        _type = 'company';
        _fiscalId.text = mf.toUpperCase();
      }
    }

    if (widget.prefilledId != null &&
        widget.client == null &&
        _cin.text.trim().isEmpty &&
        _fiscalId.text.trim().isEmpty &&
        _name.text.trim().isEmpty) {
      final value = widget.prefilledId!.trim();

      if (value.isNotEmpty) {
        if (_looksLikeFiscalId(value)) {
          _type = 'company';
          _fiscalId.text = value.toUpperCase();
          // Give a sensible default name if user didn't type one
          if (_name.text.trim().isEmpty) {
            _name.text = 'Company ${value.toUpperCase()}';
          }
        } else if (_looksLikeCin(value)) {
          _type = 'individual';
          _cin.text = value;
          // Give a sensible default name if user didn't type one
          if (_name.text.trim().isEmpty) {
            _name.text = 'Client $value';
          }
        } else {
          // Treat as a name search (requested)
          _name.text = value;
        }
      }
    }

    _animController.forward();
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phoneCode.dispose();
    _phone.dispose();
    _address.dispose();
    _fiscalId.dispose();
    _cin.dispose();
    _animController.dispose();
    super.dispose();
  }

  void _setType(String t) {
    if (_type == t) return;

    setState(() {
      _type = t;
    });

    if (t == 'company') {
      _cin.clear();
    } else {
      _fiscalId.clear();
    }
  }

  InputDecoration _dec(
    BuildContext context,
    String label, {
    IconData? icon,
    String? hint,
    String? prefixText,
  }) {
    final cs = Theme.of(context).colorScheme;

    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: icon == null ? null : Icon(icon),
      prefixText: prefixText,
      prefixStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w900,
            color: cs.onSurfaceVariant,
          ),
      filled: true,
      fillColor: cs.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: cs.outlineVariant.withOpacity(0.35)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: cs.primary, width: 1.5),
      ),
    );
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;

    FocusScope.of(context).unfocus();

    if (_loading) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    final rawName = _name.text.trim();
    final email = _email.text.trim().isEmpty ? null : _email.text.trim();

    final code =
        _phoneCode.text.trim().isEmpty ? '+216' : _phoneCode.text.trim();
    final localPhone = _phone.text.trim();
    final phone = localPhone.isEmpty ? null : '$code $localPhone';

    final address = _address.text.trim().isEmpty ? null : _address.text.trim();

    final fiscalId = _type == 'company'
        ? (_fiscalId.text.trim().isEmpty
            ? null
            : _fiscalId.text.trim().toUpperCase())
        : null;

    final cin = _type == 'individual'
        ? (_cin.text.trim().isEmpty ? null : _cin.text.trim())
        : null;

    final generatedName = _type == 'company'
        ? (fiscalId?.isNotEmpty == true ? 'Company $fiscalId' : 'Company')
        : (cin?.isNotEmpty == true ? 'Client $cin' : 'Client');

    final name = rawName.isEmpty ? generatedName : rawName;

    try {
      if (isEdit) {
        if (_clientId <= 0) {
          throw Exception('Invalid client id');
        }

        await _repo.updateClient(
          id: _clientId,
          type: _type,
          name: name,
          email: email,
          phone: phone,
          address: address,
          fiscalId: fiscalId,
          cin: cin,
        );

        if (!mounted) return;

        AppAlerts.success(context, l10n.clientAddedSuccessfully);
        Navigator.pop(context, true);
      } else {
        final result = await _repo.addClient(
          type: _type,
          name: name,
          email: email,
          phone: phone,
          address: address,
          fiscalId: fiscalId,
          cin: cin,
        );

        if (!mounted) return;

        AppAlerts.success(
          context,
          result > 0
              ? l10n.clientAddedSuccessfullyWithId(result.toString())
              : l10n.clientAddedSuccessfully,
        );

        Navigator.pop(context, true);
      }
    } catch (e) {
      if (!mounted) return;
      AppAlerts.error(
        context,
        '${l10n.saveFailed}: ${e.toString().replaceFirst('Exception: ', '')}',
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _typeSwitch(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    final isCompany = _type == 'company';

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.35)),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => _setType('individual'),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                decoration: BoxDecoration(
                  color: !isCompany ? cs.primaryContainer : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.credit_card,
                      size: 18,
                      color: !isCompany
                          ? cs.onPrimaryContainer
                          : cs.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        l10n.cin,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: !isCompany
                              ? cs.onPrimaryContainer
                              : cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: GestureDetector(
              onTap: () => _setType('company'),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                decoration: BoxDecoration(
                  color: isCompany ? cs.primaryContainer : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.business,
                      size: 18,
                      color: isCompany
                          ? cs.onPrimaryContainer
                          : cs.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        l10n.fiscalIdMf,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: isCompany
                              ? cs.onPrimaryContainer
                              : cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context)!;
    final isCompany = _type == 'company';

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? l10n.editCustomer : l10n.addCustomer),
      ),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fade,
          child: SlideTransition(
            position: _slide,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - 16,
                    ),
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => FocusScope.of(context).unfocus(),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    cs.primaryContainer.withOpacity(0.45),
                                    cs.surface,
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(22),
                                border: Border.all(
                                  color: cs.outlineVariant.withOpacity(0.25),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    height: 44,
                                    width: 44,
                                    decoration: BoxDecoration(
                                      color: cs.surface.withOpacity(0.7),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: cs.outlineVariant.withOpacity(
                                          0.18,
                                        ),
                                      ),
                                    ),
                                    child: Icon(
                                      isCompany
                                          ? Icons.business_outlined
                                          : Icons.person_outline,
                                      color: cs.primary,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          isEdit
                                              ? l10n.editCustomer
                                              : l10n.addCustomer,
                                          style: t.titleLarge?.copyWith(
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          isCompany
                                              ? l10n.companyName
                                              : l10n.fullName,
                                          style: t.bodyMedium?.copyWith(
                                            color: cs.onSurfaceVariant,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(22),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(
                                  sigmaX: 12,
                                  sigmaY: 12,
                                ),
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: cs.surfaceContainerHighest
                                        .withOpacity(0.55),
                                    borderRadius: BorderRadius.circular(22),
                                    border: Border.all(
                                      color:
                                          cs.outlineVariant.withOpacity(0.28),
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      _typeSwitch(context),
                                      const SizedBox(height: 12),
                                      TextFormField(
                                        controller: _name,
                                        textCapitalization: isCompany
                                            ? TextCapitalization.words
                                            : TextCapitalization.characters,
                                        inputFormatters: isCompany
                                            ? null
                                            : <TextInputFormatter>[
                                                UpperCaseTextFormatter()
                                              ],
                                        decoration: _dec(
                                          context,
                                          isCompany
                                              ? l10n.companyName
                                              : l10n.fullName.toUpperCase(),
                                          icon: isCompany
                                              ? Icons.business_outlined
                                              : Icons.person_outline,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      AnimatedSwitcher(
                                        duration:
                                            const Duration(milliseconds: 280),
                                        switchInCurve: Curves.easeOutCubic,
                                        switchOutCurve: Curves.easeInCubic,
                                        transitionBuilder: (child, anim) {
                                          final slide = Tween<Offset>(
                                            begin: isCompany
                                                ? const Offset(0.22, 0)
                                                : const Offset(-0.22, 0),
                                            end: Offset.zero,
                                          ).animate(anim);

                                          return FadeTransition(
                                            opacity: anim,
                                            child: SlideTransition(
                                              position: slide,
                                              child: child,
                                            ),
                                          );
                                        },
                                        child: isCompany
                                            ? TextFormField(
                                                key: const ValueKey('MF'),
                                                controller: _fiscalId,
                                                textCapitalization:
                                                    TextCapitalization
                                                        .characters,
                                                inputFormatters: [
                                                  LengthLimitingTextInputFormatter(
                                                    8,
                                                  ),
                                                  FilteringTextInputFormatter
                                                      .allow(
                                                    RegExp(r'[0-9a-zA-Z]'),
                                                  ),
                                                  TextInputFormatter
                                                      .withFunction(
                                                    (oldValue, newValue) {
                                                      return newValue.copyWith(
                                                        text: newValue.text
                                                            .toUpperCase(),
                                                        selection:
                                                            newValue.selection,
                                                      );
                                                    },
                                                  ),
                                                ],
                                                decoration: _dec(
                                                  context,
                                                  l10n.fiscalIdMf,
                                                  icon: Icons.badge_outlined,
                                                  hint: l10n.fiscalIdFormat,
                                                ),
                                                validator: (v) {
                                                  if (_type != 'company') {
                                                    return null;
                                                  }
                                                  if (v == null ||
                                                      v.trim().isEmpty) {
                                                    return l10n.mfRequired;
                                                  }
                                                  if (!_looksLikeFiscalId(v)) {
                                                    return l10n.invalidFiscalId;
                                                  }
                                                  return null;
                                                },
                                              )
                                            : TextFormField(
                                                key: const ValueKey('CIN'),
                                                controller: _cin,
                                                decoration: _dec(
                                                  context,
                                                  l10n.cin,
                                                  icon: Icons
                                                      .credit_card_outlined,
                                                ),
                                                keyboardType:
                                                    TextInputType.number,
                                                validator: (v) {
                                                  if (_type != 'individual') {
                                                    return null;
                                                  }
                                                  if (v == null ||
                                                      v.trim().isEmpty) {
                                                    return l10n.cinRequired;
                                                  }
                                                  if (v.trim().length < 6) {
                                                    return l10n.cinTooShort;
                                                  }
                                                  return null;
                                                },
                                              ),
                                      ),
                                      const SizedBox(height: 12),
                                      TextFormField(
                                        controller: _email,
                                        decoration: _dec(
                                          context,
                                          l10n.emailOptional,
                                          icon: Icons.email_outlined,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Row(
                                        children: [
                                          SizedBox(
                                            width: 110,
                                            child: TextFormField(
                                              controller: _phoneCode,
                                              keyboardType: TextInputType.phone,
                                              inputFormatters: <TextInputFormatter>[
                                                FilteringTextInputFormatter
                                                    .allow(RegExp(r'[+0-9]')),
                                                LengthLimitingTextInputFormatter(
                                                    4),
                                              ],
                                              decoration: _dec(
                                                context,
                                                l10n.code,
                                                icon: Icons.public_rounded,
                                              ),
                                              validator: (v) {
                                                final s = (v ?? '').trim();
                                                if (s.isEmpty)
                                                  return null; // empty => default +216
                                                if (!RegExp(r'^\+\d{1,3}$')
                                                    .hasMatch(s)) {
                                                  return l10n
                                                      .invalidPhoneNumber;
                                                }
                                                return null;
                                              },
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: TextFormField(
                                              controller: _phone,
                                              keyboardType: TextInputType.phone,
                                              inputFormatters: <TextInputFormatter>[
                                                FilteringTextInputFormatter
                                                    .digitsOnly,
                                                LengthLimitingTextInputFormatter(
                                                    12),
                                              ],
                                              decoration: _dec(
                                                context,
                                                l10n.phoneOptional,
                                                icon: Icons.phone_outlined,
                                              ),
                                              validator: (v) {
                                                final s = (v ?? '').trim();
                                                if (s.isEmpty) return null;

                                                final code =
                                                    _phoneCode.text.trim();
                                                // Tunisia default: exactly 8 digits when +216 or empty
                                                if (code.isEmpty ||
                                                    code == '+216') {
                                                  if (s.length != 8)
                                                    return l10n
                                                        .invalidPhoneNumber;
                                                } else {
                                                  // Generic: 6..12 digits
                                                  if (s.length < 6 ||
                                                      s.length > 12)
                                                    return l10n
                                                        .invalidPhoneNumber;
                                                }
                                                return null;
                                              },
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      TextFormField(
                                        controller: _address,
                                        decoration: _dec(
                                          context,
                                          l10n.addressOptional,
                                          icon: Icons.location_on_outlined,
                                        ),
                                        maxLines: 2,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: _loading
                                        ? null
                                        : () => Navigator.pop(context),
                                    child: Text(l10n.cancelButton),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  flex: 2,
                                  child: FilledButton(
                                    onPressed: _loading ? null : _save,
                                    child: _loading
                                        ? SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(
                                                cs.onPrimary,
                                              ),
                                            ),
                                          )
                                        : Text(
                                            isEdit
                                                ? l10n.saveChanges
                                                : l10n.saveCustomer,
                                          ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final upper = newValue.text.toUpperCase();
    return newValue.copyWith(
      text: upper,
      selection: newValue.selection,
      composing: TextRange.empty,
    );
  }
}
