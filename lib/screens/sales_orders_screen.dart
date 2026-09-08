import 'package:flutter/material.dart';
import 'package:my_app/storage/sales_orders_repo.dart';
import 'package:my_app/core/access_scope.dart';
import 'package:my_app/l10n/app_localizations.dart';
import 'package:my_app/l10n/mobile_labels.dart';
import 'package:my_app/screens/deliveries_screen.dart';

class SalesOrdersScreen extends StatefulWidget {
  const SalesOrdersScreen({super.key});
  @override
  State<SalesOrdersScreen> createState() => _SalesOrdersScreenState();
}

class _SalesOrdersScreenState extends State<SalesOrdersScreen> {
  final _repo = SalesOrdersRepo();
  final _search = TextEditingController();
  List<Map<String, dynamic>> _orders = [];
  bool _loading = true;
  String _status = '';

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
    setState(() => _loading = true);
    try {
      final rows = await _repo.list(search: _search.text, status: _status);
      if (mounted) {
        setState(() {
          _orders = rows;
          _loading = false;
        });
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  Future<void> _open(Map<String, dynamic> summary) async {
    final l10n = AppLocalizations.of(context)!;
    final id = int.tryParse('${summary['id']}') ?? 0;
    if (id <= 0) return;
    showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (_) => const SizedBox(
            height: 260, child: Center(child: CircularProgressIndicator())));
    try {
      final order = await _repo.detail(id);
      if (!mounted) return;
      Navigator.pop(context);
      final items = order['items'] as List? ?? const [];
      showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          builder: (context) => DraggableScrollableSheet(
              expand: false,
              initialChildSize: .75,
              builder: (_, controller) => ListView(
                      controller: controller,
                      padding: const EdgeInsets.all(20),
                      children: [
                        Text('${order['order_number'] ?? l10n.salesOrderLabel}',
                            style: Theme.of(context).textTheme.headlineSmall),
                        Text('${order['client_name'] ?? ''}'),
                        const SizedBox(height: 8),
                        Chip(
                          label: Text(localizedWorkflowStatus(
                            l10n,
                            '${order['status'] ?? ''}',
                          )),
                        ),
                        if ('${order['source_devis_number'] ?? ''}'.isNotEmpty)
                          Text(
                              '${l10n.sourceLabel}: ${order['source_devis_number']}'),
                        const Divider(height: 28),
                        Text('${l10n.itemsLabel} (${items.length})',
                            style: Theme.of(context).textTheme.titleMedium),
                        ...items.whereType<Map>().map((item) => ListTile(
                              title: Text(
                                  '${item['product'] ?? item['name'] ?? item['product_code'] ?? ''}'),
                              subtitle: Text(
                                  '${l10n.quantityLabel}: ${item['qty'] ?? 0}'),
                              trailing: Text(
                                  '${item['subtotal'] ?? item['total'] ?? ''}'),
                            )),
                      ])));
    } catch (error) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.salesOrdersTitle), actions: [
        if (AccessScope.of(context).permissions.allows('deliveries.view'))
          IconButton(
              tooltip: l10n.deliveriesTitle,
              icon: const Icon(Icons.local_shipping_outlined),
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const DeliveriesScreen())))
      ]),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Column(children: [
            Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                    controller: _search,
                    onSubmitted: (_) => _load(),
                    decoration: InputDecoration(
                        hintText: l10n.searchOrderClient,
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: IconButton(
                            onPressed: _load,
                            icon: const Icon(Icons.arrow_forward))))),
            SizedBox(
                height: 42,
                child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      '',
                      'DRAFT',
                      'CONFIRMED',
                      'PARTIALLY_DELIVERED',
                      'DELIVERED',
                      'INVOICED',
                      'CANCELLED'
                    ]
                        .map((value) => Padding(
                            padding: const EdgeInsetsDirectional.only(end: 8),
                            child: ChoiceChip(
                                label: Text(value.isEmpty
                                    ? l10n.all
                                    : localizedWorkflowStatus(l10n, value)),
                                selected: _status == value,
                                onSelected: (_) {
                                  _status = value;
                                  _load();
                                })))
                        .toList())),
            const SizedBox(height: 8),
            Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.separated(
                            itemCount: _orders.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemBuilder: (_, index) {
                              final order = _orders[index];
                              return ListTile(
                                  leading: const CircleAvatar(
                                      child: Icon(Icons.shopping_bag_outlined)),
                                  title: Text('${order['order_number'] ?? ''}'),
                                  subtitle: Text(
                                      '${order['client_name'] ?? ''} • '
                                      '${localizedWorkflowStatus(l10n, '${order['status'] ?? ''}')}'),
                                  trailing: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text('${order['delivery_count'] ?? 0} '
                                            '${l10n.deliveriesLabel}'),
                                        Text('${order['invoice_count'] ?? 0} '
                                            '${l10n.invoicesLabel}')
                                      ]),
                                  onTap: () => _open(order));
                            }))),
          ]),
        ),
      ),
    );
  }
}
