import 'package:flutter/material.dart';
import 'package:my_app/core/access_scope.dart';
import 'package:my_app/core/permission_service.dart';
import 'package:my_app/l10n/app_localizations.dart';
import 'package:my_app/widgets/app_alerts.dart';
import 'package:my_app/widgets/app_top_bar.dart';
import 'package:my_app/services/currency_service.dart';
import '../services/settings_service.dart';
import '../storage/products_repo.dart';
import 'add_product_screen.dart';
import 'product_barcode_scanner_screen.dart';

class ProductsScreen extends StatefulWidget {
  final VoidCallback onToggleTheme;
  final void Function(Color color) onChangePrimaryColor;
  final void Function(String code) onChangeLanguage;
  final Color currentPrimaryColor;
  final String initialFilter;
  final String initialQuery;

  const ProductsScreen({
    super.key,
    required this.onToggleTheme,
    required this.onChangePrimaryColor,
    required this.onChangeLanguage,
    required this.currentPrimaryColor,
    this.initialFilter = 'all',
    this.initialQuery = '',
  });

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final _repo = ProductsRepo();
  final _settingsService = SettingsService();
  late final TextEditingController _searchCtrl;

  String _activeKind = 'all';
  late String _attentionFilter;
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _loading = true;
  String _currency = 'TND';

  @override
  void initState() {
    super.initState();
    _searchCtrl = TextEditingController(text: widget.initialQuery);
    _attentionFilter = widget.initialFilter;
    _loadProducts();

    _searchCtrl.addListener(_applyFilter);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _applyFilter() {
    final q = _searchCtrl.text.trim().toLowerCase();
    setState(() {
      final scoped = _products.where((p) {
        final isService = _isService(p);
        if (_activeKind == 'service') return isService;
        if (_activeKind == 'product') return !isService;
        return true;
      }).toList();

      _filtered = q.isEmpty
          ? scoped
          : scoped.where((p) {
              final name = (p['name'] ?? '').toString().toLowerCase();
              final unit = (p['unit'] ?? '').toString().toLowerCase();
              final tvaRate = (p['tva_rate'] ?? '').toString().toLowerCase();
              final code = (p['code'] ?? '').toString().toLowerCase();

              return name.contains(q) ||
                  unit.contains(q) ||
                  tvaRate.contains(q) ||
                  code.contains(q);
            }).toList();
    });
  }

  bool _isService(Map<String, dynamic> product) {
    final itemType = (product['item_type'] ?? '').toString().toUpperCase();
    if (itemType.isNotEmpty) return itemType == 'SERVICE';
    return (product['unit'] ?? '').toString().trim().toLowerCase() == 'service';
  }

  Future<void> _loadProducts() async {
    if (mounted) {
      setState(() => _loading = true);
    }

    try {
      final data = await _repo.getAllProducts(
        stock: _attentionFilter == 'low' ? 'low' : '',
        pricing: _attentionFilter == 'pricing' ? 'required' : '',
      );
      final currency = await _settingsService.getCurrency();

      if (!mounted) return;

      setState(() {
        _products = data;
        _currency = currency;
        _loading = false;
      });
      // Re-apply filter after state is updated
      if (mounted) {
        _applyFilter();
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      final l10n = AppLocalizations.of(context)!;
      AppAlerts.error(
        context,
        '${l10n.loadFailed}: ${e.toString().replaceFirst('Exception: ', '')}',
      );
    }
  }

  Future<void> _editProduct(Map<String, dynamic> product) async {
    if (!_requirePermission(AppPermission.productsUpdate)) return;
    final res = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddProductScreen(product: product),
      ),
    );

    // New behavior: Add/Edit screen can return the updated product map.
    if (res is Map) {
      final updated = Map<String, dynamic>.from(res);
      final rawId = updated['id'] ?? product['id'];
      final id = rawId is int ? rawId : int.tryParse(rawId.toString()) ?? 0;

      if (!mounted) return;
      setState(() {
        final idx =
            _products.indexWhere((p) => p['id'].toString() == id.toString());
        if (idx >= 0) {
          _products[idx] = updated;
        } else {
          // If not found, insert at top (rare case)
          _products.insert(0, updated);
        }
      });
      _applyFilter();
      return;
    }

    // Backward compatibility: if it returns true, we reload.
    if (res == true) {
      await _loadProducts();
    }
  }

  Future<bool> _confirmDelete(Map<String, dynamic> product) async {
    if (!_requirePermission(AppPermission.productsDelete)) return false;
    final l10n = AppLocalizations.of(context)!;
    final name = (product['name'] ?? '').toString();

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l10n.deleteProductQuestion),
        content: Text(l10n.areYouSureDeleteProduct(name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );

    if (ok == true) {
      final rawId = product['id'];
      final id = rawId is int ? rawId : int.tryParse(rawId.toString());
      if (id == null || id <= 0) {
        AppAlerts.error(context, l10n.invalidProductId);
        return false;
      }

      await _repo.deleteProduct(id);

      if (!mounted) return false;

      setState(() {
        _products.removeWhere((x) => x['id'].toString() == id.toString());
        _filtered.removeWhere((x) => x['id'].toString() == id.toString());
      });

      AppAlerts.success(context, l10n.productDeleted);
      return true;
    }

    return false;
  }

  Widget _pill(BuildContext context, {required String text}) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: cs.tertiaryContainer.withOpacity(.55),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cs.outlineVariant.withOpacity(.18)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontWeight: FontWeight.w900,
          fontSize: 12,
          color: cs.onTertiaryContainer,
        ),
      ),
    );
  }

  Widget _swipeBg(
    BuildContext context, {
    required IconData icon,
    required String label,
    required bool alignLeft,
    required Color color,
    required Color fg,
  }) {
    final t = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        color: color.withOpacity(.75),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        mainAxisAlignment:
            alignLeft ? MainAxisAlignment.start : MainAxisAlignment.end,
        children: [
          Icon(icon, color: fg),
          const SizedBox(width: 8),
          Text(
            label,
            style: t.bodyMedium?.copyWith(
              fontWeight: FontWeight.w900,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }

  Widget _premiumProductCard(BuildContext context, Map<String, dynamic> p) {
    final l10n = AppLocalizations.of(context)!;
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    final name = (p['name'] ?? '').toString();
    final unit = (p['unit'] ?? '-').toString();
    final code = (p['code'] ?? '').toString();
    final tvaRate = (p['tva_rate'] ?? 0).toString();
    final isService = _isService(p);
    final priceValue = (p['price'] is num)
        ? (p['price'] as num).toDouble()
        : double.tryParse(p['price'].toString()) ?? 0.0;
    final price = CurrencyService.format(priceValue, _currency);

    final cardBg = cs.surfaceContainerHighest.withOpacity(.45);
    final border = cs.outlineVariant.withOpacity(.18);

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color:
                Theme.of(context).shadowColor.withOpacity(isDark ? 0.22 : 0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            height: 46,
            width: 46,
            decoration: BoxDecoration(
              color: cs.surface.withOpacity(.65),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: cs.outlineVariant.withOpacity(.18)),
            ),
            child: Icon(Icons.inventory_2_outlined, color: cs.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.isEmpty ? l10n.unnamedProduct : name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  [
                    isService ? l10n.unitService : l10n.product,
                    if (code.isNotEmpty) '${l10n.code}: $code',
                    '${l10n.unit}: $unit',
                    'TVA $tvaRate%',
                  ].join(' • '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                price,
                style: t.titleSmall?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              _pill(context, text: 'TVA $tvaRate%'),
            ],
          ),
          const SizedBox(width: 8),
          Icon(
            Icons.chevron_right,
            size: 30,
            color: cs.onSurface.withOpacity(.55),
          ),
        ],
      ),
    );
  }

  Future<void> _openInventoryDetail(Map<String, dynamic> summary) async {
    final id = int.tryParse('${summary['id']}') ?? 0;
    if (id <= 0) return;
    try {
      final canViewHistory = _can(AppPermission.stockView);
      final product = await _repo.getInventoryDetail(
        id,
        includeHistory: canViewHistory,
      );
      if (!mounted) return;
      final stock = double.tryParse('${product['current_stock'] ?? 0}') ?? 0;
      final reorder = double.tryParse('${product['reorder_point'] ?? 0}') ?? 0;
      final hasReorderPoint = product.containsKey('reorder_point');
      final movements = product['movements'] as List? ?? const [];
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (context) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: .82,
          builder: (_, controller) => ListView(
            controller: controller,
            padding: const EdgeInsets.all(20),
            children: [
              Text('${product['name'] ?? ''}',
                  style: Theme.of(context).textTheme.headlineSmall),
              Text('${product['code'] ?? ''} • ${product['unit'] ?? ''}'),
              const SizedBox(height: 18),
              Card(
                color: hasReorderPoint && stock <= reorder
                    ? Theme.of(context).colorScheme.errorContainer
                    : null,
                child: ListTile(
                  leading: const Icon(Icons.inventory_2_outlined),
                  title: Text('Physical stock: $stock'),
                  subtitle: hasReorderPoint
                      ? Text('Reorder point: $reorder')
                      : const Text('Current product availability'),
                  trailing: hasReorderPoint && stock <= reorder
                      ? const Icon(Icons.warning_amber_rounded)
                      : const Icon(Icons.check_circle_outline),
                ),
              ),
              if (hasReorderPoint && stock <= reorder)
                const Padding(
                  padding: EdgeInsets.all(8),
                  child: Text('Reorder recommended',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              if (canViewHistory) ...[
                const SizedBox(height: 12),
                Text('Recent movements',
                    style: Theme.of(context).textTheme.titleMedium),
                if (movements.isEmpty)
                  const ListTile(title: Text('No stock movements yet')),
                ...movements.whereType<Map>().map((movement) {
                  final quantity =
                      double.tryParse('${movement['quantity'] ?? 0}') ?? 0;
                  return ListTile(
                    leading: Icon(quantity >= 0
                        ? Icons.south_west_rounded
                        : Icons.north_east_rounded),
                    title: Text('${movement['movement_type'] ?? 'Movement'}'),
                    subtitle: Text(
                        '${movement['created_at'] ?? ''}\n${movement['note'] ?? ''}'),
                    isThreeLine: true,
                    trailing: Text(
                      '${quantity >= 0 ? '+' : ''}$quantity\n${movement['balance_after'] ?? ''}',
                      textAlign: TextAlign.end,
                    ),
                  );
                }),
              ],
              if (_can(AppPermission.stockAdjust) &&
                  '${product['item_type']}'.toUpperCase() != 'SERVICE') ...[
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _adjustStock(product, stock);
                  },
                  icon: const Icon(Icons.tune_rounded),
                  label: const Text('Adjust stock'),
                ),
              ],
              if (_can(AppPermission.productsUpdate)) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _editProduct(product);
                  },
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Edit product'),
                ),
              ],
            ],
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  Future<void> _adjustStock(
      Map<String, dynamic> product, double currentStock) async {
    if (!_requirePermission(AppPermission.stockAdjust)) return;
    final quantity = TextEditingController();
    final detail = TextEditingController();
    var reason = 'COUNT_CORRECTION';
    final submitted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Adjust ${product['name'] ?? 'stock'}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Current physical stock: $currentStock'),
                const SizedBox(height: 12),
                TextField(
                  controller: quantity,
                  keyboardType: const TextInputType.numberWithOptions(
                      signed: true, decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Quantity change',
                    hintText: 'Example: 5 or -2',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: reason,
                  decoration: const InputDecoration(labelText: 'Reason'),
                  items: const [
                    DropdownMenuItem(
                        value: 'COUNT_CORRECTION',
                        child: Text('Physical count correction')),
                    DropdownMenuItem(
                        value: 'DAMAGE', child: Text('Damaged stock')),
                    DropdownMenuItem(value: 'LOSS', child: Text('Loss')),
                    DropdownMenuItem(
                        value: 'FOUND', child: Text('Stock found')),
                    DropdownMenuItem(value: 'OTHER', child: Text('Other')),
                  ],
                  onChanged: (value) =>
                      setDialogState(() => reason = value ?? reason),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: detail,
                  maxLength: 255,
                  decoration:
                      const InputDecoration(labelText: 'Required explanation'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Record adjustment')),
          ],
        ),
      ),
    );
    final quantityText = quantity.text.trim();
    final detailText = detail.text.trim();
    quantity.dispose();
    detail.dispose();
    if (submitted != true) return;
    final delta = double.tryParse(quantityText.replaceAll(',', '.'));
    if (delta == null || delta.abs() < .0001 || detailText.isEmpty) {
      if (mounted) {
        AppAlerts.error(
            context, 'Enter a non-zero quantity and an explanation.');
      }
      return;
    }
    try {
      await _repo.createStockAdjustment(
        productId: int.parse('${product['id']}'),
        quantityDelta: delta,
        reasonCode: reason,
        reasonDetail: detailText,
      );
      if (!mounted) return;
      AppAlerts.success(context, 'Stock adjustment recorded.');
      await _loadProducts();
      await _openInventoryDetail(product);
    } catch (error) {
      if (mounted) {
        AppAlerts.error(context, '$error'.replaceFirst('Exception: ', ''));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppTopBar(
        title: l10n.productsServices,
        actions: [
          IconButton(
            tooltip: 'Scan product barcode',
            icon: const Icon(Icons.barcode_reader),
            onPressed: () async {
              final product = await Navigator.push<Map<String, dynamic>>(
                context,
                MaterialPageRoute(
                    builder: (_) => const ProductBarcodeScannerScreen()),
              );
              if (product != null && mounted) _openInventoryDetail(product);
            },
          ),
        ],
        onToggleTheme: widget.onToggleTheme,
        onChangePrimaryColor: widget.onChangePrimaryColor,
        onChangeLanguage: widget.onChangeLanguage,
        currentPrimaryColor: widget.currentPrimaryColor,
      ),
      floatingActionButton: _filtered.isEmpty ||
              !_can(AppPermission.productsCreate)
          ? null
          : FloatingActionButton.extended(
              onPressed: () async {
                final res = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AddProductScreen()),
                );

                // If AddProductScreen returns the created product map, insert it immediately.
                if (res is Map) {
                  final created = Map<String, dynamic>.from(res);
                  if (!mounted) return;
                  setState(() {
                    _products.insert(0, created);
                  });
                  _applyFilter();
                  return;
                }

                // Backward compatibility
                if (res == true) {
                  await _loadProducts();
                }
              },
              icon: const Icon(Icons.add),
              label: Text(l10n.add),
            ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      hintText: l10n.searchProductsHint,
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchCtrl.text.isEmpty
                          ? null
                          : IconButton(
                              onPressed: () {
                                _searchCtrl.clear();
                                _applyFilter();
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
                          color: cs.outlineVariant.withOpacity(0.35),
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
                  const SizedBox(height: 14),
                  SizedBox(
                    height: 44,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _attentionChip(
                            'all', 'All inventory', Icons.inventory_outlined),
                        const SizedBox(width: 10),
                        _attentionChip('low', 'Low stock', Icons.warning_amber),
                        const SizedBox(width: 10),
                        _attentionChip(
                            'pricing', 'Pricing required', Icons.sell_outlined),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 44,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _kindChip(
                          context,
                          value: 'all',
                          label: l10n.all,
                          icon: Icons.grid_view_rounded,
                        ),
                        const SizedBox(width: 10),
                        _kindChip(
                          context,
                          value: 'product',
                          label: l10n.product,
                          icon: Icons.inventory_2_outlined,
                        ),
                        const SizedBox(width: 10),
                        _kindChip(
                          context,
                          value: 'service',
                          label: l10n.unitService,
                          icon: Icons.design_services_outlined,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: _filtered.isEmpty
                        ? _emptyProductsState(context)
                        : RefreshIndicator(
                            onRefresh: _loadProducts,
                            child: ListView.builder(
                              physics: const AlwaysScrollableScrollPhysics(),
                              itemCount: _filtered.length,
                              itemBuilder: (context, index) {
                                final p = _filtered[index];
                                final id =
                                    int.tryParse(p['id'].toString()) ?? 0;
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Dismissible(
                                    key: ValueKey('product_$id'),
                                    direction: _dismissDirection(
                                      canUpdate:
                                          _can(AppPermission.productsUpdate),
                                      canDelete:
                                          _can(AppPermission.productsDelete),
                                    ),
                                    confirmDismiss: (direction) async {
                                      if (direction ==
                                          DismissDirection.startToEnd) {
                                        await _editProduct(p);
                                        return false;
                                      }
                                      if (direction ==
                                          DismissDirection.endToStart) {
                                        final deleted = await _confirmDelete(p);
                                        return deleted;
                                      }
                                      return false;
                                    },
                                    background: _swipeBg(
                                      context,
                                      icon: Icons.edit,
                                      label: l10n.edit,
                                      alignLeft: true,
                                      color: cs.primaryContainer,
                                      fg: cs.onPrimaryContainer,
                                    ),
                                    secondaryBackground: _swipeBg(
                                      context,
                                      icon: Icons.delete_outline,
                                      label: l10n.delete,
                                      alignLeft: false,
                                      color: cs.errorContainer,
                                      fg: cs.onErrorContainer,
                                    ),
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(22),
                                      onTap: () => _openInventoryDetail(p),
                                      child: _premiumProductCard(context, p),
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

  Widget _emptyProductsState(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 90),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.inventory_2_outlined,
                  color: cs.primary,
                  size: 54,
                ),
                const SizedBox(height: 14),
                Text(
                  l10n.noProductsYet,
                  textAlign: TextAlign.center,
                  style: t.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.createYourFirstProduct,
                  textAlign: TextAlign.center,
                  style: t.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 14),
                if (_can(AppPermission.productsCreate))
                  SizedBox(
                    width: 220,
                    height: 48,
                    child: FilledButton.icon(
                      onPressed: () async {
                        final res = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AddProductScreen(),
                          ),
                        );

                        if (res is Map) {
                          final created = Map<String, dynamic>.from(res);
                          if (!mounted) return;
                          setState(() {
                            _products.insert(0, created);
                          });
                          _applyFilter();
                          return;
                        }

                        if (res == true) {
                          await _loadProducts();
                        }
                      },
                      icon: const Icon(Icons.add),
                      label: Text(l10n.add),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  bool _can(AppPermission permission) =>
      AccessScope.maybeOf(context)?.permissions.can(permission) ?? false;

  bool _requirePermission(AppPermission permission) {
    if (_can(permission)) return true;
    AppAlerts.error(context, 'You do not have permission for this action.');
    return false;
  }

  DismissDirection _dismissDirection({
    required bool canUpdate,
    required bool canDelete,
  }) {
    if (canUpdate && canDelete) return DismissDirection.horizontal;
    if (canUpdate) return DismissDirection.startToEnd;
    if (canDelete) return DismissDirection.endToStart;
    return DismissDirection.none;
  }

  Widget _kindChip(
    BuildContext context, {
    required String value,
    required String label,
    required IconData icon,
  }) {
    final cs = Theme.of(context).colorScheme;
    final isActive = _activeKind == value;

    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: () {
        setState(() => _activeKind = value);
        _applyFilter();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? cs.primary : cs.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isActive ? cs.primary : cs.outlineVariant.withOpacity(0.35),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: isActive ? cs.onPrimary : cs.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: isActive ? cs.onPrimary : cs.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _attentionChip(String value, String label, IconData icon) {
    final selected = _attentionFilter == value;
    return FilterChip(
      avatar: Icon(icon, size: 17),
      label: Text(label),
      selected: selected,
      onSelected: (_) {
        setState(() => _attentionFilter = value);
        _loadProducts();
      },
    );
  }
}
