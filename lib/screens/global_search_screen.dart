import 'dart:async';
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

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _changed(String value) {
    _debounce?.cancel();
    if (value.trim().length < 2) {
      setState(() => _results = []);
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
