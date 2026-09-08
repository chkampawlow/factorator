import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:my_app/core/access_scope.dart';
import 'package:my_app/core/app_notification.dart';
import 'package:my_app/core/document_center_models.dart';
import 'package:my_app/core/permission_service.dart';
import 'package:my_app/l10n/app_localizations.dart';
import 'package:my_app/l10n/mobile_labels.dart';
import 'package:my_app/screens/document_center_screen.dart';
import 'package:my_app/screens/products_screen.dart';
import 'package:my_app/storage/notifications_repo.dart';
import 'package:my_app/widgets/app_alerts.dart';
import 'package:my_app/widgets/app_top_bar.dart';

class NotificationCenterScreen extends StatefulWidget {
  const NotificationCenterScreen({
    super.key,
    required this.permissions,
    required this.onToggleTheme,
    required this.onChangePrimaryColor,
    required this.onChangeLanguage,
    required this.currentPrimaryColor,
  });

  final PermissionService permissions;
  final VoidCallback onToggleTheme;
  final void Function(Color color) onChangePrimaryColor;
  final void Function(String code) onChangeLanguage;
  final Color currentPrimaryColor;

  @override
  State<NotificationCenterScreen> createState() =>
      _NotificationCenterScreenState();
}

class _NotificationCenterScreenState extends State<NotificationCenterScreen> {
  final _repo = NotificationsRepo();
  final _search = TextEditingController();
  List<AppNotification> _items = [];
  Map<String, int> _categoryCounts = {};
  NotificationReadFilter _readFilter = NotificationReadFilter.all;
  String _category = '';
  String? _error;
  bool _loading = true;
  bool _markingAll = false;
  int _unread = 0;

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
      final page = await _repo.list(
        search: _search.text,
        category: _category,
        read: _readFilter,
      );
      if (!mounted) return;
      setState(() {
        _items = page.items;
        _categoryCounts = page.categoryCounts;
        _unread = page.unread;
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

  Future<bool> _setRead(AppNotification item, bool read) async {
    final index = _items.indexWhere((candidate) => candidate.key == item.key);
    if (index < 0 || item.isRead == read) return true;
    final previousUnread = _unread;
    setState(() {
      _items[index] = item.copyWith(
        isRead: read,
        readAt: read ? DateTime.now().toIso8601String() : '',
      );
      _unread = (_unread + (read ? -1 : 1)).clamp(0, 1000000);
      if ((_readFilter == NotificationReadFilter.unread && read) ||
          (_readFilter == NotificationReadFilter.read && !read)) {
        _items.removeAt(index);
      }
    });
    try {
      final unread = await _repo.setRead(item.key, read);
      if (mounted) setState(() => _unread = unread);
      return true;
    } catch (error) {
      if (!mounted) return false;
      setState(() => _unread = previousUnread);
      AppAlerts.error(
        context,
        error.toString().replaceFirst('Exception: ', ''),
      );
      await _load();
      return false;
    }
  }

  Future<void> _markAllRead() async {
    if (_markingAll || _unread == 0) return;
    setState(() => _markingAll = true);
    try {
      final unread = await _repo.markAllRead();
      if (!mounted) return;
      setState(() {
        _unread = unread;
        _items = _readFilter == NotificationReadFilter.unread
            ? []
            : _items
                .map((item) => item.copyWith(
                      isRead: true,
                      readAt: DateTime.now().toIso8601String(),
                    ))
                .toList();
      });
      AppAlerts.success(
        context,
        AppLocalizations.of(context)!.allNotificationsRead,
      );
    } catch (error) {
      if (!mounted) return;
      AppAlerts.error(
        context,
        error.toString().replaceFirst('Exception: ', ''),
      );
    } finally {
      if (mounted) setState(() => _markingAll = false);
    }
  }

  Future<void> _open(AppNotification item) async {
    if (!item.isRead) await _setRead(item, true);
    if (!mounted) return;
    if (item.entityType == 'PRODUCT') {
      final attention = '${item.filters['attention'] ?? 'all'}';
      await Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) => AccessScope(
            permissions: widget.permissions,
            child: ProductsScreen(
              onToggleTheme: widget.onToggleTheme,
              onChangePrimaryColor: widget.onChangePrimaryColor,
              onChangeLanguage: widget.onChangeLanguage,
              currentPrimaryColor: widget.currentPrimaryColor,
              initialFilter: attention,
              initialQuery: item.entityNumber,
            ),
          ),
        ),
      );
      return;
    }

    final kind = _documentKind(item.entityType);
    if (kind == null || item.entityId <= 0) {
      AppAlerts.info(
        context,
        AppLocalizations.of(context)!.notificationNoDestination,
      );
      return;
    }
    if (!canViewDocumentKind(widget.permissions, kind)) {
      AppAlerts.error(
        context,
        AppLocalizations.of(context)!.cannotViewDocument,
      );
      return;
    }
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => DocumentDetailScreen(
          permissions: widget.permissions,
          document: MobileDocument(
            id: item.entityId,
            kind: kind,
            number: item.entityNumber,
            party: '',
            status: item.status,
            date: item.occurredAt,
            total: 0,
            currency: 'TND',
            raw: const {},
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppTopBar(
        title: l10n.notificationsTitle,
        actions: [
          IconButton(
            tooltip: l10n.markAllRead,
            onPressed: _unread == 0 || _markingAll ? null : _markAllRead,
            icon: _markingAll
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.done_all_rounded),
          ),
        ],
        onToggleTheme: widget.onToggleTheme,
        onChangePrimaryColor: widget.onChangePrimaryColor,
        onChangeLanguage: widget.onChangeLanguage,
        currentPrimaryColor: widget.currentPrimaryColor,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _search,
                        textInputAction: TextInputAction.search,
                        onSubmitted: (_) => _load(),
                        decoration: InputDecoration(
                          hintText: l10n.searchNotifications,
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: IconButton(
                            onPressed: _load,
                            icon: const Icon(Icons.arrow_forward),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Semantics(
                      label: '${l10n.unreadNotifications}: $_unread',
                      child: Badge(
                        isLabelVisible: _unread > 0,
                        label: Text('$_unread'),
                        child: const Icon(Icons.notifications_active_outlined),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 42,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: NotificationReadFilter.values
                      .map((filter) => Padding(
                            padding: const EdgeInsetsDirectional.only(end: 8),
                            child: ChoiceChip(
                              label: Text(_readFilterLabel(filter, l10n)),
                              selected: _readFilter == filter,
                              onSelected: (_) {
                                setState(() => _readFilter = filter);
                                _load();
                              },
                            ),
                          ))
                      .toList(),
                ),
              ),
              if (_categoryCounts.isNotEmpty) ...[
                const SizedBox(height: 6),
                SizedBox(
                  height: 42,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      Padding(
                        padding: const EdgeInsetsDirectional.only(end: 8),
                        child: FilterChip(
                          label: Text(l10n.allAreas),
                          selected: _category.isEmpty,
                          onSelected: (_) {
                            setState(() => _category = '');
                            _load();
                          },
                        ),
                      ),
                      ..._categoryCounts.entries.map(
                        (entry) => Padding(
                          padding: const EdgeInsetsDirectional.only(end: 8),
                          child: FilterChip(
                            avatar: Icon(_categoryIcon(entry.key), size: 17),
                            label: Text(
                                '${_categoryLabel(entry.key, l10n)} (${entry.value})'),
                            selected: _category == entry.key,
                            onSelected: (_) {
                              setState(() => _category = entry.key);
                              _load();
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 6),
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
          padding: const EdgeInsets.all(28),
          children: [
            const SizedBox(height: 100),
            const Icon(Icons.notifications_off_outlined, size: 56),
            const SizedBox(height: 14),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 14),
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
    if (_items.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(28),
          children: [
            const SizedBox(height: 100),
            const Icon(Icons.notifications_none_rounded, size: 58),
            const SizedBox(height: 14),
            Text(l10n.nothingNeedsAttention, textAlign: TextAlign.center),
          ],
        ),
      );
    }
    final colors = Theme.of(context).colorScheme;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 28),
        itemCount: _items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 6),
        itemBuilder: (context, index) {
          final item = _items[index];
          final color = _severityColor(context, item.severity);
          return Card(
            color: item.isRead
                ? null
                : colors.primaryContainer.withValues(alpha: .22),
            child: ListTile(
              leading: Stack(
                clipBehavior: Clip.none,
                children: [
                  CircleAvatar(
                    backgroundColor: color.withValues(alpha: .14),
                    foregroundColor: color,
                    child: Icon(_categoryIcon(item.category)),
                  ),
                  if (!item.isRead)
                    PositionedDirectional(
                      end: -2,
                      top: -2,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: colors.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: colors.surface, width: 2),
                        ),
                      ),
                    ),
                ],
              ),
              title: Text(
                _notificationTitle(item, l10n),
                style: TextStyle(
                  fontWeight: item.isRead ? FontWeight.w500 : FontWeight.w800,
                ),
              ),
              subtitle: Text(
                '${_notificationBody(item, l10n)}\n'
                '${_formatDate(item.occurredAt, l10n)}',
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              isThreeLine: true,
              trailing: PopupMenuButton<bool>(
                tooltip: l10n.notificationOptions,
                onSelected: (read) => _setRead(item, read),
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: !item.isRead,
                    child: Row(
                      children: [
                        Icon(item.isRead
                            ? Icons.mark_email_unread_outlined
                            : Icons.mark_email_read_outlined),
                        const SizedBox(width: 10),
                        Text(item.isRead ? l10n.markUnread : l10n.markRead),
                      ],
                    ),
                  ),
                ],
              ),
              onTap: () => _open(item),
            ),
          );
        },
      ),
    );
  }
}

DocumentKind? _documentKind(String entityType) => switch (entityType) {
      'INVOICE' => DocumentKind.invoice,
      'QUOTATION' => DocumentKind.quotation,
      'CREDIT_NOTE' => DocumentKind.creditNote,
      'SALES_ORDER' => DocumentKind.salesOrder,
      'DELIVERY_NOTE' => DocumentKind.deliveryNote,
      'SUPPLIER_ORDER' => DocumentKind.supplierOrder,
      'SUPPLIER_RECEPTION' => DocumentKind.supplierReception,
      'SUPPLIER_INVOICE' => DocumentKind.supplierInvoice,
      'EXPENSE' => DocumentKind.expense,
      _ => null,
    };

Color _severityColor(BuildContext context, NotificationSeverity severity) =>
    switch (severity) {
      NotificationSeverity.info => Theme.of(context).colorScheme.primary,
      NotificationSeverity.warning => Colors.orange.shade700,
      NotificationSeverity.critical => Theme.of(context).colorScheme.error,
    };

IconData _categoryIcon(String category) => switch (category) {
      'SALES' => Icons.trending_up_rounded,
      'STOCK' => Icons.inventory_2_outlined,
      'LOGISTICS' => Icons.local_shipping_outlined,
      'PURCHASING' => Icons.shopping_cart_outlined,
      'ACCOUNTING' => Icons.account_balance_wallet_outlined,
      _ => Icons.notifications_outlined,
    };

String _readFilterLabel(
  NotificationReadFilter filter,
  AppLocalizations l10n,
) =>
    switch (filter) {
      NotificationReadFilter.all => l10n.all,
      NotificationReadFilter.unread => l10n.unread,
      NotificationReadFilter.read => l10n.read,
    };

String _categoryLabel(String category, AppLocalizations l10n) =>
    switch (category) {
      'SALES' => l10n.salesArea,
      'STOCK' => l10n.stockArea,
      'LOGISTICS' => l10n.logisticsArea,
      'PURCHASING' => l10n.purchasingArea,
      'ACCOUNTING' => l10n.accountingArea,
      _ => category,
    };

String _formatDate(String value, AppLocalizations l10n) {
  final date = DateTime.tryParse(value);
  if (date == null) return value;
  final now = DateTime.now();
  final day = DateTime(date.year, date.month, date.day);
  final today = DateTime(now.year, now.month, now.day);
  if (day == today) {
    return '${l10n.today} · ${DateFormat('HH:mm', l10n.localeName).format(date)}';
  }
  if (day == today.subtract(const Duration(days: 1))) {
    return '${l10n.yesterday} · ${DateFormat('HH:mm', l10n.localeName).format(date)}';
  }
  return DateFormat('dd MMM yyyy', l10n.localeName).format(date);
}

String _notificationTitle(AppNotification item, AppLocalizations l10n) =>
    switch (item.type) {
      'OVERDUE_INVOICE' =>
        '${l10n.kindInvoice} ${item.entityNumber} · ${l10n.overdue}',
      'QUOTATION_FOLLOWUP' =>
        '${l10n.kindQuotation} ${item.entityNumber} · ${l10n.reviewTab}',
      'ORDER_READY' =>
        '${l10n.kindSalesOrder} ${item.entityNumber} · ${l10n.statusConfirmed}',
      'LOW_STOCK' => '${l10n.stockArea} · ${item.entityNumber}',
      'PRODUCT_PRICING' =>
        '${l10n.product} ${item.entityNumber} · ${l10n.price}',
      'DELIVERY_PENDING' => '${l10n.deliveryLabel} ${item.entityNumber} · '
          '${localizedWorkflowStatus(l10n, item.status)}',
      'SUPPLIER_ORDER_EXPECTED' => '${l10n.purchaseOrder} ${item.entityNumber}',
      'RECEPTION_DISCREPANCY' =>
        '${l10n.receptionLabel} ${item.entityNumber} · ${l10n.exception}',
      'RECEPTION_PENDING' =>
        '${l10n.receptionLabel} ${item.entityNumber} · ${l10n.pending}',
      'EXPENSE_REVIEW' => '${l10n.expenseReview}: ${item.entityNumber}',
      'SUPPLIER_INVOICE_DUE' =>
        '${l10n.supplierInvoice} ${item.entityNumber} · ${l10n.due}',
      _ => item.title,
    };

String _notificationBody(AppNotification item, AppLocalizations l10n) =>
    switch (item.type) {
      'LOW_STOCK' => '${l10n.stockArea} · ${l10n.needsAttention}',
      'PRODUCT_PRICING' => '${l10n.price} · ${l10n.pending}',
      'OVERDUE_INVOICE' => '${l10n.kindInvoice} · ${l10n.overdue}',
      'QUOTATION_FOLLOWUP' when item.body.startsWith('Quotation sent') =>
        localizedWorkflowStatus(l10n, 'SENT'),
      _ => item.body,
    };
