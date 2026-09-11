import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:my_app/core/access_scope.dart';
import 'package:my_app/core/permission_service.dart';
import 'package:my_app/l10n/app_localizations.dart';
import 'package:my_app/screens/add_client_screen.dart';
import 'package:my_app/screens/add_product_screen.dart';
import 'package:my_app/screens/capture_extractor_screen.dart';
import 'package:my_app/screens/create_expense_note_screen.dart';
import 'package:my_app/screens/invoice_edit_screen.dart';
import 'package:my_app/screens/invoices_screen.dart';
import 'package:my_app/screens/notification_center_screen.dart';
import 'package:my_app/screens/products_screen.dart';
import 'package:my_app/screens/global_search_screen.dart';
import 'package:my_app/screens/supplier_receptions_screen.dart';

import '../storage/invoices_repo.dart';

import 'package:my_app/services/currency_service.dart';
import '../services/settings_service.dart';
import '../storage/clients_repo.dart';
import '../storage/dashboard_repo.dart';
import '../widgets/action_tile.dart';
import '../widgets/app_alerts.dart';
import '../widgets/app_top_bar.dart';

enum _ExpenseEntryMode { manual, scan }

class DashboardScreen extends StatefulWidget {
  final PermissionService permissions;
  final VoidCallback onToggleTheme;
  final void Function(Color color) onChangePrimaryColor;
  final void Function(String code) onChangeLanguage;
  final Color currentPrimaryColor;

  const DashboardScreen({
    super.key,
    required this.permissions,
    required this.onToggleTheme,
    required this.onChangePrimaryColor,
    required this.onChangeLanguage,
    required this.currentPrimaryColor,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _repo = DashboardRepo();
  final _clientsRepo = ClientsRepo();
  final _settingsService = SettingsService();
  final _invoicesRepo = InvoicesRepo();

  bool _loading = true;
  String? _loadError;

  int _customersCount = 0;
  String _currency = 'TND';
  double _monthlyExpenses = 0;
  int _paidCount = 0;
  int _unpaidCount = 0;
  List<double> _monthlyRevenue = List.filled(6, 0);
  List<double> _chartRevenue = [];
  List<String> _chartMonths = [];
  double _paymentRate = 0;

  double _avgInvoice = 0;
  List<MapEntry<String, double>> _topClients = [];
  List<Map<String, dynamic>> _recentDocuments = [];
  List<Map<String, dynamic>> _attention = [];
  List<Map<String, dynamic>> _lowStock = [];
  List<MapEntry<String, double>> _topProducts = [];
  Map<String, dynamic> _notificationCounts = {};
  int _productCount = 0;
  int _lowStockCount = 0;
  int _zeroStockCount = 0;
  int _pendingSupplierOrders = 0;

  bool _didLoadOnce = false;

  PermissionService get _permissions => widget.permissions;
  AppRole get _role => _permissions.role;
  bool get _showsFinancialPerformance =>
      _role == AppRole.administrator ||
      _role == AppRole.commercial ||
      _role == AppRole.accounting;
  bool get _showsInventoryPerformance =>
      _role == AppRole.stock || _role == AppRole.administrator;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didLoadOnce) {
      _didLoadOnce = true;
      _load();
    }
  }

  Future<int> _countCustomers() async {
    final clients = await _clientsRepo.getAllClients();
    return clients.length;
  }

  Future<Map<String, dynamic>?> _pickClientForNewInvoice() async {
    return showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _DashboardClientPickerSheet(clientsRepo: _clientsRepo),
    );
  }

  Future<void> _createInvoiceAndOpenEditor() async {
    if (!_requirePermission(AppPermission.invoicesCreate)) return;
    final l10n = AppLocalizations.of(context)!;

    final selectedClient = await _pickClientForNewInvoice();
    if (!mounted) return;

    if (selectedClient == null) {
      // Either no clients or user dismissed
      return;
    }

    final clientId =
        int.tryParse((selectedClient['id'] ?? '0').toString()) ?? 0;
    if (clientId <= 0) return;

    try {
      final now = DateTime.now();
      final draftId = await _invoicesRepo.createInvoiceHeader(
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
          builder: (_) => AccessScope(
            permissions: _permissions,
            child: InvoiceEditScreen(
              invoiceId: draftId,
              onToggleTheme: widget.onToggleTheme,
              onChangePrimaryColor: widget.onChangePrimaryColor,
              onChangeLanguage: widget.onChangeLanguage,
              currentPrimaryColor: widget.currentPrimaryColor,
            ),
          ),
        ),
      );

      if (!mounted) return;
      await _load();
    } catch (e) {
      if (!mounted) return;
      // Keep it simple: show backend message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                '${l10n.saveFailed}: ${e.toString().replaceFirst('Exception: ', '')}')),
      );
    }
  }

  double _number(dynamic value) =>
      value is num ? value.toDouble() : double.tryParse('$value') ?? 0;

  int _integer(dynamic value) =>
      value is int ? value : int.tryParse('$value') ?? 0;

  Map<String, dynamic> _map(dynamic value) =>
      value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

  void _applyOverview(Map<String, dynamic> overview) {
    final invoice = _map(overview['invoice']);
    final sales = _map(overview['sales']);
    final accounting = _map(overview['accounting']);
    final inventory = _map(overview['inventory']);
    final workflow = _map(overview['workflow']);
    final source = sales.isNotEmpty
        ? sales
        : accounting.isNotEmpty
            ? accounting
            : invoice;

    _paidCount = _integer(source['paid_count']);
    _unpaidCount =
        _integer(source['unpaid_count']) + _integer(source['overdue_count']);
    final invoiceCount = _integer(source['invoice_count']);
    final totalRevenue = _number(source['revenue_total']);
    final monthlyRevenue = _number(source['monthly_revenue']);
    final rawMonthlySeries = overview['monthly_series'];
    final monthlyRows = rawMonthlySeries is List
        ? rawMonthlySeries
            .whereType<Map>()
            .map((row) => Map<String, dynamic>.from(row))
            .toList()
        : <Map<String, dynamic>>[];
    final monthlySeries =
        monthlyRows.map((row) => _number(row['revenue'])).toList();
    _monthlyExpenses = _number(
      accounting['monthly_expenses'] ?? overview['monthly_expenses'],
    );
    _monthlyRevenue =
        monthlySeries.isEmpty ? <double>[monthlyRevenue] : monthlySeries;
    _chartRevenue = List<double>.from(_monthlyRevenue);
    _chartMonths = monthlyRows.map((row) => '${row['month'] ?? ''}').toList();
    _paymentRate = invoiceCount == 0 ? 0 : (_paidCount / invoiceCount) * 100;
    _avgInvoice = invoiceCount == 0 ? 0 : totalRevenue / invoiceCount;

    final rawTopClients = overview['top_clients'];
    _topClients = rawTopClients is List
        ? rawTopClients
            .whereType<Map>()
            .map((row) => Map<String, dynamic>.from(row))
            .map((row) => MapEntry(
                  (row['label'] ?? '').toString(),
                  _number(row['value']),
                ))
            .where((entry) => entry.key.isNotEmpty)
            .take(3)
            .toList()
        : [];
    final rawRecent = overview['recent_invoices'] ?? source['recent_invoices'];
    _recentDocuments = rawRecent is List
        ? rawRecent
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .take(5)
            .toList()
        : [];
    final rawAttention = overview['attention'];
    _attention = rawAttention is List
        ? rawAttention
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList()
        : [];

    _productCount = _integer(inventory['product_count']);
    _lowStockCount = _integer(
      inventory['low_stock_count'] ?? overview['low_stock_count'],
    );
    _zeroStockCount = _integer(inventory['zero_stock_count']);
    _pendingSupplierOrders = _integer(
      inventory['pending_supplier_orders'] ??
          workflow['pending_supplier_orders'],
    );
    final rawLowStock = inventory['low_stock'] ?? overview['low_stock'];
    _lowStock = rawLowStock is List
        ? rawLowStock
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .take(5)
            .toList()
        : [];

    final rawTopProducts =
        inventory['top_products'] ?? overview['top_products'];
    _topProducts = rawTopProducts is List
        ? rawTopProducts
            .whereType<Map>()
            .map((row) => Map<String, dynamic>.from(row))
            .map(
              (row) => MapEntry(
                (row['label'] ?? '').toString(),
                _number(row['value']),
              ),
            )
            .where((entry) => entry.key.isNotEmpty)
            .take(5)
            .toList()
        : [];
  }

  String _attentionLabel(String type) {
    final language = Localizations.localeOf(context).languageCode;
    if (language == 'fr') {
      return switch (type) {
        'OVERDUE_INVOICES' => 'Factures en retard',
        'ACCEPTED_DEVIS' => 'Devis acceptés',
        'DELIVERIES_TO_INVOICE' => 'Livraisons prêtes à facturer',
        'INVOICE_DRAFTS' => 'Brouillons à compléter',
        'LOW_STOCK' => 'Stock faible',
        'ZERO_STOCK' || 'OUT_OF_STOCK' => 'Rupture de stock',
        'PRODUCT_PRICING_REQUIRED' => 'Prix de vente manquants',
        'PENDING_SUPPLIER_ORDERS' ||
        'SUPPLIER_ORDERS_PENDING' =>
          'Commandes fournisseur en attente',
        'PENDING_RECEPTIONS' => 'Réceptions en attente',
        'PENDING_INVITATIONS' => 'Invitations en attente',
        _ => type.replaceAll('_', ' ').toLowerCase(),
      };
    }
    if (language == 'ar') {
      return switch (type) {
        'OVERDUE_INVOICES' => 'فواتير متأخرة',
        'ACCEPTED_DEVIS' => 'عروض أسعار مقبولة',
        'DELIVERIES_TO_INVOICE' => 'تسليمات جاهزة للفوترة',
        'INVOICE_DRAFTS' => 'مسودات تحتاج إلى إكمال',
        'LOW_STOCK' => 'مخزون منخفض',
        'ZERO_STOCK' || 'OUT_OF_STOCK' => 'نفاد المخزون',
        'PRODUCT_PRICING_REQUIRED' => 'منتجات دون سعر بيع',
        'PENDING_SUPPLIER_ORDERS' ||
        'SUPPLIER_ORDERS_PENDING' =>
          'طلبات موردين معلقة',
        'PENDING_RECEPTIONS' => 'عمليات استلام معلقة',
        'PENDING_INVITATIONS' => 'دعوات معلقة',
        _ => type.replaceAll('_', ' ').toLowerCase(),
      };
    }
    return switch (type) {
      'OVERDUE_INVOICES' => 'Overdue invoices',
      'ACCEPTED_DEVIS' => 'Accepted quotations to process',
      'DELIVERIES_TO_INVOICE' => 'Deliveries ready to invoice',
      'INVOICE_DRAFTS' => 'Invoice drafts to complete',
      'LOW_STOCK' => 'Low-stock products',
      'ZERO_STOCK' || 'OUT_OF_STOCK' => 'Out-of-stock products',
      'PRODUCT_PRICING_REQUIRED' => 'Products requiring a selling price',
      'PENDING_SUPPLIER_ORDERS' ||
      'SUPPLIER_ORDERS_PENDING' =>
        'Pending supplier orders',
      'PENDING_RECEPTIONS' => 'Pending supplier receptions',
      'PENDING_INVITATIONS' => 'Pending invitations',
      _ => type.replaceAll('_', ' ').toLowerCase(),
    };
  }

  String _performanceLabel(String localeName) => switch (localeName) {
        'fr' when _role == AppRole.stock => 'Aperçu du stock',
        'ar' when _role == AppRole.stock => 'نظرة عامة على المخزون',
        _ when _role == AppRole.stock => 'Inventory overview',
        'fr' when _role == AppRole.accounting => 'Aperçu financier',
        'ar' when _role == AppRole.accounting => 'نظرة مالية عامة',
        _ when _role == AppRole.accounting => 'Financial overview',
        'fr' when _role == AppRole.commercial => 'Performance commerciale',
        'ar' when _role == AppRole.commercial => 'أداء المبيعات',
        _ when _role == AppRole.commercial => 'Sales performance',
        'fr' => 'Performance globale',
        'ar' => 'الأداء العام',
        _ => 'Business performance',
      };

  String _roleLabel(String key, String localeName) {
    const labels = {
      'en': {
        'products': 'Products',
        'low_stock': 'Low stock',
        'out_of_stock': 'Out of stock',
        'pending_orders': 'Pending supplier orders',
        'paid_invoices': 'Paid invoices',
        'unpaid_invoices': 'Unpaid invoices',
        'inventory_activity': 'Inventory activity',
        'top_products': 'Top products',
        'units_sold': 'units sold',
      },
      'fr': {
        'products': 'Produits',
        'low_stock': 'Stock faible',
        'out_of_stock': 'Rupture de stock',
        'pending_orders': 'Commandes fournisseur',
        'paid_invoices': 'Factures payées',
        'unpaid_invoices': 'Factures impayées',
        'inventory_activity': 'Activité du stock',
        'top_products': 'Meilleurs produits',
        'units_sold': 'unités vendues',
      },
      'ar': {
        'products': 'المنتجات',
        'low_stock': 'مخزون منخفض',
        'out_of_stock': 'نفاد المخزون',
        'pending_orders': 'طلبات الموردين المعلقة',
        'paid_invoices': 'الفواتير المدفوعة',
        'unpaid_invoices': 'الفواتير غير المدفوعة',
        'inventory_activity': 'حركة المخزون',
        'top_products': 'أفضل المنتجات',
        'units_sold': 'وحدة مباعة',
      },
    };
    final language = labels.containsKey(localeName) ? localeName : 'en';
    return labels[language]![key] ?? key;
  }

  String _recentDocumentsLabel(String localeName) => switch (localeName) {
        'fr' => 'Documents récents',
        'ar' => 'المستندات الأخيرة',
        _ => 'Recent documents',
      };

  String _tipTitle(String localeName) => switch (localeName) {
        'fr' => 'Astuce du jour',
        'ar' => 'نصيحة اليوم',
        _ => 'Tip of the day',
      };

  String _tipBody(String localeName) => switch (localeName) {
        'fr' when _role == AppRole.stock =>
          'Traitez d’abord les ruptures et les produits sous le seuil de réapprovisionnement.',
        'ar' when _role == AppRole.stock =>
          'ابدأ بمعالجة المنتجات النافدة وتلك التي تقل عن حد إعادة الطلب.',
        _ when _role == AppRole.stock =>
          'Start with out-of-stock items and products below their reorder threshold.',
        'fr' when _role == AppRole.accounting =>
          'Contrôlez les impayés et les dépenses approuvées pour suivre votre revenu net.',
        'ar' when _role == AppRole.accounting =>
          'راجع الفواتير غير المدفوعة والمصاريف المعتمدة لمتابعة صافي الإيرادات.',
        _ when _role == AppRole.accounting =>
          'Review unpaid invoices and approved expenses to track net revenue.',
        'fr' =>
          'Relancez les factures en retard pour améliorer votre trésorerie.',
        'ar' => 'تابع الفواتير المتأخرة لتحسين التدفق النقدي.',
        _ => 'Follow up overdue invoices to improve your cash flow.',
      };

  Future<void> _openAttention(Map<String, dynamic> item) async {
    final type = '${item['type'] ?? ''}';
    if (type == 'OVERDUE_INVOICES' || type == 'INVOICE_DRAFTS') {
      await _openInvoicesWithStatus(
        type == 'OVERDUE_INVOICES' ? 'OVERDUE' : 'DRAFT',
      );
    } else if (type == 'LOW_STOCK' ||
        type == 'ZERO_STOCK' ||
        type == 'OUT_OF_STOCK' ||
        type == 'PRODUCT_PRICING_REQUIRED') {
      await _go(ProductsScreen(
        onToggleTheme: widget.onToggleTheme,
        onChangePrimaryColor: widget.onChangePrimaryColor,
        onChangeLanguage: widget.onChangeLanguage,
        currentPrimaryColor: widget.currentPrimaryColor,
        initialFilter: type == 'PRODUCT_PRICING_REQUIRED' ? 'pricing' : 'low',
      ));
    } else if (type == 'PENDING_RECEPTIONS') {
      if (!_requirePermission(AppPermission.supplierReceptionsView)) return;
      await _go(SupplierReceptionsScreen(
        onToggleTheme: widget.onToggleTheme,
        onChangePrimaryColor: widget.onChangePrimaryColor,
        onChangeLanguage: widget.onChangeLanguage,
        currentPrimaryColor: widget.currentPrimaryColor,
      ));
    }
  }

  Future<void> _showNotifications() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => NotificationCenterScreen(
          permissions: _permissions,
          onToggleTheme: widget.onToggleTheme,
          onChangePrimaryColor: widget.onChangePrimaryColor,
          onChangeLanguage: widget.onChangeLanguage,
          currentPrimaryColor: widget.currentPrimaryColor,
        ),
      ),
    );
    if (mounted) await _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });

    try {
      final results = await Future.wait([
        _repo.getOverview(),
        _repo.getNotificationCounts(),
        _can(AppPermission.clientsView) ? _countCustomers() : Future.value(0),
        _settingsService.getCurrency(),
      ]);
      final overview = results[0] as Map<String, dynamic>;
      final notifications = results[1] as Map<String, dynamic>;
      final customers = results[2] as int;
      final currency = results[3] as String;

      if (!mounted) return;

      setState(() {
        _customersCount = customers;
        _currency = currency;
        _applyOverview(overview);
        _notificationCounts = notifications;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _go(Widget page) async {
    final res = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AccessScope(
          permissions: _permissions,
          child: page,
        ),
      ),
    );
    if (res == true) await _load();
  }

  Future<void> _openRecentDocument(Map<String, dynamic> document) async {
    final id = _integer(document['id']);
    if (id <= 0) return;
    await _go(
      InvoiceEditScreen(
        invoiceId: id,
        onToggleTheme: widget.onToggleTheme,
        onChangePrimaryColor: widget.onChangePrimaryColor,
        onChangeLanguage: widget.onChangeLanguage,
        currentPrimaryColor: widget.currentPrimaryColor,
      ),
    );
  }

  Future<void> _openAddClient() async {
    if (!_requirePermission(AppPermission.clientsCreate)) return;
    await _go(const AddClientScreen());
  }

  Future<void> _openNewExpenseOptions() async {
    if (!_requirePermission(AppPermission.expensesCreate)) return;
    final l10n = AppLocalizations.of(context)!;

    final mode = await showModalBottomSheet<_ExpenseEntryMode>(
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
                  l10n.createExpenseNoteTitle,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: const Icon(Icons.edit_note_rounded),
                  title: const Text('Enter manually'),
                  subtitle: Text(l10n.createExpenseNoteSubtitle),
                  onTap: () => Navigator.pop(context, _ExpenseEntryMode.manual),
                ),
                const SizedBox(height: 8),
                ListTile(
                  leading: const Icon(Icons.document_scanner_outlined),
                  title: Text(l10n.scanInvoiceTitle),
                  subtitle: Text(l10n.scanInvoiceSubtitle),
                  onTap: () => Navigator.pop(context, _ExpenseEntryMode.scan),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted || mode == null) return;

    switch (mode) {
      case _ExpenseEntryMode.manual:
        await _go(const CreateExpenseNoteScreen());
        break;
      case _ExpenseEntryMode.scan:
        await _go(
          CaptureExtractorScreen(
            onToggleTheme: widget.onToggleTheme,
            onChangePrimaryColor: widget.onChangePrimaryColor,
            onChangeLanguage: widget.onChangeLanguage,
            currentPrimaryColor: widget.currentPrimaryColor,
            permissions: _permissions,
          ),
        );
        break;
    }
  }

  Future<void> _openInvoicesWithStatus(String status) async {
    if (!_permissions.canViewFeature(AppFeature.invoices)) {
      AppAlerts.error(context, 'You do not have permission for this action.');
      return;
    }
    // Open invoices list and pass initialStatus as a constructor parameter.
    final res = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AccessScope(
          permissions: _permissions,
          child: InvoicesScreen(
            initialStatus: status,
            onToggleTheme: widget.onToggleTheme,
            onChangePrimaryColor: widget.onChangePrimaryColor,
            onChangeLanguage: widget.onChangeLanguage,
            currentPrimaryColor: widget.currentPrimaryColor,
          ),
        ),
      ),
    );
    if (!mounted) return;
    if (res == true) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final screenWidth = MediaQuery.of(context).size.width;
    final stackCharts = screenWidth < 700;
    final quickActions = <Widget>[
      if (_can(AppPermission.invoicesCreate))
        ActionTile(
          label: l10n.createInvoice,
          icon: Icons.add_circle_outline,
          bg: cs.primary,
          fg: cs.onPrimary,
          onTap: _createInvoiceAndOpenEditor,
        ),
      if (_can(AppPermission.expensesCreate))
        ActionTile(
          label: l10n.createExpenseNoteTitle,
          icon: Icons.account_balance_wallet_outlined,
          bg: cs.secondary,
          onTap: _openNewExpenseOptions,
        ),
      if (_can(AppPermission.clientsCreate))
        ActionTile(
          label: l10n.newCustomer,
          icon: Icons.person_add_alt_1_outlined,
          bg: const Color(0xFF8B5CF6),
          fg: cs.onSecondary,
          onTap: _openAddClient,
        ),
      if (_can(AppPermission.productsCreate))
        ActionTile(
          label: l10n.addProduct,
          icon: Icons.inventory_2_outlined,
          bg: cs.tertiary,
          onTap: () => _go(const AddProductScreen()),
        ),
    ];
    final topClientMax = _topClients.fold<double>(
      0,
      (maximum, entry) => math.max(maximum, entry.value),
    );
    final monthlyRevenue =
        _monthlyRevenue.isNotEmpty ? _monthlyRevenue.last : 0.0;
    final performanceItems = switch (_role) {
      AppRole.stock => <Widget>[
          _MiniStatRect(
            title: _roleLabel('products', l10n.localeName),
            value: '$_productCount',
            subtitle: '',
            icon: Icons.inventory_2_outlined,
            color: cs.primary,
          ),
          _MiniStatRect(
            title: _roleLabel('low_stock', l10n.localeName),
            value: '$_lowStockCount',
            subtitle: '',
            icon: Icons.inventory_outlined,
            color: cs.tertiary,
          ),
          _MiniStatRect(
            title: _roleLabel('out_of_stock', l10n.localeName),
            value: '$_zeroStockCount',
            subtitle: '',
            icon: Icons.warning_amber_rounded,
            color: cs.error,
          ),
          _MiniStatRect(
            title: _roleLabel('pending_orders', l10n.localeName),
            value: '$_pendingSupplierOrders',
            subtitle: '',
            icon: Icons.shopping_cart_checkout_rounded,
            color: cs.secondary,
          ),
        ],
      AppRole.accounting => <Widget>[
          _MiniStatRect(
            title: l10n.netMonthlyRevenue,
            value: CurrencyService.format(
              monthlyRevenue - _monthlyExpenses,
              _currency,
            ),
            subtitle: '',
            icon: Icons.account_balance_wallet_outlined,
            color: cs.primary,
          ),
          _MiniStatRect(
            title: l10n.monthlyRevenue,
            value: CurrencyService.format(monthlyRevenue, _currency),
            subtitle: '',
            icon: Icons.trending_up_rounded,
            color: cs.secondary,
          ),
          _MiniStatRect(
            title: l10n.monthlyExpenses,
            value: CurrencyService.format(_monthlyExpenses, _currency),
            subtitle: '',
            icon: Icons.trending_down_rounded,
            color: cs.tertiary,
          ),
          _MiniStatRect(
            title: _roleLabel('unpaid_invoices', l10n.localeName),
            value: '$_unpaidCount',
            subtitle: '',
            icon: Icons.pending_actions_rounded,
            color: cs.error,
          ),
        ],
      AppRole.commercial => <Widget>[
          _MiniStatRect(
            title: l10n.monthlyRevenue,
            value: CurrencyService.format(monthlyRevenue, _currency),
            subtitle: '',
            icon: Icons.trending_up_rounded,
            color: cs.primary,
          ),
          _MiniStatRect(
            title: l10n.averageInvoice,
            value: CurrencyService.format(_avgInvoice, _currency),
            subtitle: '',
            icon: Icons.bar_chart_rounded,
            color: cs.secondary,
          ),
          _MiniStatRect(
            title: _roleLabel('paid_invoices', l10n.localeName),
            value: '$_paidCount',
            subtitle: '',
            icon: Icons.task_alt_rounded,
            color: cs.primary,
          ),
          _MiniStatRect(
            title: l10n.clients,
            value: '$_customersCount',
            subtitle: '',
            icon: Icons.people_alt_outlined,
            color: const Color(0xFF8B5CF6),
          ),
        ],
      _ => <Widget>[
          _MiniStatRect(
            title: l10n.netMonthlyRevenue,
            value: CurrencyService.format(
              monthlyRevenue - _monthlyExpenses,
              _currency,
            ),
            subtitle: '',
            icon: Icons.payments_outlined,
            color: cs.primary,
          ),
          _MiniStatRect(
            title: l10n.monthlyRevenue,
            value: CurrencyService.format(monthlyRevenue, _currency),
            subtitle: '',
            icon: Icons.trending_up_rounded,
            color: cs.secondary,
          ),
          _MiniStatRect(
            title: l10n.averageInvoice,
            value: CurrencyService.format(_avgInvoice, _currency),
            subtitle: '',
            icon: Icons.bar_chart_rounded,
            color: cs.tertiary,
          ),
          _MiniStatRect(
            title: l10n.clients,
            value: '$_customersCount',
            subtitle: '',
            icon: Icons.people_alt_outlined,
            color: const Color(0xFF8B5CF6),
          ),
        ],
    };

    return Scaffold(
      appBar: AppTopBar(
        title: 'El Fatoura',
        actions: [
          IconButton(
            tooltip: 'Notifications',
            icon: Badge(
              isLabelVisible: _integer(
                    _notificationCounts['unread_count'] ??
                        _notificationCounts['unread'],
                  ) >
                  0,
              label: Text('${_integer(
                _notificationCounts['unread_count'] ??
                    _notificationCounts['unread'],
              )}'),
              child: const Icon(Icons.notifications_outlined),
            ),
            onPressed: _showNotifications,
          ),
        ],
        onToggleTheme: widget.onToggleTheme,
        onChangePrimaryColor: widget.onChangePrimaryColor,
        onChangeLanguage: widget.onChangeLanguage,
        currentPrimaryColor: widget.currentPrimaryColor,
      ),
      body: _loading
          ? const _DashboardLoading()
          : _loadError != null
              ? RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(24),
                    children: [
                      const SizedBox(height: 120),
                      Icon(Icons.cloud_off_rounded, size: 54, color: cs.error),
                      const SizedBox(height: 16),
                      Text(
                        '${l10n.loadFailed}: $_loadError',
                        textAlign: TextAlign.center,
                        style: t.titleMedium,
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: FilledButton.icon(
                          onPressed: _load,
                          icon: const Icon(Icons.refresh),
                          label: Text(l10n.retry),
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: EdgeInsets.zero,
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1080),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _DashboardSearch(
                                  onSearch: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => GlobalSearchScreen(
                                          permissions: _permissions,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(height: 22),
                                Text(
                                  _performanceLabel(l10n.localeName),
                                  style: t.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 10),
                                // ===== SUMMARY (non-clickable) =====
                                LayoutBuilder(
                                  builder: (context, c) {
                                    final isNarrow = c.maxWidth < 720;

                                    final items = performanceItems;

                                    if (isNarrow) {
                                      return GridView.count(
                                        shrinkWrap: true,
                                        physics:
                                            const NeverScrollableScrollPhysics(),
                                        crossAxisCount: 2,
                                        mainAxisSpacing: 10,
                                        crossAxisSpacing: 10,
                                        childAspectRatio:
                                            c.maxWidth < 380 ? 1.45 : 1.62,
                                        children: items,
                                      );
                                    }

                                    return Row(
                                      children: [
                                        Expanded(child: items[0]),
                                        const SizedBox(width: 10),
                                        Expanded(child: items[1]),
                                        const SizedBox(width: 10),
                                        Expanded(child: items[2]),
                                        const SizedBox(width: 10),
                                        Expanded(child: items[3]),
                                      ],
                                    );
                                  },
                                ),
                                const SizedBox(height: 18),

                                if (quickActions.isNotEmpty) ...[
                                  Text(
                                    l10n.quickActions,
                                    style: t.titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                  const SizedBox(height: 10),
                                  GridView.count(
                                    shrinkWrap: true,
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    crossAxisCount: screenWidth < 620 ? 2 : 4,
                                    mainAxisSpacing: 10,
                                    crossAxisSpacing: 10,
                                    childAspectRatio:
                                        screenWidth < 420 ? 1.65 : 2.15,
                                    children: quickActions,
                                  ),
                                  const SizedBox(height: 18),
                                ],

                                if (_recentDocuments.isNotEmpty) ...[
                                  Text(
                                    _recentDocumentsLabel(l10n.localeName),
                                    style: t.titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                  const SizedBox(height: 8),
                                  _RecentDocumentsCard(
                                    documents: _recentDocuments,
                                    currency: _currency,
                                    onTap: _openRecentDocument,
                                  ),
                                  const SizedBox(height: 18),
                                ],

                                if (_attention.isNotEmpty) ...[
                                  Text(
                                    l10n.needsAttention,
                                    style: t.titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                  const SizedBox(height: 8),
                                  _DashboardAttentionCard(
                                    items: _attention,
                                    labelFor: _attentionLabel,
                                    onTap: _openAttention,
                                  ),
                                  const SizedBox(height: 18),
                                ],

                                // ===== NEW STATS SECTION =====
                                if (_topClients.isNotEmpty)
                                  Card(
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            l10n.topClients,
                                            style: t.titleSmall?.copyWith(
                                                fontWeight: FontWeight.w900),
                                          ),
                                          const SizedBox(height: 12),
                                          ..._topClients.asMap().entries.map(
                                                (entry) => _TopClientRow(
                                                  rank: entry.key + 1,
                                                  client: entry.value,
                                                  maximum: topClientMax,
                                                  currency: _currency,
                                                ),
                                              ),
                                        ],
                                      ),
                                    ),
                                  ),

                                if (_showsInventoryPerformance &&
                                    (_lowStock.isNotEmpty ||
                                        _topProducts.isNotEmpty)) ...[
                                  const SizedBox(height: 18),
                                  _InventoryActivityCard(
                                    lowStock: _lowStock,
                                    topProducts: _topProducts,
                                    title: _roleLabel(
                                      'inventory_activity',
                                      l10n.localeName,
                                    ),
                                    lowStockLabel: _roleLabel(
                                      'low_stock',
                                      l10n.localeName,
                                    ),
                                    topProductsLabel: _roleLabel(
                                      'top_products',
                                      l10n.localeName,
                                    ),
                                    unitsSoldLabel: _roleLabel(
                                      'units_sold',
                                      l10n.localeName,
                                    ),
                                  ),
                                ],

                                if (_showsFinancialPerformance) ...[
                                  const SizedBox(height: 18),
                                  stackCharts
                                      ? Column(
                                          children: [
                                            Card(
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.all(16),
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    _ChartTitleRow(
                                                      title:
                                                          l10n.monthlyRevenue,
                                                      value: CurrencyService
                                                          .format(
                                                        _chartRevenue.isEmpty
                                                            ? 0
                                                            : _chartRevenue
                                                                .last,
                                                        _currency,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 12),
                                                    SizedBox(
                                                      height: 180,
                                                      child:
                                                          _chartRevenue.isEmpty
                                                              ? Center(
                                                                  child: Text(
                                                                    l10n.noInvoicesYet,
                                                                    style: t
                                                                        .bodyMedium
                                                                        ?.copyWith(
                                                                      color: cs
                                                                          .onSurfaceVariant,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .w700,
                                                                    ),
                                                                  ),
                                                                )
                                                              : CustomPaint(
                                                                  painter:
                                                                      _RevenueLineChartPainter(
                                                                    values:
                                                                        _chartRevenue,
                                                                    labels:
                                                                        _chartMonths,
                                                                    lineColor: cs
                                                                        .primary,
                                                                    fillColor: cs
                                                                        .primary
                                                                        .withValues(
                                                                            alpha:
                                                                                0.10),
                                                                    gridColor: cs
                                                                        .outlineVariant
                                                                        .withValues(
                                                                            alpha:
                                                                                0.25),
                                                                  ),
                                                                  child: const SizedBox
                                                                      .expand(),
                                                                ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 12),
                                            Card(
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.all(16),
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      l10n.paymentRate,
                                                      style: t.titleSmall
                                                          ?.copyWith(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w900),
                                                    ),
                                                    const SizedBox(height: 12),
                                                    SizedBox(
                                                      height: 180,
                                                      child:
                                                          _PaymentRateContent(
                                                        rate: _paymentRate,
                                                        paidCount: _paidCount,
                                                        unpaidCount:
                                                            _unpaidCount,
                                                        paidLabel:
                                                            l10n.paidLabel,
                                                        unpaidLabel:
                                                            l10n.unpaidLabel,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ],
                                        )
                                      : Row(
                                          children: [
                                            Expanded(
                                              child: Card(
                                                child: Padding(
                                                  padding:
                                                      const EdgeInsets.all(16),
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      _ChartTitleRow(
                                                        title:
                                                            l10n.monthlyRevenue,
                                                        value: CurrencyService
                                                            .format(
                                                          _chartRevenue.isEmpty
                                                              ? 0
                                                              : _chartRevenue
                                                                  .last,
                                                          _currency,
                                                        ),
                                                      ),
                                                      const SizedBox(
                                                          height: 12),
                                                      SizedBox(
                                                        height: 180,
                                                        child:
                                                            _chartRevenue
                                                                    .isEmpty
                                                                ? Center(
                                                                    child: Text(
                                                                      l10n.noInvoicesYet,
                                                                      style: t
                                                                          .bodyMedium
                                                                          ?.copyWith(
                                                                        color: cs
                                                                            .onSurfaceVariant,
                                                                        fontWeight:
                                                                            FontWeight.w700,
                                                                      ),
                                                                    ),
                                                                  )
                                                                : CustomPaint(
                                                                    painter:
                                                                        _RevenueLineChartPainter(
                                                                      values:
                                                                          _chartRevenue,
                                                                      labels:
                                                                          _chartMonths,
                                                                      lineColor:
                                                                          cs.primary,
                                                                      fillColor: cs
                                                                          .primary
                                                                          .withValues(
                                                                              alpha: 0.10),
                                                                      gridColor: cs
                                                                          .outlineVariant
                                                                          .withValues(
                                                                              alpha: 0.25),
                                                                    ),
                                                                    child: const SizedBox
                                                                        .expand(),
                                                                  ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Card(
                                                child: Padding(
                                                  padding:
                                                      const EdgeInsets.all(16),
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        l10n.paymentRate,
                                                        style: t.titleSmall
                                                            ?.copyWith(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w900),
                                                      ),
                                                      const SizedBox(
                                                          height: 12),
                                                      SizedBox(
                                                        height: 180,
                                                        child:
                                                            _PaymentRateContent(
                                                          rate: _paymentRate,
                                                          paidCount: _paidCount,
                                                          unpaidCount:
                                                              _unpaidCount,
                                                          paidLabel:
                                                              l10n.paidLabel,
                                                          unpaidLabel:
                                                              l10n.unpaidLabel,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                ],
                                const SizedBox(height: 18),
                                _DashboardTipCard(
                                  title: _tipTitle(l10n.localeName),
                                  body: _tipBody(l10n.localeName),
                                ),
                                const SizedBox(height: 20),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  bool _can(AppPermission permission) => _permissions.can(permission);

  bool _requirePermission(AppPermission permission) {
    if (_can(permission)) return true;
    AppAlerts.error(context, 'You do not have permission for this action.');
    return false;
  }
}

class _DashboardSearch extends StatelessWidget {
  final VoidCallback onSearch;

  const _DashboardSearch({required this.onSearch});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          button: true,
          label: MaterialLocalizations.of(context).searchFieldLabel,
          child: InkWell(
            onTap: onSearch,
            borderRadius: BorderRadius.circular(15),
            child: Ink(
              height: 50,
              padding: const EdgeInsets.symmetric(horizontal: 15),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: cs.outlineVariant),
              ),
              child: Row(
                children: [
                  Icon(Icons.search_rounded, color: cs.onSurfaceVariant),
                  const SizedBox(width: 11),
                  Text(
                    MaterialLocalizations.of(context).searchFieldLabel,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DashboardLoading extends StatelessWidget {
  const _DashboardLoading();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final placeholder = cs.surfaceContainerHighest.withValues(alpha: 0.72);

    Widget block({required double height, double? width, double radius = 14}) {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: placeholder,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(
            color: cs.outlineVariant.withValues(alpha: 0.55),
          ),
        ),
      );
    }

    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1080),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              block(height: 50),
              const SizedBox(height: 24),
              LayoutBuilder(
                builder: (context, constraints) {
                  final count = constraints.maxWidth < 720 ? 2 : 4;
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: 4,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: count,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: constraints.maxWidth < 380 ? 1.45 : 1.7,
                    ),
                    itemBuilder: (_, __) => block(height: 112),
                  );
                },
              ),
              const SizedBox(height: 18),
              block(height: 210),
              const SizedBox(height: 18),
              block(height: 156),
              const SizedBox(height: 18),
              const Center(
                child: SizedBox.square(
                  dimension: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.4),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChartTitleRow extends StatelessWidget {
  final String title;
  final String value;

  const _ChartTitleRow({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: textTheme.labelLarge?.copyWith(
            color: cs.primary,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _PaymentRateContent extends StatelessWidget {
  final double rate;
  final int paidCount;
  final int unpaidCount;
  final String paidLabel;
  final String unpaidLabel;

  const _PaymentRateContent({
    required this.rate,
    required this.paidCount,
    required this.unpaidCount,
    required this.paidLabel,
    required this.unpaidLabel,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final normalizedRate = (rate / 100).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          children: [
            Container(
              width: 43,
              height: 43,
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(Icons.donut_large_rounded, color: cs.primary),
            ),
            const SizedBox(width: 12),
            Text(
              '${rate.toStringAsFixed(1)}%',
              style: textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        LinearProgressIndicator(
          value: normalizedRate,
          minHeight: 8,
          borderRadius: BorderRadius.circular(99),
          backgroundColor: cs.surfaceContainerHighest,
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 16,
          runSpacing: 8,
          children: [
            _ChartLegendItem(
              color: cs.primary,
              label: '$paidCount $paidLabel',
            ),
            _ChartLegendItem(
              color: cs.error,
              label: '$unpaidCount $unpaidLabel',
            ),
          ],
        ),
      ],
    );
  }
}

class _ChartLegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _ChartLegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _InventoryActivityCard extends StatelessWidget {
  const _InventoryActivityCard({
    required this.lowStock,
    required this.topProducts,
    required this.title,
    required this.lowStockLabel,
    required this.topProductsLabel,
    required this.unitsSoldLabel,
  });

  final List<Map<String, dynamic>> lowStock;
  final List<MapEntry<String, double>> topProducts;
  final String title;
  final String lowStockLabel;
  final String topProductsLabel;
  final String unitsSoldLabel;

  String _quantity(dynamic value) {
    final number = value is num ? value.toDouble() : double.tryParse('$value');
    if (number == null) return '0';
    return number == number.roundToDouble()
        ? number.toInt().toString()
        : number.toStringAsFixed(3).replaceFirst(RegExp(r'\.?0+$'), '');
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final lowItems = lowStock.take(3).toList();
    final productItems = topProducts.take(3).toList();

    Widget sectionTitle(String label, IconData icon, Color color) => Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 7),
            Text(
              label,
              style:
                  textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
          ],
        );

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style:
                  textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            if (lowItems.isNotEmpty) ...[
              const SizedBox(height: 14),
              sectionTitle(
                lowStockLabel,
                Icons.warning_amber_rounded,
                cs.tertiary,
              ),
              const SizedBox(height: 6),
              for (final item in lowItems)
                ListTile(
                  dense: true,
                  minTileHeight: 44,
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    '${item['label'] ?? '-'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: cs.tertiary.withValues(alpha: .13),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${_quantity(item['value'])} ${item['unit'] ?? ''}'
                          .trim(),
                      style: textTheme.labelMedium?.copyWith(
                        color: cs.tertiary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
            ],
            if (lowItems.isNotEmpty && productItems.isNotEmpty)
              const Divider(height: 22),
            if (productItems.isNotEmpty) ...[
              sectionTitle(
                topProductsLabel,
                Icons.leaderboard_outlined,
                cs.primary,
              ),
              const SizedBox(height: 6),
              for (var index = 0; index < productItems.length; index++)
                ListTile(
                  dense: true,
                  minTileHeight: 44,
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Text(
                      '${index + 1}',
                      style: textTheme.labelMedium?.copyWith(
                        color: cs.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  title: Text(
                    productItems[index].key,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Text(
                    '${_quantity(productItems[index].value)} $unitsSoldLabel',
                    style: textTheme.labelMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DashboardTipCard extends StatelessWidget {
  final String title;
  final String body;

  const _DashboardTipCard({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            cs.primary.withValues(alpha: 0.17),
            cs.surfaceContainerHigh.withValues(alpha: 0.92),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.primary.withValues(alpha: 0.24)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(Icons.lightbulb_outline_rounded, color: cs.primary),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: textTheme.titleSmall?.copyWith(
                    color: cs.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  body,
                  style: textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentDocumentsCard extends StatelessWidget {
  final List<Map<String, dynamic>> documents;
  final String currency;
  final ValueChanged<Map<String, dynamic>> onTap;

  const _RecentDocumentsCard({
    required this.documents,
    required this.currency,
    required this.onTap,
  });

  double _amount(Map<String, dynamic> document) {
    final value = document['total_tnd'] ?? document['total'] ?? 0;
    return value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        child: Column(
          children: [
            for (var index = 0; index < documents.length; index++) ...[
              Builder(
                builder: (context) {
                  final document = documents[index];
                  final status = '${document['status'] ?? ''}'.toUpperCase();
                  final accent = status == 'PAID' || status == 'PAYED'
                      ? cs.primary
                      : status == 'OVERDUE'
                          ? cs.error
                          : cs.secondary;
                  final number = '${document['invoice'] ?? '-'}';
                  final client = '${document['client_name'] ?? ''}'.trim();
                  final date = '${document['invoice_date'] ?? ''}'.trim();

                  return ListTile(
                    minTileHeight: 64,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.receipt_long_rounded,
                        size: 20,
                        color: accent,
                      ),
                    ),
                    title: Text(
                      number,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: Text(
                      [client, date]
                          .where((value) => value.isNotEmpty)
                          .join(' • '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          CurrencyService.format(_amount(document), currency),
                          style: textTheme.labelMedium?.copyWith(
                            color: cs.onSurface,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 20,
                          color: cs.onSurfaceVariant,
                        ),
                      ],
                    ),
                    onTap: () => onTap(document),
                  );
                },
              ),
              if (index < documents.length - 1)
                const Divider(indent: 58, endIndent: 8),
            ],
          ],
        ),
      ),
    );
  }
}

class _TopClientRow extends StatelessWidget {
  final int rank;
  final MapEntry<String, double> client;
  final double maximum;
  final String currency;

  const _TopClientRow({
    required this.rank,
    required this.client,
    required this.maximum,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final colors = <Color>[
      cs.primary,
      cs.secondary,
      const Color(0xFF8B5CF6),
    ];
    final accent = colors[(rank - 1).clamp(0, colors.length - 1)];
    final progress = maximum <= 0 ? 0.0 : (client.value / maximum).clamp(0, 1);

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Text(
              '$rank',
              style: textTheme.labelMedium?.copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  client.key,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.labelLarge,
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: progress.toDouble(),
                    minHeight: 5,
                    color: accent,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            CurrencyService.format(client.value, currency),
            style: textTheme.labelMedium?.copyWith(
              color: cs.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardAttentionCard extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  final String Function(String type) labelFor;
  final ValueChanged<Map<String, dynamic>> onTap;

  const _DashboardAttentionCard({
    required this.items,
    required this.labelFor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final visibleItems = items.take(5).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        child: Column(
          children: [
            for (var index = 0; index < visibleItems.length; index++) ...[
              Builder(
                builder: (context) {
                  final item = visibleItems[index];
                  final tone = '${item['tone'] ?? ''}';
                  final color = tone == 'danger'
                      ? cs.error
                      : tone == 'warning'
                          ? cs.tertiary
                          : cs.primary;
                  return ListTile(
                    minTileHeight: 58,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                    leading: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Icon(
                        tone == 'danger'
                            ? Icons.warning_amber_rounded
                            : Icons.schedule_rounded,
                        color: color,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      labelFor('${item['type'] ?? ''}'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '${item['count'] ?? 0}',
                            style: Theme.of(context)
                                .textTheme
                                .labelMedium
                                ?.copyWith(
                                  color: color,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                        ),
                        const SizedBox(width: 5),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: cs.onSurfaceVariant,
                          size: 20,
                        ),
                      ],
                    ),
                    onTap: () => onTap(item),
                  );
                },
              ),
              if (index < visibleItems.length - 1)
                const Divider(indent: 54, endIndent: 8),
            ],
          ],
        ),
      ),
    );
  }
}

class _DashboardClientPickerSheet extends StatefulWidget {
  final ClientsRepo clientsRepo;

  const _DashboardClientPickerSheet({required this.clientsRepo});

  @override
  State<_DashboardClientPickerSheet> createState() =>
      _DashboardClientPickerSheetState();
}

class _DashboardClientPickerSheetState
    extends State<_DashboardClientPickerSheet> {
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
    return v.length == 8;
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

class _RevenueLineChartPainter extends CustomPainter {
  final List<double> values;
  final List<String> labels;
  final Color lineColor;
  final Color fillColor;
  final Color gridColor;

  _RevenueLineChartPainter({
    required this.values,
    required this.labels,
    required this.lineColor,
    required this.fillColor,
    required this.gridColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;

    const horizontalPad = 8.0;
    const topPad = 10.0;
    const bottomPad = 26.0;
    final chartWidth = size.width - (horizontalPad * 2);
    final chartHeight = size.height - topPad - bottomPad;

    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;

    for (int i = 0; i < 4; i++) {
      final y = topPad + ((chartHeight / 3) * i);
      canvas.drawLine(
        Offset(horizontalPad, y),
        Offset(size.width - horizontalPad, y),
        gridPaint,
      );
    }

    final minValue = values.reduce(math.min);
    final maxValue = values.reduce(math.max);
    final valueRange = maxValue - minValue;

    Offset pointFor(int index) {
      final x = values.length == 1
          ? size.width / 2
          : horizontalPad + (chartWidth / (values.length - 1) * index);
      final normalized = valueRange.abs() < 0.000001
          ? 0.5
          : (values[index] - minValue) / valueRange;
      final y = topPad + ((1 - normalized) * chartHeight);
      return Offset(x, y);
    }

    final points = List<Offset>.generate(values.length, pointFor);
    final path = Path()..moveTo(points.first.dx, points.first.dy);

    // Catmull-Rom-inspired control points keep the revenue line fluid without
    // overshooting the actual monthly values.
    for (int i = 0; i < points.length - 1; i++) {
      final p0 = i == 0 ? points[i] : points[i - 1];
      final p1 = points[i];
      final p2 = points[i + 1];
      final p3 = i + 2 < points.length ? points[i + 2] : p2;
      const tension = 0.18;
      path.cubicTo(
        p1.dx + ((p2.dx - p0.dx) * tension),
        p1.dy + ((p2.dy - p0.dy) * tension),
        p2.dx - ((p3.dx - p1.dx) * tension),
        p2.dy - ((p3.dy - p1.dy) * tension),
        p2.dx,
        p2.dy,
      );
    }

    if (values.length > 1) {
      final fillPath = Path.from(path);
      fillPath.lineTo(
        points.last.dx,
        size.height - bottomPad,
      );
      fillPath.lineTo(points.first.dx, size.height - bottomPad);
      fillPath.close();
      canvas.drawPath(
        fillPath,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [fillColor, fillColor.withValues(alpha: 0)],
          ).createShader(
            Rect.fromLTWH(0, topPad, size.width, chartHeight),
          )
          ..style = PaintingStyle.fill,
      );
    }

    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, linePaint);

    final pointPaint = Paint()..color = lineColor;
    for (int i = 0; i < values.length; i++) {
      final point = points[i];
      if (i == values.length - 1) {
        canvas.drawCircle(
          point,
          8,
          Paint()..color = lineColor.withValues(alpha: 0.16),
        );
      }
      canvas.drawCircle(point, i == values.length - 1 ? 4.5 : 3.2, pointPaint);

      if (i < labels.length) {
        final parts = labels[i].split('-');
        final label = parts.length == 2 ? parts.last : labels[i];
        final textPainter = TextPainter(
          text: TextSpan(
            text: label,
            style: TextStyle(
              color: gridColor.withValues(alpha: 0.95),
              fontSize: 9,
              fontWeight: FontWeight.w600,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        textPainter.paint(
          canvas,
          Offset(
            point.dx - (textPainter.width / 2),
            size.height - bottomPad + 7,
          ),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _RevenueLineChartPainter oldDelegate) {
    return oldDelegate.values != values ||
        oldDelegate.labels != labels ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.fillColor != fillColor ||
        oldDelegate.gridColor != gridColor;
  }
}

class _MiniStatRect extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color? color;

  const _MiniStatRect({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final tone = color ?? cs.primary;

    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: 0.72),
        ),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: tone.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, size: 19, color: tone),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: t.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: t.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }
}
