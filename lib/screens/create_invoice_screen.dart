import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:my_app/l10n/app_localizations.dart';
import 'package:my_app/storage/connections_repo.dart';
import 'package:my_app/widgets/app_alerts.dart';

import '../storage/invoices_repo.dart';
import 'invoice_edit_screen.dart';

class CreateInvoiceScreen extends StatefulWidget {
  const CreateInvoiceScreen({super.key});

  @override
  State<CreateInvoiceScreen> createState() => _CreateInvoiceScreenState();
}

class _CreateInvoiceScreenState extends State<CreateInvoiceScreen>
    with SingleTickerProviderStateMixin {
  final _connectionsRepo = ConnectionsRepo();
  final _invoicesRepo = InvoicesRepo();

  // Mode
  // - connection: store user id in custom_code
  // - manual: store name/email in custom_name/custom_email
  String _mode = 'connection'; // connection | manual

  // Connection selection
  String? _clientUserId;
  String _clientDisplay = '';
  String _clientEmail = '';

  // Manual entry
  final _manualNameCtrl = TextEditingController();
  final _manualEmailCtrl = TextEditingController();

  final DateTime _issueDate = DateTime.now();
  DateTime _dueDate = DateTime.now().add(const Duration(days: 7));

  bool _saving = false;

  String _fmtDate(DateTime d) => d.toLocal().toString().split(' ')[0];

  void _setMode(String mode) {
    if (_mode == mode) return;
    setState(() {
      _mode = mode;
      if (_mode == 'manual') {
        _clientUserId = null;
        _clientDisplay = '';
        _clientEmail = '';
      } else {
        _manualNameCtrl.clear();
        _manualEmailCtrl.clear();
      }
    });
  }

  Future<void> _pickDueDate() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      initialDate: _dueDate,
    );

    if (picked == null) return;

    setState(() {
      _dueDate = picked;
    });
  }

  Future<void> _openConnectionPicker() async {
    final l10n = AppLocalizations.of(context)!;

    try {
      final items = await _connectionsRepo.accepted();
      if (!mounted) return;

      final selected = await showModalBottomSheet<Map<String, dynamic>>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (ctx) {
          final cs = Theme.of(ctx).colorScheme;
          final t = Theme.of(ctx).textTheme;

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.chooseFromConnections,
                    style: t.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 12),
                  if (items.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 28),
                      child: Center(
                        child: Text(
                          l10n.noAcceptedConnections,
                          style: t.bodyMedium?.copyWith(
                            color: cs.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    )
                  else
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (ctx, i) {
                          final u = items[i];
                          return _ConnectionTile(
                            data: u,
                            onTap: () => Navigator.pop(ctx, u),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      );

      if (selected == null || !mounted) return;

      final id = int.tryParse((selected['other_user_id'] ?? '0').toString()) ?? 0;
      final name = (selected['other_display_name'] ?? '').toString().trim();
      final email = (selected['other_email'] ?? '').toString().trim();

      if (id <= 0) {
        AppAlerts.error(context, l10n.invalidSelection);
        return;
      }

      setState(() {
        _mode = 'connection';
        _clientUserId = id.toString();
        _clientDisplay = name.isEmpty ? '${l10n.connectedUser} #$id' : name;
        _clientEmail = email;
        _manualNameCtrl.clear();
        _manualEmailCtrl.clear();
      });
    } catch (e) {
      if (!mounted) return;
      AppAlerts.error(
        context,
        '${l10n.loadFailed}: ${e.toString().replaceFirst('Exception: ', '')}',
      );
    }
  }

  bool _manualHasAny() {
    return _manualNameCtrl.text.trim().isNotEmpty ||
        _manualEmailCtrl.text.trim().isNotEmpty;
  }

  Future<void> _saveInvoice() async {
    final l10n = AppLocalizations.of(context)!;

    if (_saving) return;

    final manualName = _manualNameCtrl.text.trim();
    final manualEmail = _manualEmailCtrl.text.trim();

    if (_mode == 'connection') {
      if (_clientUserId == null || _clientUserId!.isEmpty) {
        AppAlerts.warning(context, l10n.pleaseChooseClient);
        return;
      }
    } else {
      if (!_manualHasAny()) {
        AppAlerts.warning(context, l10n.enterClientNameOrEmail);
        return;
      }
    }

    setState(() => _saving = true);

    try {
      final invoiceId = await _invoicesRepo.createInvoiceHeader(
        clientId: 0,
        issueDate: _issueDate,
        dueDate: _dueDate,
        status: 'open',
        subtotal: 0,
        totalVat: 0,
        total: 0,
        customCode: _mode == 'connection' ? _clientUserId : null,
        customName: _mode == 'manual' ? manualName : null,
        customEmail: _mode == 'manual' ? manualEmail : null,
      );

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => InvoiceEditScreen(invoiceId: invoiceId),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      AppAlerts.error(
        context,
        '${l10n.saveFailed}: ${e.toString().replaceFirst('Exception: ', '')}',
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _modeSelector(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

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
              onTap: () => _setMode('connection'),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                decoration: BoxDecoration(
                  color: _mode == 'connection' ? cs.primaryContainer : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.people_alt_outlined,
                      size: 18,
                      color: _mode == 'connection' ? cs.onPrimaryContainer : cs.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        l10n.chooseFromConnections,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: _mode == 'connection' ? cs.onPrimaryContainer : cs.onSurfaceVariant,
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
              onTap: () => _setMode('manual'),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                decoration: BoxDecoration(
                  color: _mode == 'manual' ? cs.primaryContainer : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.edit_outlined,
                      size: 18,
                      color: _mode == 'manual' ? cs.onPrimaryContainer : cs.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        l10n.manualClient,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: _mode == 'manual' ? cs.onPrimaryContainer : cs.onSurfaceVariant,
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

  InputDecoration _dec(BuildContext context, String label, {IconData? icon}) {
    final cs = Theme.of(context).colorScheme;
    return InputDecoration(
      labelText: label,
      prefixIcon: icon == null ? null : Icon(icon),
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

  Widget _clientCard(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context)!;

    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest.withOpacity(0.55),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: cs.outlineVariant.withOpacity(0.28)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.client,
                style: t.titleMedium?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 12),
              _modeSelector(context),
              const SizedBox(height: 12),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, anim) {
                  final slide = Tween<Offset>(
                    begin: const Offset(0, 0.06),
                    end: Offset.zero,
                  ).animate(anim);
                  return FadeTransition(
                    opacity: anim,
                    child: SlideTransition(position: slide, child: child),
                  );
                },
                child: _mode == 'connection'
                    ? Column(
                        key: const ValueKey('connection'),
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: FilledButton.icon(
                              onPressed: _openConnectionPicker,
                              icon: const Icon(Icons.people_alt_outlined),
                              label: Text(l10n.chooseFromConnections),
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (_clientUserId == null)
                            Text(
                              l10n.noClientSelected,
                              style: t.bodyMedium?.copyWith(
                                color: cs.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                            )
                          else
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: cs.primaryContainer.withOpacity(0.45),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: cs.outlineVariant.withOpacity(0.22),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.verified_user_outlined, color: cs.primary),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _clientDisplay,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: t.bodyMedium?.copyWith(
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                        if (_clientEmail.isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(top: 3),
                                            child: Text(
                                              _clientEmail,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: t.bodySmall?.copyWith(
                                                color: cs.onSurfaceVariant,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: l10n.remove,
                                    onPressed: () => setState(() => _clientUserId = null),
                                    icon: const Icon(Icons.close),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      )
                    : Column(
                        key: const ValueKey('manual'),
                        children: [
                          TextField(
                            controller: _manualNameCtrl,
                            decoration: _dec(
                              context,
                              l10n.clientNameOptional,
                              icon: Icons.person_outline,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _manualEmailCtrl,
                            keyboardType: TextInputType.emailAddress,
                            decoration: _dec(
                              context,
                              l10n.clientEmailOptional,
                              icon: Icons.email_outlined,
                            ),
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

  @override
  void dispose() {
    _manualNameCtrl.dispose();
    _manualEmailCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.newInvoice)),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: _saving ? null : _saveInvoice,
              child: Text(
                _saving ? l10n.saving : l10n.createInvoice,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          padding: const EdgeInsets.only(bottom: 90),
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
                  color: cs.outlineVariant.withOpacity(isDark ? 0.28 : 0.18),
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
                        color: cs.outlineVariant.withOpacity(0.18),
                      ),
                    ),
                    child: Icon(Icons.receipt_long_outlined, color: cs.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.newInvoice,
                          style: t.titleLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          l10n.createInvoiceSetupSubtitle,
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
            _clientCard(context),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                title: Text(l10n.dueDate),
                subtitle: Text(_fmtDate(_dueDate)),
                trailing: const Icon(Icons.event),
                onTap: _pickDueDate,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConnectionTile extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onTap;

  const _ConnectionTile({
    required this.data,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context)!;

    final id = int.tryParse((data['other_user_id'] ?? '0').toString()) ?? 0;
    final name = (data['other_display_name'] ?? '').toString().trim();
    final email = (data['other_email'] ?? '').toString().trim();

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withOpacity(0.55),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: cs.outlineVariant.withOpacity(0.25)),
        ),
        child: Row(
          children: [
            Container(
              height: 44,
              width: 44,
              decoration: BoxDecoration(
                color: cs.surface.withOpacity(0.7),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: cs.outlineVariant.withOpacity(0.18)),
              ),
              child: Icon(Icons.verified_user_outlined, color: cs.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name.isEmpty ? '${l10n.connectedUser} #$id' : name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.titleSmall?.copyWith(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 26, color: cs.onSurface.withOpacity(0.55)),
          ],
        ),
      ),
    );
  }
}