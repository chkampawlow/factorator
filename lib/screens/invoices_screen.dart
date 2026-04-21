import 'package:flutter/material.dart';
import 'package:my_app/l10n/app_localizations.dart';
import 'package:my_app/screens/add_client_screen.dart';
import 'package:my_app/screens/invoice_edit_screen.dart';
import 'package:my_app/services/auth_service.dart';
import 'package:my_app/services/currency_service.dart';
import 'package:my_app/services/exchange_rate_service.dart';
import 'package:my_app/services/settings_service.dart';
import 'package:my_app/storage/clients_repo.dart';
import 'package:my_app/storage/invoices_repo.dart';
import 'package:my_app/widgets/app_alerts.dart';
import 'package:my_app/widgets/app_top_bar.dart';

class InvoicesScreen extends StatefulWidget {
  final int initialInvoiceId;
  final String initialStatus;
  final VoidCallback onToggleTheme;
  final void Function(Color color) onChangePrimaryColor;
  final void Function(String code) onChangeLanguage;
  final Color currentPrimaryColor;

  const InvoicesScreen({
    super.key,
    this.initialInvoiceId = 0,
    this.initialStatus = 'all',
    required this.onToggleTheme,
    required this.onChangePrimaryColor,
    required this.onChangeLanguage,
    required this.currentPrimaryColor,
  });

  @override
  State<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends State<InvoicesScreen> {
  String _paymentMethodLabel(String raw, AppLocalizations l10n) {
    final s = raw.trim().toUpperCase();
    switch (s) {
      case 'CASH':
        return l10n.paymentCash;
      case 'CARD':
        return l10n.paymentCard;
      case 'TRANSFER':
        return l10n.paymentTransfer;
      case 'CHECK':
        return l10n.paymentCheck;
      default:
        return '';
    }
  }

  Future<void> _deleteDraftInvoice(int invoiceId) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.delete),
        content: Text(l10n.deleteDraftInvoiceConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _repo.deleteInvoice(invoiceId);
      if (!mounted) return;
      setState(() {
        _invoices.removeWhere((e) => _toInt(e['id']) == invoiceId);
      });
      AppAlerts.success(context, l10n.invoiceDeleted);
    } catch (e) {
      if (!mounted) return;
      AppAlerts.error(context,
          '${l10n.deleteFailed}: ${e.toString().replaceFirst('Exception: ', '')}');
    }
  }

  final InvoicesRepo _repo = InvoicesRepo();
  final AuthService _authService = AuthService();
  final SettingsService _settingsService = SettingsService();
  final ClientsRepo _clientsRepo = ClientsRepo();
  final TextEditingController _searchCtrl = TextEditingController();

  bool _loading = true;
  bool _didLoadOnce = false;
  bool _updatingStatus = false;
  String _currency = 'TND';
  String _statusFilter = 'all';
  List<Map<String, dynamic>> _invoices = [];

  List<Map<String, dynamic>> get _filteredInvoices {
    final query = _searchCtrl.text.trim().toLowerCase();

    final filtered = _invoices.where((inv) {
      final invoiceNumber = (inv['invoice'] ?? '').toString().toLowerCase();
      final email = (inv['custom_email'] ?? '').toString().toLowerCase();
      final code = (inv['custom_code'] ?? '').toString().toLowerCase();
      final invoiceType = (inv['invoice_type'] ?? '').toString().toLowerCase();
      final typeDoc = (inv['type_doc'] ?? '').toString().toLowerCase();
      final clientName = (inv['client_name'] ??
              inv['custom_name'] ??
              inv['customer_name'] ??
              inv['name'] ??
              '')
          .toString()
          .toLowerCase();
      final status = _normalizedStatus((inv['status'] ?? 'UNPAID').toString())
          .toLowerCase();

      final matchesStatus =
          _statusFilter == 'all' ? true : status == _statusFilter;

      final matchesQuery = query.isEmpty ||
          invoiceNumber.contains(query) ||
          email.contains(query) ||
          code.contains(query) ||
          invoiceType.contains(query) ||
          typeDoc.contains(query) ||
          clientName.contains(query);

      return matchesStatus && matchesQuery;
    }).toList();

    filtered.sort((a, b) {
      final aStatus = _normalizedStatus((a['status'] ?? 'UNPAID').toString());
      final bStatus = _normalizedStatus((b['status'] ?? 'UNPAID').toString());
      final aDue = _parseDate(a['invoice_due_date']);
      final bDue = _parseDate(b['invoice_due_date']);

      final aOverdue = _isOverdue(aStatus, aDue);
      final bOverdue = _isOverdue(bStatus, bDue);

      if (aOverdue != bOverdue) {
        return aOverdue ? -1 : 1;
      }

      if (aStatus == 'UNPAID' && bStatus != 'UNPAID') return -1;
      if (aStatus != 'UNPAID' && bStatus == 'UNPAID') return 1;

      return bDue.compareTo(aDue);
    });

    return filtered;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didLoadOnce) {
      _didLoadOnce = true;
      _statusFilter = _normalizeFilterInput(widget.initialStatus);
      _load();
    }
  }

  int _toInt(dynamic v, [int fallback = 0]) {
    if (v == null) return fallback;
    if (v is int) return v;
    return int.tryParse(v.toString()) ?? fallback;
  }

  String _normalizeFilterInput(String v) {
    final s = v.trim().toLowerCase();
    if (s.isEmpty) return 'all';

    // Accept multiple synonyms coming from other screens / backend.
    if (s == 'all') return 'all';
    if (s == 'draft') return 'draft';
    if (s == 'paid') return 'paid';
    if (s == 'unpaid' || s == 'open') return 'unpaid';
    if (s == 'cancelled' || s == 'canceled') return 'cancelled';

    // Also accept uppercase values.
    if (s == 'paid') return 'paid';
    if (s == 'unpaid') return 'unpaid';

    return 'all';
  }

  Future<Map<String, dynamic>?> _pickClient() async {
    return showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _ClientPickerSheet(clientsRepo: _clientsRepo),
    );
  }

  Future<void> _createDraftAndOpenEdit() async {
    final l10n = AppLocalizations.of(context)!;
    if (_updatingStatus || _loading) return;

    final picked = await _pickClient();
    if (!mounted || picked == null) return;

    final clientId = _toInt(picked['id']);
    if (clientId <= 0) {
      AppAlerts.error(context, l10n.invalidClientId);
      return;
    }

    final now = DateTime.now();

    try {
      final invoiceId = await _repo.createInvoiceHeader(
        clientId: clientId,
        issueDate: now,
        dueDate: now.add(const Duration(days: 7)),
        status: 'DRAFT',
        subtotal: 0,
        totalVat: 0,
        total: 0,
      );

      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => InvoiceEditScreen(
            invoiceId: invoiceId,
            onToggleTheme: widget.onToggleTheme,
            onChangePrimaryColor: widget.onChangePrimaryColor,
            onChangeLanguage: widget.onChangeLanguage,
            currentPrimaryColor: widget.currentPrimaryColor,
          ),
        ),
      );

      if (!mounted) return;
      await _load();
    } catch (e) {
      if (!mounted) return;
      AppAlerts.error(
        context,
        '${l10n.saveFailed}: ${e.toString().replaceFirst('Exception: ', '')}',
      );
    }
  }

  Future<void> _openEdit(int invoiceId) async {
    if (invoiceId <= 0) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InvoiceEditScreen(
          invoiceId: invoiceId,
          onToggleTheme: widget.onToggleTheme,
          onChangePrimaryColor: widget.onChangePrimaryColor,
          onChangeLanguage: widget.onChangeLanguage,
          currentPrimaryColor: widget.currentPrimaryColor,
        ),
      ),
    );

    if (!mounted) return;
    await _load();
  }

  Future<void> _load() async {
    final l10n = AppLocalizations.of(context)!;

    if (mounted) {
      setState(() => _loading = true);
    }

    try {
      final data = await _repo.getAllInvoices();
      final currency = await _settingsService.getCurrency();
      final currentUser = await _authService.me();
      final userUsesFodec =
          ExchangeRateService.fodecEnabledFromMap(currentUser);
      final fodecRate = userUsesFodec
          ? ExchangeRateService.fodecRateForCurrency(currency)
          : 0.0;

      if (!mounted) return;

      setState(() {
        _invoices = data.map((invoice) {
          final normalized = Map<String, dynamic>.from(invoice);
          if (!userUsesFodec) {
            final subtotal = _toDouble(normalized['subtotal']);
            final vatAmount = _toDouble(normalized['montant_tva']);
            final timbre = _toDouble(normalized['timbre']);
            normalized['fodec'] = 0.0;
            normalized['fodec_rate'] = 0.0;
            normalized['base_tva'] = subtotal;
            normalized['total'] = subtotal + vatAmount + timbre;
          } else {
            normalized['fodec'] = 1;
            normalized['fodec_rate'] = fodecRate;
          }
          return normalized;
        }).toList();
        _currency = currency;
        _loading = false;
        if (widget.initialInvoiceId > 0) {
          // Open requested invoice after first load.
          final idToOpen = widget.initialInvoiceId;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            _openEdit(idToOpen);
          });
        }
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _invoices = [];
        _loading = false;
      });

      AppAlerts.error(
        context,
        '${l10n.loadFailed}: ${e.toString().replaceFirst('Exception: ', '')}',
      );
    }
  }

  double _toDouble(dynamic value, [double fallback = 0.0]) {
    if (value == null) return fallback;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString().replaceAll(',', '.')) ?? fallback;
  }

  DateTime _parseDate(dynamic value) {
    if (value == null) return DateTime.now();
    return DateTime.tryParse(value.toString()) ?? DateTime.now();
  }

  String _normalizedStatus(String status) {
    final s = status.trim().toUpperCase();
    if (s == 'DRAFT') return 'DRAFT';
    if (s == 'OPEN') return 'UNPAID';
    if (s == 'PAID') return 'PAID';
    if (s == 'CANCELLED' || s == 'CANCELED') return 'CANCELLED';
    return 'UNPAID';
  }

  String _statusLabel(String status, AppLocalizations l10n) {
    final s = _normalizedStatus(status);
    if (s == 'DRAFT') return l10n.draftLabel.toUpperCase();
    if (s == 'PAID') return l10n.paidLabel.toUpperCase();
    if (s == 'CANCELLED') return l10n.cancelledLabel.toUpperCase();
    return l10n.unpaidLabel.toUpperCase();
  }

  bool _isOverdue(String status, DateTime due) {
    final normalized = _normalizedStatus(status);
    final now = DateTime.now();
    final dueOnly = DateTime(due.year, due.month, due.day);
    final today = DateTime(now.year, now.month, now.day);

    return normalized != 'PAID' &&
        normalized != 'CANCELLED' &&
        dueOnly.isBefore(today);
  }

  bool _isDueSoon(String status, DateTime due) {
    final normalized = _normalizedStatus(status);
    if (normalized == 'PAID' || normalized == 'CANCELLED') return false;

    final now = DateTime.now();
    final d0 = DateTime(now.year, now.month, now.day);
    final d1 = DateTime(due.year, due.month, due.day);
    final diff = d1.difference(d0).inDays;

    return diff >= 0 && diff <= 3;
  }

  Color _statusBg(String status, bool isOverdue, ColorScheme cs) {
    final s = _normalizedStatus(status);
    if (s == 'DRAFT') return cs.secondaryContainer;
    if (s == 'PAID') return cs.primaryContainer;
    if (s == 'CANCELLED') return cs.surfaceContainerHighest;
    if (isOverdue) return cs.errorContainer;
    return cs.tertiaryContainer;
  }

  Color _statusFg(String status, bool isOverdue, ColorScheme cs) {
    final s = _normalizedStatus(status);
    if (s == 'DRAFT') return cs.onSecondaryContainer;
    if (s == 'PAID') return cs.onPrimaryContainer;
    if (s == 'CANCELLED') return cs.onSurfaceVariant;
    if (isOverdue) return cs.onErrorContainer;
    return cs.onTertiaryContainer;
  }

  Future<void> _updateInvoiceStatus(
    int invoiceId,
    String status, {
    String? paymentMethod,
  }) async {
    final l10n = AppLocalizations.of(context)!;

    if (_updatingStatus) return;

    setState(() {
      _updatingStatus = true;
    });

    try {
      await _repo.updateInvoiceStatus(
        invoiceId,
        status,
        paymentMethod: paymentMethod,
      );
      if (!mounted) return;

      AppAlerts.success(context, l10n.invoiceStatusUpdated);

      await _load();
    } catch (e) {
      if (!mounted) return;
      AppAlerts.error(
        context,
        '${l10n.updateFailed}: ${e.toString().replaceFirst('Exception: ', '')}',
      );
    } finally {
      if (mounted) {
        setState(() {
          _updatingStatus = false;
        });
      }
    }
  }

  Future<String?> _pickPaymentMethod() async {
    final l10n = AppLocalizations.of(context)!;
    final methods = <({IconData icon, String value, String label})>[
      (icon: Icons.payments_outlined, value: 'CASH', label: l10n.paymentCash),
      (icon: Icons.credit_card_rounded, value: 'CARD', label: l10n.paymentCard),
      (
        icon: Icons.account_balance_rounded,
        value: 'TRANSFER',
        label: l10n.paymentTransfer
      ),
      (
        icon: Icons.receipt_long_outlined,
        value: 'CHECK',
        label: l10n.paymentCheck
      ),
    ];

    return showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.paymentMethod,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 12),
                for (final method in methods) ...[
                  ListTile(
                    leading: Icon(method.icon),
                    title: Text(method.label),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    onTap: () => Navigator.pop(context, method.value),
                  ),
                  const SizedBox(height: 4),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showStatusSheet(int invoiceId, String currentStatus) async {
    final l10n = AppLocalizations.of(context)!;
    final normalized = _normalizedStatus(currentStatus);
    if (normalized == 'DRAFT') {
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.changeStatus,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 14),
                _StatusActionTile(
                  icon: Icons.check_circle_rounded,
                  title: l10n.markAsPaid,
                  selected: normalized == 'PAID',
                  onTap: () async {
                    Navigator.pop(context);
                    final paymentMethod = await _pickPaymentMethod();
                    if (paymentMethod == null) return;
                    await _updateInvoiceStatus(
                      invoiceId,
                      'PAID',
                      paymentMethod: paymentMethod,
                    );
                  },
                ),
                const SizedBox(height: 8),
                _StatusActionTile(
                  icon: Icons.payments_outlined,
                  title: l10n.markAsUnpaid,
                  selected: normalized == 'UNPAID',
                  onTap: () async {
                    Navigator.pop(context);
                    await _updateInvoiceStatus(invoiceId, 'UNPAID');
                  },
                ),
                const SizedBox(height: 8),
                _StatusActionTile(
                  icon: Icons.cancel_rounded,
                  title: l10n.markAsCancelled,
                  selected: normalized == 'CANCELLED',
                  onTap: () async {
                    Navigator.pop(context);
                    await _updateInvoiceStatus(invoiceId, 'CANCELLED');
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final filteredInvoices = _filteredInvoices;

    return Scaffold(
      appBar: AppTopBar(
        title: l10n.invoices,
        onToggleTheme: widget.onToggleTheme,
        onChangePrimaryColor: widget.onChangePrimaryColor,
        onChangeLanguage: widget.onChangeLanguage,
        currentPrimaryColor: widget.currentPrimaryColor,
      ),
      floatingActionButton: _loading || _invoices.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: _createDraftAndOpenEdit,
              icon: const Icon(Icons.add),
              label: Text(l10n.newInvoice),
            ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  TextField(
                    controller: _searchCtrl,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: l10n.searchInvoiceClientEmail,
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchCtrl.text.isEmpty
                          ? null
                          : IconButton(
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() {});
                              },
                              icon: const Icon(Icons.close),
                            ),
                      filled: true,
                      fillColor: cs.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: cs.outlineVariant.withValues(alpha: 0.35),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: cs.primary,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _FilterChip(
                          label: l10n.all,
                          selected: _statusFilter == 'all',
                          onTap: () => setState(() => _statusFilter = 'all'),
                        ),
                        const SizedBox(width: 8),
                        _FilterChip(
                          label: l10n.draftLabel,
                          selected: _statusFilter == 'draft',
                          onTap: () => setState(() => _statusFilter = 'draft'),
                        ),
                        const SizedBox(width: 8),
                        _FilterChip(
                          label: l10n.unpaidLabel,
                          selected: _statusFilter == 'unpaid',
                          onTap: () => setState(() => _statusFilter = 'unpaid'),
                        ),
                        const SizedBox(width: 8),
                        _FilterChip(
                          label: l10n.paidLabel,
                          selected: _statusFilter == 'paid',
                          onTap: () => setState(() => _statusFilter = 'paid'),
                        ),
                        const SizedBox(width: 8),
                        _FilterChip(
                          label: l10n.cancelledLabel,
                          selected: _statusFilter == 'cancelled',
                          onTap: () =>
                              setState(() => _statusFilter = 'cancelled'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: _invoices.isEmpty
                        ? _EmptyInvoices(onCreateDraft: _createDraftAndOpenEdit)
                        : filteredInvoices.isEmpty
                            ? ListView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                children: [
                                  const SizedBox(height: 80),
                                  Center(
                                    child: Text(l10n.noInvoicesMatchSearch),
                                  ),
                                ],
                              )
                            : RefreshIndicator(
                                onRefresh: _load,
                                child: ListView.separated(
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  itemCount: filteredInvoices.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(height: 12),
                                  itemBuilder: (context, i) {
                                    final inv = filteredInvoices[i];

                                    final invoiceId = _toInt(inv['id']);
                                    final invNumber =
                                        (inv['invoice'] ?? '').toString();
                                    final status = _normalizedStatus(
                                        (inv['status'] ?? 'UNPAID').toString());
                                    final totalValue = _toDouble(inv['total']);
                                    final subtotalValue =
                                        _toDouble(inv['subtotal']);
                                    final fodecRate =
                                        _toDouble(inv['fodec_rate']);
                                    final storedBaseTvaValue = _toDouble(
                                      inv['base_tva'],
                                      subtotalValue,
                                    );
                                    final calculatedFodecValue = fodecRate > 0
                                        ? subtotalValue * (fodecRate / 100.0)
                                        : 0.0;
                                    final baseTvaValue = fodecRate <= 0
                                        ? subtotalValue
                                        : (storedBaseTvaValue <=
                                                subtotalValue + 0.0005
                                            ? subtotalValue +
                                                calculatedFodecValue
                                            : storedBaseTvaValue);
                                    final vatAmountValue =
                                        _toDouble(inv['montant_tva']);
                                    final timbreValue =
                                        _toDouble(inv['timbre']);
                                    final itemTotal =
                                        baseTvaValue + vatAmountValue;
                                    final displayTotal = timbreValue > 0 &&
                                            totalValue <= itemTotal + 0.0005
                                        ? itemTotal + timbreValue
                                        : totalValue;
                                    final total = CurrencyService.format(
                                        displayTotal, _currency);
                                    final subtotal = CurrencyService.format(
                                        subtotalValue, _currency);
                                    final vatAmount = CurrencyService.format(
                                        vatAmountValue, _currency);
                                    final email =
                                        (inv['custom_email'] ?? '').toString();
                                    final invoiceType =
                                        (inv['invoice_type'] ?? '').toString();
                                    final clientName = (inv['client_name'] ??
                                            inv['custom_name'] ??
                                            inv['customer_name'] ??
                                            inv['name'] ??
                                            '')
                                        .toString();

                                    final due =
                                        _parseDate(inv['invoice_due_date']);
                                    final issue =
                                        _parseDate(inv['invoice_date']);
                                    final overdue = _isOverdue(status, due);
                                    final dueSoon = _isDueSoon(status, due);

                                    final paymentRaw = (inv['payment_method'] ??
                                            inv['paymentMethod'] ??
                                            '')
                                        .toString();
                                    final paymentLabel =
                                        _paymentMethodLabel(paymentRaw, l10n);
                                    final canDelete = status == 'DRAFT';
                                    return Dismissible(
                                      key: ValueKey('invoice_$invoiceId'),
                                      direction: canDelete
                                          ? DismissDirection.horizontal
                                          : DismissDirection.none,
                                      confirmDismiss: (dir) async {
                                        if (!canDelete) return false;
                                        await _deleteDraftInvoice(invoiceId);
                                        return false;
                                      },
                                      background: Container(
                                        alignment: Alignment.centerLeft,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 18),
                                        decoration: BoxDecoration(
                                          color: cs.errorContainer,
                                          borderRadius:
                                              BorderRadius.circular(22),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(Icons.delete_outline,
                                                color: cs.onErrorContainer),
                                            const SizedBox(width: 10),
                                            Text(l10n.delete,
                                                style: TextStyle(
                                                    color: cs.onErrorContainer,
                                                    fontWeight:
                                                        FontWeight.w900)),
                                          ],
                                        ),
                                      ),
                                      secondaryBackground: Container(
                                        alignment: Alignment.centerRight,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 18),
                                        decoration: BoxDecoration(
                                          color: cs.errorContainer,
                                          borderRadius:
                                              BorderRadius.circular(22),
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.end,
                                          children: [
                                            Text(l10n.delete,
                                                style: TextStyle(
                                                    color: cs.onErrorContainer,
                                                    fontWeight:
                                                        FontWeight.w900)),
                                            const SizedBox(width: 10),
                                            Icon(Icons.delete_outline,
                                                color: cs.onErrorContainer),
                                          ],
                                        ),
                                      ),
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(22),
                                        onTap: () => _openEdit(invoiceId),
                                        child: Container(
                                          padding: const EdgeInsets.all(16),
                                          decoration: BoxDecoration(
                                            color: cs.surface,
                                            borderRadius:
                                                BorderRadius.circular(22),
                                            border: Border.all(
                                              color: overdue
                                                  ? cs.error
                                                      .withValues(alpha: 0.30)
                                                  : (dueSoon
                                                      ? cs.tertiary.withValues(
                                                          alpha: 0.28)
                                                      : cs.outlineVariant
                                                          .withValues(
                                                              alpha: 0.28)),
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Theme.of(context)
                                                    .shadowColor
                                                    .withValues(
                                                      alpha: Theme.of(context)
                                                                  .brightness ==
                                                              Brightness.dark
                                                          ? 0.22
                                                          : 0.08,
                                                    ),
                                                blurRadius: 20,
                                                offset: const Offset(0, 6),
                                              ),
                                            ],
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Text(
                                                          invNumber.isEmpty
                                                              ? l10n.invoice
                                                              : invNumber,
                                                          maxLines: 1,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                          style: theme.textTheme
                                                              .titleMedium
                                                              ?.copyWith(
                                                            fontWeight:
                                                                FontWeight.w900,
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                            height: 6),
                                                        if (clientName
                                                            .trim()
                                                            .isNotEmpty)
                                                          Text(
                                                            clientName,
                                                            maxLines: 1,
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                            style: theme
                                                                .textTheme
                                                                .bodyLarge
                                                                ?.copyWith(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w800,
                                                            ),
                                                          ),
                                                        if (email.isNotEmpty)
                                                          Padding(
                                                            padding:
                                                                const EdgeInsets
                                                                    .only(
                                                                    top: 3),
                                                            child: Text(
                                                              email,
                                                              maxLines: 1,
                                                              overflow:
                                                                  TextOverflow
                                                                      .ellipsis,
                                                              style: theme
                                                                  .textTheme
                                                                  .bodyMedium
                                                                  ?.copyWith(
                                                                color: cs
                                                                    .onSurfaceVariant,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                              ),
                                                            ),
                                                          ),
                                                      ],
                                                    ),
                                                  ),
                                                  const SizedBox(width: 10),
                                                  Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment.end,
                                                    children: [
                                                      _StatusPill(
                                                        text: overdue
                                                            ? l10n.overdue
                                                                .toUpperCase()
                                                            : _statusLabel(
                                                                status, l10n),
                                                        bg: _statusBg(status,
                                                            overdue, cs),
                                                        fg: _statusFg(status,
                                                            overdue, cs),
                                                        onTap: (_updatingStatus ||
                                                                status ==
                                                                    'DRAFT')
                                                            ? null
                                                            : () =>
                                                                _showStatusSheet(
                                                                    invoiceId,
                                                                    status),
                                                      ),
                                                      const SizedBox(
                                                          height: 10),
                                                      Text(
                                                        total,
                                                        style: theme.textTheme
                                                            .titleMedium
                                                            ?.copyWith(
                                                          fontWeight:
                                                              FontWeight.w900,
                                                        ),
                                                      ),
                                                      Text(
                                                        _currency,
                                                        style: theme
                                                            .textTheme.bodySmall
                                                            ?.copyWith(
                                                          color: cs
                                                              .onSurfaceVariant,
                                                          fontWeight:
                                                              FontWeight.w700,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 14),
                                              Wrap(
                                                spacing: 8,
                                                runSpacing: 8,
                                                children: [
                                                  _MetaChip(
                                                    text: [
                                                      '${l10n.issued} ${issue.toLocal().toString().split(' ')[0]}',
                                                      if (invoiceType
                                                          .isNotEmpty)
                                                        '${l10n.type}: $invoiceType',
                                                      if (paymentLabel
                                                          .isNotEmpty)
                                                        paymentLabel,
                                                    ].join(' • '),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 10),
                                              Align(
                                                alignment:
                                                    Alignment.centerRight,
                                                child: Text(
                                                  [
                                                    'HT $subtotal',
                                                    if (fodecRate > 0)
                                                      'Base TVA ${CurrencyService.format(baseTvaValue, _currency)}',
                                                    'TVA $vatAmount',
                                                  ].join(' • '),
                                                  style: theme
                                                      .textTheme.bodySmall
                                                      ?.copyWith(
                                                    color: cs.onSurfaceVariant,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String text;
  final Color bg;
  final Color fg;
  final VoidCallback? onTap;

  const _StatusPill({
    required this.text,
    required this.bg,
    required this.fg,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: fg.withValues(alpha: 0.28)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (onTap != null) ...[
                Icon(Icons.touch_app_rounded, size: 15, color: fg),
                const SizedBox(width: 5),
              ],
              Text(
                text,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: fg,
                  fontSize: 12,
                ),
              ),
              if (onTap != null) ...[
                const SizedBox(width: 3),
                Icon(Icons.expand_more_rounded, size: 16, color: fg),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final String text;

  const _MetaChip({required this.text});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _StatusActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool selected;
  final VoidCallback onTap;

  const _StatusActionTile({
    required this.icon,
    required this.title,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: selected
              ? cs.primaryContainer.withValues(alpha: 0.65)
              : cs.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? cs.primary.withValues(alpha: 0.4)
                : cs.outlineVariant.withValues(alpha: 0.25),
          ),
        ),
        child: Row(
          children: [
            Icon(icon),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ),
            if (selected) const Icon(Icons.check_circle_rounded),
          ],
        ),
      ),
    );
  }
}

class _EmptyInvoices extends StatelessWidget {
  final Future<void> Function() onCreateDraft;

  const _EmptyInvoices({required this.onCreateDraft});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 80),
        Icon(
          Icons.receipt_long,
          size: 70,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(height: 14),
        Center(
          child: Text(
            l10n.noInvoicesYet,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Center(
          child: Text(
            l10n.createYourFirstInvoiceToSeeItHere,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(height: 18),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: SizedBox(
            height: 48,
            child: FilledButton.icon(
              onPressed: onCreateDraft,
              icon: const Icon(Icons.add),
              label: Text(l10n.createInvoice),
            ),
          ),
        ),
      ],
    );
  }
}

class _ClientPickerSheet extends StatefulWidget {
  final ClientsRepo clientsRepo;
  const _ClientPickerSheet({required this.clientsRepo});

  @override
  State<_ClientPickerSheet> createState() => _ClientPickerSheetState();
}

class _ClientPickerSheetState extends State<_ClientPickerSheet> {
  final TextEditingController _searchCtrl = TextEditingController();

  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _clients = [];
  List<Map<String, dynamic>> _filtered = [];

  @override
  void initState() {
    super.initState();
    _load();
    _searchCtrl.addListener(_apply);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _apply() {
    final q = _searchCtrl.text.trim().toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? _clients
          : _clients.where((c) {
              final name = (c['name'] ?? '').toString().toLowerCase();
              final email = (c['email'] ?? '').toString().toLowerCase();
              final mf = (c['fiscalId'] ?? c['fiscal_id'] ?? '')
                  .toString()
                  .toLowerCase();
              final cin = (c['cin'] ?? '').toString().toLowerCase();
              return name.contains(q) ||
                  email.contains(q) ||
                  mf.contains(q) ||
                  cin.contains(q);
            }).toList();
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final data = await widget.clientsRepo.getAllClientsarchived();
      if (!mounted) return;
      setState(() {
        _clients = List<Map<String, dynamic>>.from(data);
        _filtered = List<Map<String, dynamic>>.from(data);
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

  bool _looksLikeCin(String s) {
    final v = s.trim();
    return v.length == 8; // CIN rule
  }

  bool _looksLikeFiscalId(String s) {
    final v = s.trim().toUpperCase();
    return RegExp(r'^\d{7}[A-Z]$').hasMatch(v);
  }

  Future<void> _addClientFromSearch(String value) async {
    final q = value.trim();
    final saved = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddClientScreen(
          prefilledName:
              q.isNotEmpty && !_looksLikeCin(q) && !_looksLikeFiscalId(q)
                  ? q
                  : null,
          prefilledCin: _looksLikeCin(q) ? q : null,
          prefilledFiscalId: _looksLikeFiscalId(q) ? q : null,
        ),
      ),
    );

    if (saved != true) return;

    await _load();
    if (!mounted) return;

    final lookup = q.toLowerCase();
    if (lookup.isEmpty) {
      if (_clients.isNotEmpty) {
        Navigator.pop(context, _clients.first);
      }
      return;
    }

    final match = _clients.firstWhere(
      (c) {
        final name = (c['name'] ?? '').toString().trim().toLowerCase();
        final mf = (c['fiscalId'] ?? c['fiscal_id'] ?? '')
            .toString()
            .trim()
            .toLowerCase();
        final cin = (c['cin'] ?? '').toString().trim().toLowerCase();
        return lookup.isNotEmpty &&
            (name == lookup || mf == lookup || cin == lookup);
      },
      orElse: () => <String, dynamic>{},
    );

    if (match.isNotEmpty) {
      Navigator.pop(context, match);
    }
  }

  Widget _clientEmptyState(BuildContext context, String searchValue) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final hasSearch = searchValue.trim().isNotEmpty;

    return Center(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(28, 42, 28, 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.person_add_alt_1_outlined,
              size: 72,
              color: cs.primary,
            ),
            const SizedBox(height: 18),
            Text(
              _clients.isEmpty ? l10n.noCustomersYet : l10n.noResults,
              textAlign: TextAlign.center,
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              hasSearch
                  ? '${l10n.addNewClient}: ${searchValue.trim()}'
                  : l10n.createFirstCustomerToSeeHere,
              textAlign: TextAlign.center,
              style: textTheme.titleSmall?.copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w800,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    final q = _searchCtrl.text.trim();

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: bottom),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * .80,
          child: Column(
            children: [
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: l10n.searchNameMfCin,
                    prefixIcon: const Icon(Icons.search),
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                        ? Padding(
                            padding: const EdgeInsets.all(16),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color:
                                    cs.errorContainer.withValues(alpha: 0.55),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                    color: cs.error.withValues(alpha: 0.25)),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(Icons.error_rounded,
                                      color: cs.onErrorContainer),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      '${l10n.loadFailed}: ${_error ?? ''}',
                                      style: TextStyle(
                                        color: cs.onErrorContainer,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : _filtered.isEmpty
                            ? _clientEmptyState(context, q)
                            : ListView.separated(
                                itemCount: _filtered.length,
                                separatorBuilder: (_, __) =>
                                    const Divider(height: 1),
                                itemBuilder: (_, i) {
                                  final c = _filtered[i];
                                  final name = (c['name'] ?? '').toString();
                                  final email = (c['email'] ?? '').toString();
                                  final mf =
                                      (c['fiscalId'] ?? c['fiscal_id'] ?? '')
                                          .toString();
                                  final cin = (c['cin'] ?? '').toString();

                                  final parts = <String>[];
                                  if (email.trim().isNotEmpty) {
                                    parts.add(email.trim());
                                  }
                                  if (mf.trim().isNotEmpty) {
                                    parts.add('MF: ${mf.trim()}');
                                  }
                                  if (cin.trim().isNotEmpty) {
                                    parts.add('CIN: ${cin.trim()}');
                                  }

                                  return ListTile(
                                    title: Text(
                                      name.isEmpty ? l10n.client : name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    subtitle: parts.isEmpty
                                        ? null
                                        : Text(
                                            parts.join(' • '),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                    onTap: () => Navigator.pop(context, c),
                                  );
                                },
                              ),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.person_add_alt_1_rounded),
                    label: Text(
                      q.isEmpty
                          ? l10n.addNewClient
                          : '${l10n.addNewClient}: $q',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onPressed: () => _addClientFromSearch(q),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
