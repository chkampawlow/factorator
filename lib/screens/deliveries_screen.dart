import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:my_app/core/delivery_maps.dart';
import 'package:my_app/core/client_identity.dart';
import 'package:my_app/core/permission_service.dart';
import 'package:my_app/core/session_service.dart';
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
  final _stops = <Map<String, dynamic>>[];

  String _text(String en, String fr, String ar) =>
      switch (AppLocalizations.of(context)!.localeName.split('_').first) {
        'fr' => fr,
        'ar' => ar,
        _ => en,
      };

  void _message(String value) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(value)));

  void _selectStop(Map<String, dynamic> row) {
    final index = _stops.indexWhere((stop) => stop['id'] == row['id']);
    if (index >= 0) {
      setState(() => _stops.removeAt(index));
      return;
    }
    if (deliveryAddress(row).isEmpty) {
      _message(_text(
          'Add a delivery address before routing this delivery.',
          'Ajoutez une adresse de livraison avant de tracer cet itinéraire.',
          'أضف عنوان التسليم قبل تحديد مسار التسليم.'));
      return;
    }
    if (_stops.length == 4) {
      _message(_text(
          'Maximum 4 deliveries per route.',
          'Maximum 4 livraisons par itinéraire.',
          'الحد الأقصى 4 تسليمات لكل مسار.'));
      return;
    }
    setState(() => _stops.add(row));
  }

  Future<void> _route(List<Map<String, dynamic>> deliveries) async {
    final stops = List<Map<String, dynamic>>.from(deliveries);
    if (stops.isEmpty) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(builder: (_, update) {
        Future<void> openRoute({bool copy = false}) async {
          try {
            final uri = deliveryRouteUri(stops.map(deliveryAddress).toList());
            if (copy) {
              await Clipboard.setData(ClipboardData(text: uri.toString()));
              if (mounted) {
                _message(_text('Route link copied.',
                    'Lien de l’itinéraire copié.', 'تم نسخ رابط المسار.'));
              }
            } else if (!await launchUrl(uri,
                mode: LaunchMode.externalApplication)) {
              throw StateError('Could not open Google Maps');
            }
          } catch (_) {
            if (mounted) {
              _message(_text(
                  'Could not open or copy this route. Check the addresses.',
                  'Impossible d’ouvrir ou copier cet itinéraire. Vérifiez les adresses.',
                  'تعذر فتح أو نسخ المسار. تحقق من العناوين.'));
            }
          }
        }

        return SafeArea(
            child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(
                _text('Delivery route', 'Itinéraire de livraison',
                    'مسار التسليم'),
                style: Theme.of(context).textTheme.titleLarge),
            Text(_text(
                'Starts from your location. Review addresses and stop order.',
                'Départ depuis votre position. Vérifiez les adresses et l’ordre des arrêts.',
                'يبدأ من موقعك. تحقق من العناوين وترتيب التوقفات.')),
            Flexible(
                child: ListView(shrinkWrap: true, children: [
              for (var i = 0; i < stops.length; i++)
                ListTile(
                  leading: CircleAvatar(child: Text('${i + 1}')),
                  title: Text(
                      '${stops[i]['delivery_number']} • ${stops[i]['client_name'] ?? ''}'),
                  subtitle: Text(deliveryAddress(stops[i])),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(
                        icon: const Icon(Icons.arrow_upward),
                        tooltip: _text('Move up', 'Monter', 'تحريك لأعلى'),
                        onPressed: i == 0
                            ? null
                            : () => update(() {
                                  final item = stops.removeAt(i);
                                  stops.insert(i - 1, item);
                                })),
                    IconButton(
                        icon: const Icon(Icons.arrow_downward),
                        tooltip: _text('Move down', 'Descendre', 'تحريك لأسفل'),
                        onPressed: i == stops.length - 1
                            ? null
                            : () => update(() {
                                  final item = stops.removeAt(i);
                                  stops.insert(i + 1, item);
                                })),
                  ]),
                ),
            ])),
            FilledButton.icon(
                onPressed: () => openRoute(),
                icon: const Icon(Icons.directions),
                label: Text(_text('Open Google Maps', 'Ouvrir Google Maps',
                    'فتح خرائط Google'))),
            TextButton.icon(
                onPressed: () => openRoute(copy: true),
                icon: const Icon(Icons.copy),
                label: Text(_text(
                    'Copy route link', 'Copier le lien', 'نسخ رابط المسار'))),
          ]),
        ));
      }),
    );
  }

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
          // Refresh selected destinations without silently using stale addresses.
          for (var i = _stops.length - 1; i >= 0; i--) {
            final matches = rows.where((row) => row['id'] == _stops[i]['id']);
            if (matches.isNotEmpty) {
              if (deliveryAddress(matches.first).isEmpty) {
                _stops.removeAt(i);
              } else {
                _stops[i] = matches.first;
              }
            }
          }
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

  Future<void> _callCustomer(Map<String, dynamic> delivery) async {
    final uri = clientPhoneUri({'phone': delivery['client_phone']});
    if (uri == null) {
      _message(AppLocalizations.of(context)!.phoneNumberInvalid);
      return;
    }
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
          mounted) {
        _message(_text(
            'Could not open the phone app.',
            'Impossible d’ouvrir l’application Téléphone.',
            'تعذر فتح تطبيق الهاتف.'));
      }
    } catch (_) {
      if (mounted) {
        _message(_text(
            'Could not open the phone app.',
            'Impossible d’ouvrir l’application Téléphone.',
            'تعذر فتح تطبيق الهاتف.'));
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
    final session = SessionService.instance.current;
    final p = AccessScope.maybeOf(context)?.permissions ??
        (session == null ? null : PermissionService(session));
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
                      OutlinedButton.icon(
                        onPressed:
                            clientPhoneUri({'phone': d['client_phone']}) == null
                                ? null
                                : () => _callCustomer(d),
                        icon: const Icon(Icons.call_outlined),
                        label: Text(_text('Call customer', 'Appeler le client',
                            'الاتصال بالعميل')),
                      ),
                      Text(
                          (d['client_phone'] ?? '').toString().trim().isNotEmpty
                              ? '${d['client_phone']}'
                              : _text(
                                  'Customer phone number unavailable',
                                  'Numéro de téléphone client indisponible',
                                  'رقم هاتف العميل غير متاح')),
                      Text(deliveryAddress(d)),
                      if (deliveryAddress(d).isNotEmpty)
                        OutlinedButton.icon(
                          onPressed: () => _route([d]),
                          icon: const Icon(Icons.location_on_outlined),
                          label: Text(_text(
                              'Open location / directions',
                              'Ouvrir le lieu / itinéraire',
                              'فتح الموقع / الاتجاهات')),
                        ),
                      if (deliveryAddress(d).isEmpty)
                        Text(_text(
                            'Delivery address missing',
                            'Adresse de livraison manquante',
                            'عنوان التسليم غير موجود')),
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
                          p?.allows('deliveries.confirm') == true)
                        FilledButton(
                            onPressed: () {
                              Navigator.pop(context);
                              _action(id, 'CONFIRM');
                            },
                            child: Text(l10n.confirmDelivery)),
                      if ('${d['status']}' == 'CONFIRMED' &&
                          p?.allows('deliveries.deliver') == true)
                        FilledButton(
                            onPressed: () {
                              Navigator.pop(context);
                              _action(id, 'DELIVER');
                            },
                            child: Text(l10n.markDelivered)),
                      if ('${d['status']}' == 'DRAFT' &&
                          p?.allows('deliveries.cancel') == true)
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
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(children: [
                  Expanded(
                      child: Text(_text(
                          'Select up to 4 deliveries for a route.',
                          'Sélectionnez jusqu’à 4 livraisons pour un itinéraire.',
                          'اختر حتى 4 تسليمات لمسار واحد.'))),
                  if (_stops.isNotEmpty)
                    IconButton(
                        tooltip: _text('Clear selection',
                            'Effacer la sélection', 'مسح الاختيار'),
                        onPressed: () => setState(_stops.clear),
                        icon: const Icon(Icons.clear)),
                  FilledButton.icon(
                      onPressed: _stops.isEmpty ? null : () => _route(_stops),
                      icon: const Icon(Icons.route),
                      label: Text('${_stops.length}/4')),
                ])),
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
                            leading: Checkbox(
                              value:
                                  _stops.any((stop) => stop['id'] == r['id']),
                              onChanged: (_) => _selectStop(r),
                            ),
                            title: Text('${r['delivery_number'] ?? ''}'),
                            subtitle: Text('${r['client_name'] ?? ''} • '
                                '${localizedWorkflowStatus(l10n, '${r['status'] ?? ''}')}\n${deliveryAddress(r)}'),
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
