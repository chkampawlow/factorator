import 'package:flutter/material.dart';
import 'package:my_app/core/access_scope.dart';
import 'package:my_app/core/permission_service.dart';
import 'package:my_app/core/supplier_reception_logic.dart';
import 'package:my_app/l10n/app_localizations.dart';
import 'package:my_app/l10n/mobile_labels.dart';
import 'package:my_app/storage/supplier_receptions_repo.dart';
import 'package:my_app/widgets/app_alerts.dart';
import 'package:my_app/widgets/app_top_bar.dart';

import 'supplier_reception_form_screen.dart';

class SupplierReceptionsScreen extends StatefulWidget {
  const SupplierReceptionsScreen({
    super.key,
    required this.onToggleTheme,
    required this.onChangePrimaryColor,
    required this.onChangeLanguage,
    required this.currentPrimaryColor,
  });

  final VoidCallback onToggleTheme;
  final void Function(Color color) onChangePrimaryColor;
  final void Function(String code) onChangeLanguage;
  final Color currentPrimaryColor;

  @override
  State<SupplierReceptionsScreen> createState() =>
      _SupplierReceptionsScreenState();
}

class _SupplierReceptionsScreenState extends State<SupplierReceptionsScreen> {
  final _repo = SupplierReceptionsRepo();
  final _search = TextEditingController();
  List<Map<String, dynamic>> _receptions = [];
  String _status = '';
  String? _error;
  bool _loading = true;
  bool _openingNew = false;

  PermissionService get _permissions => AccessScope.of(context).permissions;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final rows = await _repo.list(
        search: _search.text,
        status: _status,
      );
      if (!mounted) return;
      setState(() {
        _receptions = rows;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _openReception(Map<String, dynamic> summary) async {
    final id = int.tryParse('${summary['id'] ?? 0}') ?? 0;
    if (id <= 0) return;
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => SupplierReceptionDetailScreen(
          receptionId: id,
          permissions: _permissions,
        ),
      ),
    );
    if (changed == true) await _load();
  }

  Future<void> _createFromOrder() async {
    final l10n = AppLocalizations.of(context)!;
    if (!_permissions.can(AppPermission.supplierReceptionsCreate)) {
      AppAlerts.error(context, l10n.cannotCreateReception);
      return;
    }
    setState(() => _openingNew = true);
    try {
      final orders = await _repo.listOpenSupplierOrders();
      if (!mounted) return;
      setState(() => _openingNew = false);
      if (orders.isEmpty) {
        AppAlerts.info(
          context,
          l10n.noSupplierOrderAvailable,
        );
        return;
      }
      final selected = await showModalBottomSheet<Map<String, dynamic>>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (context) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: .75,
          builder: (_, controller) => ListView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            children: [
              Text(
                l10n.selectSupplierOrder,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              ...orders.map(
                (order) => Card(
                  child: ListTile(
                    leading: const Icon(Icons.shopping_cart_outlined),
                    title:
                        Text('${order['orderNumber'] ?? l10n.purchaseOrder}'),
                    subtitle: Text(
                      '${order['supplierName'] ?? ''}\n'
                      '${localizedWorkflowStatus(l10n, '${order['status'] ?? ''}')} • '
                      '${l10n.received} ${_number(receptionNumber(order['receivedQty']))} / '
                      '${_number(receptionNumber(order['orderedQty']))}',
                    ),
                    isThreeLine: true,
                    onTap: () => Navigator.pop(context, order),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
      if (selected == null || !mounted) return;
      setState(() => _openingNew = true);
      final orderId = int.tryParse('${selected['id'] ?? 0}') ?? 0;
      final results = await Future.wait([
        _repo.supplierOrderDetail(orderId),
        _repo.forSupplierOrder(orderId),
      ]);
      if (!mounted) return;
      setState(() => _openingNew = false);
      final saved = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => SupplierReceptionFormScreen(
            supplierOrder: results[0] as Map<String, dynamic>,
            previousReceptions: results[1] as List<Map<String, dynamic>>,
          ),
        ),
      );
      if (saved == true) await _load();
    } catch (error) {
      if (!mounted) return;
      setState(() => _openingNew = false);
      AppAlerts.error(
        context,
        error.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final canCreate = _permissions.can(AppPermission.supplierReceptionsCreate);
    return Scaffold(
      appBar: AppTopBar(
        title: l10n.supplierReceptionsTitle,
        onToggleTheme: widget.onToggleTheme,
        onChangePrimaryColor: widget.onChangePrimaryColor,
        onChangeLanguage: widget.onChangeLanguage,
        currentPrimaryColor: widget.currentPrimaryColor,
      ),
      floatingActionButton: canCreate
          ? FloatingActionButton.extended(
              onPressed: _openingNew ? null : _createFromOrder,
              icon: _openingNew
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add),
              label: Text(l10n.receiveOrder),
            )
          : null,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: TextField(
                  controller: _search,
                  onSubmitted: (_) => _load(),
                  decoration: InputDecoration(
                    hintText: l10n.searchSupplierOrderDocument,
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: IconButton(
                      onPressed: _load,
                      icon: const Icon(Icons.arrow_forward),
                    ),
                  ),
                ),
              ),
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: ['', 'DRAFT', 'REVIEWED']
                      .map(
                        (status) => Padding(
                          padding: const EdgeInsetsDirectional.only(end: 8),
                          child: ChoiceChip(
                            label: Text(status.isEmpty
                                ? l10n.all
                                : localizedWorkflowStatus(l10n, status)),
                            selected: _status == status,
                            onSelected: (_) {
                              setState(() => _status = status);
                              _load();
                            },
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(child: _body()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body() {
    final l10n = AppLocalizations.of(context)!;
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 100),
            const Icon(Icons.cloud_off_outlined, size: 52),
            const SizedBox(height: 12),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            Center(
              child: FilledButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: Text(l10n.retry),
              ),
            ),
          ],
        ),
      );
    }
    if (_receptions.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 100),
            const Icon(Icons.inventory_outlined, size: 54),
            const SizedBox(height: 12),
            Text(
              l10n.noSupplierReceptions,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
        itemCount: _receptions.length,
        itemBuilder: (context, index) {
          final reception = _receptions[index];
          final lines = reception['lines'] as List? ?? const [];
          final damaged = lines.whereType<Map>().fold<double>(
                0,
                (sum, line) =>
                    sum +
                    receptionNumber(line['damagedQty']) +
                    receptionNumber(line['rejectedQty']),
              );
          final applied = receptionBool(reception['stockApplied']);
          final title = '${reception['supplierDeliveryNoteNumber'] ?? ''}'
                  .trim()
                  .isNotEmpty
              ? '${reception['supplierDeliveryNoteNumber']}'
              : '${reception['invoiceNumber'] ?? ''}'.trim().isNotEmpty
                  ? '${reception['invoiceNumber']}'
                  : '${l10n.receptionLabel} #${reception['id']}';
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              contentPadding: const EdgeInsets.all(14),
              leading: CircleAvatar(
                child: Icon(
                  applied ? Icons.inventory_rounded : Icons.inventory_outlined,
                ),
              ),
              title: Text(title),
              subtitle: Text(
                '${reception['supplierName'] ?? ''}\n${reception['sourceSupplierOrderNumber'] ?? l10n.noPurchaseOrder} • ${reception['receivedDate'] ?? ''}',
              ),
              isThreeLine: true,
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${_number(receptionNumber(reception['totalTtc']))} TND',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  if (damaged > 0)
                    const Icon(Icons.warning_amber_rounded, size: 19)
                  else
                    Text(localizedWorkflowStatus(
                      l10n,
                      '${reception['status'] ?? ''}',
                    )),
                ],
              ),
              onTap: () => _openReception(reception),
            ),
          );
        },
      ),
    );
  }

  static String _number(double value) =>
      value.toStringAsFixed(3).replaceFirst(RegExp(r'\.?0+$'), '');
}

class SupplierReceptionDetailScreen extends StatefulWidget {
  const SupplierReceptionDetailScreen({
    super.key,
    required this.receptionId,
    required this.permissions,
  });

  final int receptionId;
  final PermissionService permissions;

  @override
  State<SupplierReceptionDetailScreen> createState() =>
      _SupplierReceptionDetailScreenState();
}

class _SupplierReceptionDetailScreenState
    extends State<SupplierReceptionDetailScreen> {
  final _repo = SupplierReceptionsRepo();
  Map<String, dynamic>? _reception;
  String? _error;
  bool _loading = true;
  bool _confirming = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final reception = await _repo.detail(widget.receptionId);
      if (!mounted) return;
      setState(() {
        _reception = reception;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _edit() async {
    final reception = _reception;
    if (reception == null) return;
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => SupplierReceptionFormScreen(reception: reception),
      ),
    );
    if (changed == true) await _load();
  }

  Future<void> _confirm() async {
    final l10n = AppLocalizations.of(context)!;
    final reception = _reception;
    if (reception == null || _confirming) return;
    var createExpense = false;
    final canCreateExpense =
        widget.permissions.can(AppPermission.expensesCreate) &&
            receptionNumber(reception['totalTtc']) > 0;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(l10n.confirmSupplierReception),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.atomicStockNotice,
              ),
              if (canCreateExpense) ...[
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.createLinkedExpense),
                  value: createExpense,
                  onChanged: (value) =>
                      setDialogState(() => createExpense = value),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(l10n.confirmPostStock),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _confirming = true);
    try {
      final result = await _repo.confirm(
        widget.receptionId,
        createExpense: createExpense,
      );
      if (!mounted) return;
      final applied = int.tryParse('${result['applied_lines'] ?? 0}') ?? 0;
      AppAlerts.success(
        context,
        '${l10n.receptionConfirmed} $applied ${l10n.productLinesPosted}',
      );
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _confirming = false);
      AppAlerts.error(
        context,
        error.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final reception = _reception;
    final canEdit = reception != null &&
        !receptionBool(reception['stockApplied']) &&
        '${reception['status']}' == 'DRAFT' &&
        widget.permissions.can(AppPermission.supplierReceptionsUpdate);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.receptionDetails),
        actions: [
          if (canEdit)
            IconButton(
              onPressed: _edit,
              tooltip: l10n.editDraft,
              icon: const Icon(Icons.edit_outlined),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: _load,
                          icon: const Icon(Icons.refresh),
                          label: Text(l10n.retry),
                        ),
                      ],
                    ),
                  ),
                )
              : _detailBody(reception!),
    );
  }

  Widget _detailBody(Map<String, dynamic> reception) {
    final l10n = AppLocalizations.of(context)!;
    final lines = reception['lines'] as List? ?? const [];
    final stockApplied = receptionBool(reception['stockApplied']);
    final canConfirm = !stockApplied &&
        '${reception['status']}' == 'DRAFT' &&
        widget.permissions.can(AppPermission.supplierReceptionsConfirm);
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            '${reception['supplierName'] ?? ''}',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Chip(
                label: Text(localizedWorkflowStatus(
                  l10n,
                  '${reception['status'] ?? ''}',
                )),
              ),
              Chip(
                avatar: Icon(
                  stockApplied ? Icons.check_circle : Icons.schedule,
                  size: 18,
                ),
                label:
                    Text(stockApplied ? l10n.stockPosted : l10n.stockPending),
              ),
              if ('${reception['exceptionType'] ?? 'NONE'}' != 'NONE')
                Chip(
                  avatar: const Icon(Icons.warning_amber_rounded, size: 18),
                  label: Text(localizedReceptionException(
                    l10n,
                    '${reception['exceptionType']}',
                  )),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                _detailTile(
                  Icons.shopping_cart_outlined,
                  l10n.purchaseOrder,
                  '${reception['sourceSupplierOrderNumber'] ?? '-'}',
                ),
                _detailTile(
                  Icons.description_outlined,
                  l10n.supplierDeliveryNote,
                  '${reception['supplierDeliveryNoteNumber'] ?? '-'}',
                ),
                _detailTile(
                  Icons.receipt_long_outlined,
                  l10n.supplierInvoice,
                  '${reception['invoiceNumber'] ?? '-'}',
                ),
                _detailTile(
                  Icons.event_available_outlined,
                  l10n.received,
                  '${reception['receivedDate'] ?? '-'}',
                ),
              ],
            ),
          ),
          if ('${reception['exceptionReason'] ?? ''}'.trim().isNotEmpty)
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: ListTile(
                leading: const Icon(Icons.report_problem_outlined),
                title: Text(l10n.exceptionReason),
                subtitle: Text('${reception['exceptionReason']}'),
              ),
            ),
          if (receptionBool(reception['hasDiscrepancyAttachment']))
            Card(
              child: ListTile(
                leading: const Icon(Icons.attachment_outlined),
                title: Text(l10n.addDiscrepancyEvidence),
                subtitle: Text('${reception['discrepancyAttachmentName']}'),
              ),
            ),
          const SizedBox(height: 14),
          Text(
            '${l10n.receptionLines} (${lines.length})',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          ...lines.whereType<Map>().map(_lineDetails),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${l10n.totalHt}: ${_number(receptionNumber(reception['totalHt']))} TND',
                  ),
                  Text(
                    '${l10n.vat}: ${_number(receptionNumber(reception['totalVat']))} TND',
                  ),
                  Text(
                    '${l10n.totalTtc}: ${_number(receptionNumber(reception['totalTtc']))} TND',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
          if (canConfirm) ...[
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _confirming ? null : _confirm,
              icon: _confirming
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.inventory_rounded),
              label: Text(
                _confirming ? l10n.postingStock : l10n.confirmPostStock,
              ),
            ),
          ],
          const SizedBox(height: 28),
        ],
      ),
    );
  }

  Widget _lineDetails(Map<dynamic, dynamic> line) {
    final l10n = AppLocalizations.of(context)!;
    final damaged = receptionNumber(line['damagedQty']);
    final rejected = receptionNumber(line['rejectedQty']);
    final hasDiscrepancy = damaged > 0 || rejected > 0;
    return Card(
      color:
          hasDiscrepancy ? Theme.of(context).colorScheme.errorContainer : null,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${line['name'] ?? ''}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text('${line['code'] ?? ''} • ${line['unit'] ?? ''}'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 6,
              children: [
                Text('${l10n.received} '
                    '${_number(receptionNumber(line['qty']))}'),
                Text(
                  '${l10n.accepted} '
                  '${_number(receptionNumber(line['acceptedQty']))}',
                ),
                Text('${l10n.damaged} ${_number(damaged)}'),
                Text('${l10n.rejected} ${_number(rejected)}'),
              ],
            ),
            if ('${line['discrepancyReason'] ?? ''}'.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('${line['discrepancyReason']}'),
            ],
          ],
        ),
      ),
    );
  }

  Widget _detailTile(IconData icon, String title, String value) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(value.trim().isEmpty ? '-' : value),
    );
  }

  static String _number(double value) =>
      value.toStringAsFixed(3).replaceFirst(RegExp(r'\.?0+$'), '');
}
