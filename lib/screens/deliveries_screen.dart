import 'package:flutter/material.dart';
import 'package:my_app/core/access_scope.dart';
import 'package:my_app/l10n/app_localizations.dart';
import 'package:my_app/l10n/mobile_labels.dart';
import 'package:my_app/storage/deliveries_repo.dart';

class DeliveriesScreen extends StatefulWidget {
  const DeliveriesScreen({super.key});
  @override
  State<DeliveriesScreen> createState() => _DeliveriesScreenState();
}

class _DeliveriesScreenState extends State<DeliveriesScreen> {
  final _repo = DeliveriesRepo();
  final _search = TextEditingController();
  List<Map<String, dynamic>> _rows = [];
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
          _rows = rows;
          _loading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _action(int id, String action) async {
    try {
      await _repo.action(id, action);
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _open(Map<String, dynamic> row) async {
    final l10n = AppLocalizations.of(context)!;
    final id = int.tryParse('${row['id']}') ?? 0;
    if (id < 1) return;
    final d = await _repo.detail(id);
    if (!mounted) return;
    final items = d['items'] as List? ?? const [];
    final p = AccessScope.of(context).permissions;
    showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (context) => DraggableScrollableSheet(
            expand: false,
            initialChildSize: .78,
            builder: (_, c) => ListView(
                    controller: c,
                    padding: const EdgeInsets.all(20),
                    children: [
                      Text('${d['delivery_number'] ?? l10n.deliveryLabel}',
                          style: Theme.of(context).textTheme.headlineSmall),
                      Text('${d['client_name'] ?? ''}'),
                      Text(
                          '${l10n.salesOrderLabel}: ${d['order_number'] ?? '-'}'),
                      Chip(
                        label: Text(localizedWorkflowStatus(
                          l10n,
                          '${d['status'] ?? ''}',
                        )),
                      ),
                      const Divider(),
                      Text('${l10n.itemsLabel} (${items.length})'),
                      ...items.whereType<Map>().map((i) => ListTile(
                          title: Text(
                              '${i['product'] ?? i['product_code'] ?? ''}'),
                          subtitle:
                              Text('${l10n.quantityLabel}: ${i['qty'] ?? 0}'))),
                      if ('${d['status']}' == 'DRAFT' &&
                          p.allows('deliveries.confirm'))
                        FilledButton(
                            onPressed: () {
                              Navigator.pop(context);
                              _action(id, 'CONFIRM');
                            },
                            child: Text(l10n.confirmDelivery)),
                      if ('${d['status']}' == 'CONFIRMED' &&
                          p.allows('deliveries.deliver'))
                        FilledButton(
                            onPressed: () {
                              Navigator.pop(context);
                              _action(id, 'DELIVER');
                            },
                            child: Text(l10n.markDelivered)),
                      if ('${d['status']}' == 'DRAFT' &&
                          p.allows('deliveries.cancel'))
                        TextButton(
                            onPressed: () {
                              Navigator.pop(context);
                              _action(id, 'CANCEL');
                            },
                            child: Text(l10n.cancelDelivery)),
                    ])));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.deliveriesTitle)),
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
                  hintText: l10n.searchDeliveryClientOrder,
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(
                      onPressed: _load, icon: const Icon(Icons.arrow_forward)),
                ),
              ),
            ),
            SizedBox(
              height: 42,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: ['', 'DRAFT', 'CONFIRMED', 'DELIVERED', 'CANCELLED']
                    .map((s) => Padding(
                          padding: const EdgeInsetsDirectional.only(end: 8),
                          child: ChoiceChip(
                            label: Text(s.isEmpty
                                ? l10n.all
                                : localizedWorkflowStatus(l10n, s)),
                            selected: _status == s,
                            onSelected: (_) {
                              _status = s;
                              _load();
                            },
                          ),
                        ))
                    .toList(),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        itemCount: _rows.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final r = _rows[i];
                          return ListTile(
                            leading: const CircleAvatar(
                                child: Icon(Icons.local_shipping_outlined)),
                            title: Text('${r['delivery_number'] ?? ''}'),
                            subtitle: Text('${r['client_name'] ?? ''} • '
                                '${localizedWorkflowStatus(l10n, '${r['status'] ?? ''}')}'),
                            trailing: '${r['ready_to_invoice']}' == '1'
                                ? Chip(label: Text(l10n.readyToInvoice))
                                : null,
                            onTap: () => _open(r),
                          );
                        },
                      ),
                    ),
            ),
          ]),
        ),
      ),
    );
  }
}
