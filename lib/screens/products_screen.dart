import 'package:flutter/material.dart';
import 'package:my_app/l10n/app_localizations.dart';
import '../services/currency_service.dart';
import '../services/settings_service.dart';
import '../storage/products_repo.dart';
import 'add_product_screen.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final _repo = ProductsRepo();
  final _settingsService = SettingsService();
  final _searchCtrl = TextEditingController();

  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _loading = true;
  String _currency = 'TND';

  @override
  void initState() {
    super.initState();
    _loadProducts();

    _searchCtrl.addListener(() {
      final q = _searchCtrl.text.trim().toLowerCase();
      setState(() {
        _filtered = q.isEmpty
            ? _products
            : _products.where((p) {
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
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    setState(() => _loading = true);

    try {
      final data = await _repo.getAllProducts();
      final currency = await _settingsService.getCurrency();
      setState(() {
        _products = data;
        _filtered = data;
        _currency = currency;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
      });

      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${l10n.loadFailed}: $e')),
      );
    }
  }

  Future<void> _editProduct(Map<String, dynamic> product) async {
    final saved = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddProductScreen(product: product),
      ),
    );

    if (saved == true) {
      await _loadProducts();
    }
  }

  Future<bool> _confirmDelete(Map<String, dynamic> product) async {
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
      await _repo.deleteProduct(product['id'] as int);

      if (!mounted) return false;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.productDeleted)),
      );

      await _loadProducts();
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
    final priceValue = (p['price'] is num)
        ? (p['price'] as num).toDouble()
        : double.tryParse(p['price'].toString()) ?? 0.0;
    final price = CurrencyService.format(priceValue, _currency);

    final cardBg = cs.surfaceContainerHighest.withOpacity(.45);
    final border = cs.outlineVariant.withOpacity(.18);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.05),
            blurRadius: 16,
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.productsServices,
          style: t.titleMedium?.copyWith(fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            onPressed: _loadProducts,
            icon: const Icon(Icons.refresh),
            tooltip: l10n.refresh,
          ),
          const SizedBox(width: 6),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final saved = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddProductScreen()),
          );
          if (saved == true) {
            await _loadProducts();
          }
        },
        icon: const Icon(Icons.add),
        label: Text(l10n.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadProducts,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest.withOpacity(.55),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: cs.outlineVariant.withOpacity(.25),
                      ),
                    ),
                    child: TextField(
                      controller: _searchCtrl,
                      decoration: InputDecoration(
                        hintText: l10n.searchProductsHint,
                        prefixIcon: const Icon(Icons.search),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (_filtered.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 30),
                      child: Center(
                        child: Text(
                          l10n.noProductsYet,
                          style: t.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    )
                  else
                    ..._filtered.map((p) {
                      final id = int.tryParse(p['id'].toString()) ?? 0;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Dismissible(
                          key: ValueKey('product_$id'),
                          confirmDismiss: (direction) async {
                            if (direction == DismissDirection.startToEnd) {
                              await _editProduct(p);
                              return false;
                            }
                            if (direction == DismissDirection.endToStart) {
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
                            onTap: () => _editProduct(p),
                            child: _premiumProductCard(context, p),
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
    );
  }
}