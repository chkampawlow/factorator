import 'package:flutter/material.dart';
import 'package:my_app/l10n/app_localizations.dart';
import 'package:my_app/storage/clients_repo.dart';

class AddClientScreen extends StatefulWidget {
  final Map<String, dynamic>? client;
  final String? prefilledId;

  const AddClientScreen({
    super.key,
    this.client,
    this.prefilledId,
  });

  @override
  State<AddClientScreen> createState() => _AddClientScreenState();
}

class _AddClientScreenState extends State<AddClientScreen> {
  final _formKey = GlobalKey<FormState>();
  final _repo = ClientsRepo();

  late String _type; // company | individual

  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _fiscalId = TextEditingController();
  final _cin = TextEditingController();

  bool _loading = false;

  int get _clientId {
    final raw = widget.client?['id'];
    if (raw is int) return raw;
    return int.tryParse(raw?.toString() ?? '') ?? 0;
  }
  bool get isEdit => widget.client != null;

  bool _looksLikeFiscalId(String value) {
    final v = value.trim().toUpperCase();

    if (v.startsWith('TN')) return true;
    if (RegExp(r'^[0-9]{7}[A-Z]{3}[0-9]{3}$').hasMatch(v)) return true;

    return false;
  }

  bool _looksLikeCin(String value) {
    final v = value.trim();
    return RegExp(r'^[0-9]{6,12}$').hasMatch(v);
  }

  @override
  void initState() {
    super.initState();

    final c = widget.client;
    _type = (c?['type']?.toString() ?? 'individual');

    _name.text = (c?['name'] ?? '').toString();
    _email.text = (c?['email'] ?? '').toString();
    _phone.text = (c?['phone'] ?? '').toString();
    _address.text = (c?['address'] ?? '').toString();
    _fiscalId.text = (c?['fiscalId'] ?? c?['fiscal_id'] ?? '').toString();
    _cin.text = (c?['cin'] ?? '').toString();

    if (widget.prefilledId != null && widget.client == null) {
      final value = widget.prefilledId!.trim();

      if (_looksLikeFiscalId(value)) {
        _type = 'company';
        _fiscalId.text = value;
      } else if (_looksLikeCin(value)) {
        _type = 'individual';
        _cin.text = value;
      }
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _address.dispose();
    _fiscalId.dispose();
    _cin.dispose();
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

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;

    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    final rawName = _name.text.trim();
    final email = _email.text.trim().isEmpty ? null : _email.text.trim();
    final phone = _phone.text.trim().isEmpty ? null : _phone.text.trim();
    final address = _address.text.trim().isEmpty ? null : _address.text.trim();

    final fiscalId = _type == 'company'
        ? (_fiscalId.text.trim().isEmpty ? null : _fiscalId.text.trim())
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

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Client updated successfully'),
          ),
        );

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

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result > 0
                  ? l10n.clientAddedSuccessfullyWithId(result.toString())
                  : l10n.clientAddedSuccessfully,
            ),
          ),
        );

        Navigator.pop(context, true);
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${l10n.saveFailed}: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Widget _premiumCard(BuildContext context, {required Widget child}) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withOpacity(.45),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outlineVariant.withOpacity(.25)),
      ),
      child: child,
    );
  }

  InputDecoration _dec(BuildContext context, String label, {IconData? icon}) {
    final cs = Theme.of(context).colorScheme;
    return InputDecoration(
      labelText: label,
      prefixIcon: icon == null ? null : Icon(icon),
      filled: true,
      fillColor: cs.surface.withOpacity(.55),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: cs.outlineVariant.withOpacity(.25)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: cs.primary.withOpacity(.9), width: 1.4),
      ),
    );
  }

  Widget _buildSwipeHeader(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    final isCompany = _type == 'company';

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant.withOpacity(.35)),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => _setType('individual'),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                decoration: BoxDecoration(
                  color: !isCompany ? cs.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.credit_card,
                      size: 18,
                      color: !isCompany ? cs.onPrimary : cs.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        l10n.cin,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: !isCompany
                              ? cs.onPrimary
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
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                decoration: BoxDecoration(
                  color: isCompany ? cs.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.business,
                      size: 18,
                      color: isCompany ? cs.onPrimary : cs.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        l10n.fiscalIdMf,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: isCompany
                              ? cs.onPrimary
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
    final isCompany = _type == 'company';
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? l10n.editCustomer : l10n.addCustomer),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: IconButton(
              onPressed: _loading ? null : _save,
              tooltip: isEdit ? l10n.saveChanges : l10n.saveCustomer,
              icon: _loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.2),
                    )
                  : Icon(isEdit ? Icons.check : Icons.add),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              _premiumCard(
                context,
                child: Column(
                  children: [
                    _buildSwipeHeader(context),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _name,
                      decoration: _dec(
                        context,
                        isCompany ? l10n.companyName : l10n.fullName,
                        icon: isCompany
                            ? Icons.business_outlined
                            : Icons.person_outline,
                      ),
                    ),
                    const SizedBox(height: 12),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 280),
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
                          child: SlideTransition(position: slide, child: child),
                        );
                      },
                      child: isCompany
                          ? TextFormField(
                              key: const ValueKey('MF'),
                              controller: _fiscalId,
                              decoration: _dec(
                                context,
                                l10n.fiscalIdMf,
                                icon: Icons.badge_outlined,
                              ),
                              validator: (v) {
                                if (_type != 'company') return null;
                                if (v == null || v.trim().isEmpty) {
                                  return l10n.mfRequired;
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
                                icon: Icons.credit_card_outlined,
                              ),
                              keyboardType: TextInputType.number,
                              validator: (v) {
                                if (_type != 'individual') return null;
                                if (v == null || v.trim().isEmpty) {
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
                    TextFormField(
                      controller: _phone,
                      decoration: _dec(
                        context,
                        l10n.phoneOptional,
                        icon: Icons.phone_outlined,
                      ),
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
            ],
          ),
        ),
      ),
    );
  }
}