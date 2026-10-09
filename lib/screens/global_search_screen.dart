import 'dart:async';
import 'package:my_app/core/api_client.dart';
import 'package:my_app/core/api_config.dart';
import 'package:my_app/core/document_center_models.dart';
import 'package:my_app/screens/document_center_screen.dart';
import 'package:my_app/widgets/app_alerts.dart';
import 'package:flutter/material.dart';
import 'package:my_app/core/permission_service.dart';
import 'package:my_app/l10n/app_localizations.dart';
import 'package:my_app/l10n/mobile_labels.dart';
import 'package:my_app/services/global_search_service.dart';

class GlobalSearchScreen extends StatefulWidget {
  final PermissionService permissions;
  const GlobalSearchScreen({super.key, required this.permissions});

  @override
  State<GlobalSearchScreen> createState() => _GlobalSearchScreenState();
}

class _GlobalSearchScreenState extends State<GlobalSearchScreen> {
  final _controller = TextEditingController();
  final _service = GlobalSearchService();
  Timer? _debounce;
  List<GlobalSearchResult> _results = [];
  bool _loading = false;
  bool _opening = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _changed(String value) {
    _debounce?.cancel();
    if (value.trim().length < 2) {
      setState(() {
        _results = [];
        _loading = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(value));
  }

  Future<void> _search(String value) async {
    setState(() => _loading = true);
    final results = await _service.search(value, widget.permissions);
    if (!mounted || _controller.text.trim() != value.trim()) return;
    setState(() {
      _results = results;
      _loading = false;
    });
  }

  Future<void> _openResult(GlobalSearchResult result) async {
    if (_opening) return;
    final id = int.tryParse('${result.data['id']}') ?? 0;
    if (id <= 0) return;
    final document = switch (result.type) {
      'Invoice' => MobileDocument.fromInvoice(result.data),
      'Expense' => MobileDocument.fromExpense(result.data),
      'Supplier order' => MobileDocument.fromSupplierOrder(result.data),
      'Reception' => MobileDocument.fromSupplierReception(result.data),
      _ => null,
    };
    if (document != null) {
      await Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => DocumentDetailScreen(
                  document: document, permissions: widget.permissions)));
      return;
    }
    setState(() => _opening = true);
    try {
      final endpoint = switch (result.type) {
        'Client' => '${ApiConfig.baseUrl}/clients/get_client.php',
        'Supplier' => '${ApiConfig.baseUrl}/suppliers/get_supplier.php',
        'Product' => ApiConfig.getProduct,
        _ => throw StateError('Unsupported result type'),
      };
      final response = await ApiClient.instance
          .get(endpoint, authRequired: true, queryParams: {'id': id}) as Map;
      final key = switch (result.type) {
        'Client' => 'client',
        'Supplier' => 'supplier',
        _ => 'product',
      };
      final data = Map<String, dynamic>.from(response[key] as Map);
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      final fields = <String, String>{
        'code': l10n.codeOptional,
        'reference': l10n.codeOptional,
        'email': l10n.email,
        'phone': l10n.phone,
        'address': l10n.address,
        'price': l10n.price,
        'unit': l10n.unitOptional,
        'barcode': 'Barcode',
        'fiscalId': l10n.fiscalId,
        'fiscal_id': l10n.fiscalId,
        if ('${data['item_type']}'.toUpperCase() != 'SERVICE' &&
            '${data['unit']}'.toLowerCase() != 'service')
          'stock_quantity': l10n.quantityLabel,
      };
      await showModalBottomSheet<void>(
          context: context,
          showDragHandle: true,
          isScrollControlled: true,
          builder: (_) => SafeArea(
                  child: DraggableScrollableSheet(
                expand: false,
                initialChildSize: .65,
                builder: (_, controller) => ListView(
                    controller: controller,
                    padding: const EdgeInsets.all(20),
                    children: [
                      Text('${data['name'] ?? result.title}',
                          style: Theme.of(context).textTheme.headlineSmall),
                      for (final field in fields.entries)
                        if ((data[field.key] ?? '')
                            .toString()
                            .trim()
                            .isNotEmpty)
                          ListTile(
                              title: Text(field.value),
                              subtitle: SelectableText('${data[field.key]}')),
                    ]),
              )));
    } catch (error) {
      if (mounted) AppAlerts.error(context, error.toString());
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  IconData _icon(String type) => switch (type) {
        'Client' => Icons.person_outline,
        'Product' => Icons.inventory_2_outlined,
        'Invoice' => Icons.receipt_long_outlined,
        'Expense' => Icons.payments_outlined,
        'Supplier' => Icons.store_outlined,
        'Supplier order' => Icons.shopping_cart_outlined,
        _ => Icons.local_shipping_outlined,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Semantics(
          textField: true,
          label: l10n.mobileSearchHint,
          child: TextField(
            controller: _controller,
            autofocus: true,
            onChanged: _changed,
            decoration: InputDecoration(
              hintText: l10n.mobileSearchHint,
              border: InputBorder.none,
            ),
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _results.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      _controller.text.trim().length < 2
                          ? l10n.enterTwoCharacters
                          : l10n.noPermittedResults,
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 900),
                    child: ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: _results.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final result = _results[index];
                        return ListTile(
                          onTap: _opening ? null : () => _openResult(result),
                          trailing: const Icon(Icons.chevron_right),
                          leading:
                              CircleAvatar(child: Icon(_icon(result.type))),
                          title: Text(result.title),
                          subtitle: Text(
                            '${localizedSearchType(l10n, result.type)} • '
                            '${result.subtitle}',
                          ),
                        );
                      },
                    ),
                  ),
                ),
    );
  }
}
