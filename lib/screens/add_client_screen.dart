import 'package:flutter/material.dart';
import 'package:my_app/storage/clients_repo.dart';
import '../widgets/primary_button.dart';

class AddClientScreen extends StatefulWidget {
  final Map<String, dynamic>? client;
  const AddClientScreen({super.key, this.client});

  @override
  State<AddClientScreen> createState() => _AddClientScreenState();
}

class _AddClientScreenState extends State<AddClientScreen> {
  final _formKey = GlobalKey<FormState>();
final _repo = ClientsRepo();
  late String _type; // 'company' | 'individual'

  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _fiscalId = TextEditingController();
  final _cin = TextEditingController();

  bool _loading = false;
  bool get isEdit => widget.client != null;

  @override
  void initState() {
    super.initState();

    final c = widget.client;
    _type = (c?['type']?.toString() ?? 'individual');

    _name.text = (c?['name'] ?? '').toString();
    _email.text = (c?['email'] ?? '').toString();
    _phone.text = (c?['phone'] ?? '').toString();
    _address.text = (c?['address'] ?? '').toString();
    _fiscalId.text = (c?['fiscalId'] ?? '').toString();
    _cin.text = (c?['cin'] ?? '').toString();
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
    setState(() => _type = t);

    if (t == 'company') {
      _cin.clear();
    } else {
      _fiscalId.clear();
    }
  }
Future<void> _save() async {
  FocusScope.of(context).unfocus();

  if (!_formKey.currentState!.validate()) return;
  setState(() => _loading = true);

  final name = _name.text.trim();
  final email = _email.text.trim().isEmpty ? null : _email.text.trim();
  final phone = _phone.text.trim().isEmpty ? null : _phone.text.trim();
  final address = _address.text.trim().isEmpty ? null : _address.text.trim();

  final fiscalId = _type == 'company'
      ? (_fiscalId.text.trim().isEmpty ? null : _fiscalId.text.trim())
      : null;

  final cin = _type == 'individual'
      ? (_cin.text.trim().isEmpty ? null : _cin.text.trim())
      : null;

  try {
    if (isEdit) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Client update API not added yet.")),
      );
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

      print("API RESULT => $result");

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result > 0
                ? "Client added successfully with ID: $result"
                : "Client added successfully",
          ),
        ),
      );
      Navigator.pop(context, true);
    }
  } catch (e) {
    print("SAVE CLIENT ERROR => $e");

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Save failed: $e")),
    );
  } finally {
    if (mounted) {
      setState(() => _loading = false);
    }
  }
}
  Widget _pill(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;

    final isCompany = _type == 'company';

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, anim) {
        final slide = Tween<Offset>(
          begin: isCompany ? const Offset(0.22, 0) : const Offset(-0.22, 0),
          end: Offset.zero,
        ).animate(anim);

        return FadeTransition(
          opacity: anim,
          child: SlideTransition(position: slide, child: child),
        );
      },
      child: Container(
        key: ValueKey(_type),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withOpacity(.55),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: cs.outlineVariant.withOpacity(.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isCompany ? Icons.business_outlined : Icons.person_outline,
              size: 18,
              color: cs.primary,
            ),
            const SizedBox(width: 10),
            Text(
              isCompany ? "Matricule Fiscal (MF)" : "CIN",
              style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(width: 10),
            Icon(
              Icons.swap_horiz,
              size: 18,
              color: cs.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isCompany = _type == 'company';

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? "Edit Customer" : "Add Customer"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragEnd: (details) {
            final v = details.primaryVelocity ?? 0;
            if (v < -150) _setType('individual');
            if (v > 150) _setType('company');
          },
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: _pill(context),
                ),
                const SizedBox(height: 14),
                _premiumCard(
                  context,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _name,
                        decoration: _dec(
                          context,
                          isCompany ? "Company name" : "Full name",
                          icon: isCompany
                              ? Icons.business_outlined
                              : Icons.person_outline,
                        ),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? "Required" : null,
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
                                key: const ValueKey("MF"),
                                controller: _fiscalId,
                                decoration: _dec(
                                  context,
                                  "Matricule Fiscal (MF)",
                                  icon: Icons.badge_outlined,
                                ),
                                validator: (v) {
                                  if (_type != 'company') return null;
                                  if (v == null || v.trim().isEmpty) {
                                    return "MF required";
                                  }
                                  return null;
                                },
                              )
                            : TextFormField(
                                key: const ValueKey("CIN"),
                                controller: _cin,
                                decoration: _dec(
                                  context,
                                  "CIN",
                                  icon: Icons.credit_card_outlined,
                                ),
                                keyboardType: TextInputType.number,
                                validator: (v) {
                                  if (_type != 'individual') return null;
                                  if (v == null || v.trim().isEmpty) {
                                    return "CIN required";
                                  }
                                  if (v.trim().length < 6) {
                                    return "CIN looks too short";
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
                          "Email (optional)",
                          icon: Icons.email_outlined,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _phone,
                        decoration: _dec(
                          context,
                          "Phone (optional)",
                          icon: Icons.phone_outlined,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _address,
                        decoration: _dec(
                          context,
                          "Address (optional)",
                          icon: Icons.location_on_outlined,
                        ),
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 90),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            border: Border(
              top: BorderSide(color: cs.outlineVariant.withOpacity(.25)),
            ),
          ),
          child: PrimaryButton(
            text: isEdit ? "Save Changes" : "Save Customer",
            loading: _loading,
            onTap: _save,
          ),
        ),
      ),
    );
  }
}