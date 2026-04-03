import 'package:flutter/material.dart';
import 'package:my_app/l10n/app_localizations.dart';
import 'package:my_app/screens/pdf_preview_screen.dart';
import 'package:my_app/widgets/app_alerts.dart';
import 'package:my_app/services/auth_service.dart';
import 'package:my_app/services/currency_service.dart';
import 'package:my_app/services/invoice_pdf_service.dart';
import 'package:my_app/services/settings_service.dart';
import 'package:my_app/storage/clients_repo.dart';
import 'package:my_app/storage/invoice_items_repo.dart';
import 'package:my_app/storage/invoices_repo.dart';
import 'package:my_app/storage/products_repo.dart';
import 'package:shared_preferences/shared_preferences.dart';

class InvoiceEditScreen extends StatefulWidget {
  final int invoiceId;

  const InvoiceEditScreen({
    super.key,
    required this.invoiceId,
  });

  @override
  State<InvoiceEditScreen> createState() => _InvoiceEditScreenState();
}

class _InvoiceEditScreenState extends State<InvoiceEditScreen> {
  bool _loading = true;
  String? _error;
  bool _clientDeleted = false;

  final _clientsRepo = ClientsRepo();
  final _productsRepo = ProductsRepo();
  final _invoiceItemsRepo = InvoiceItemsRepo();
  final _invoicesRepo = InvoicesRepo();
  final _authService = AuthService();
  final _settingsService = SettingsService();

  Map<String, dynamic>? _invoice;
  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _products = [];

  Map<String, dynamic>? _selectedProduct;
  int? _selectedProductId;
  String _currency = 'TND';

  final TextEditingController _qtyCtrl = TextEditingController(text: '1');
  final TextEditingController _discountCtrl = TextEditingController(text: '0');
  final TextEditingController _customPriceCtrl = TextEditingController();


  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _discountCtrl.dispose();
    _customPriceCtrl.dispose();
    super.dispose();
  }

  int _toInt(dynamic v, [int fallback = 0]) {
    if (v == null) return fallback;
    if (v is int) return v;
    return int.tryParse(v.toString()) ?? fallback;
  }

  double _toD(dynamic v, [double fallback = 0.0]) {
    if (v == null) return fallback;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString().replaceAll(',', '.')) ?? fallback;
  }

  double _qty() =>
      double.tryParse(_qtyCtrl.text.trim().replaceAll(',', '.')) ?? 1.0;

  double _discountPct() =>
      double.tryParse(_discountCtrl.text.trim().replaceAll(',', '.')) ?? 0.0;

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _error = null;
      _clientDeleted = false;
    });

    try {
      final remoteInv = await _invoicesRepo.getInvoiceById(widget.invoiceId);
      final products = await _productsRepo.getAllProducts();
      final items = await _invoiceItemsRepo.getInvoiceItems(widget.invoiceId);
      final currentUser = await _authService.me();
      final currency = await _settingsService.getCurrency();

      final rawClientId = remoteInv['custom_code'];
      final clientId = rawClientId is int
          ? rawClientId
          : int.tryParse(rawClientId.toString());

      Map<String, dynamic>? client;
      bool clientDeleted = false;

      if (clientId != null && clientId > 0) {
        try {
          client = await _clientsRepo.getClientById(clientId);
          if (client == null || client.isEmpty) {
            clientDeleted = true;
            client = null;
          }
        } catch (_) {
          clientDeleted = true;
          client = null;
        }
      }

      final inv = {
        'id': remoteInv['id'],
        'invoiceNumber': remoteInv['invoice'],
        'issueDate': remoteInv['invoice_date'],
        'dueDate': remoteInv['invoice_due_date'],
        'subtotal': remoteInv['subtotal'],
        'totalVat': remoteInv['montant_tva'],
        'total': remoteInv['total'],
        'status': remoteInv['status'],
        'clientName': client?['name'] ?? 'Client',
        'clientEmail': client?['email'] ?? '',
        'clientPhone': client?['phone'] ?? '',
        'clientAddress': client?['address'] ?? '',
        'clientType': client?['type'] ?? 'individual',
        'clientFiscalId': client?['fiscalId'] ?? client?['fiscal_id'] ?? '',
        'clientCin': client?['cin'] ?? '',
        'userFirstName': currentUser['first_name'] ?? '',
        'userLastName': currentUser['last_name'] ?? '',
        'userFiscalId': currentUser['fiscal_id'] ?? '',
        'userOrganizationName': currentUser['organization_name'] ?? '',
        'userPhone': currentUser['phone'] ?? '',
        'userFax': currentUser['fax'] ?? '',
        'userAddress': currentUser['address'] ?? '',
        'userWebsite': currentUser['website'] ?? '',
        'userEmail': currentUser['email'] ?? '',
        'currency': currency,
      };

      if (!mounted) return;

      setState(() {
        _invoice = inv;
        _currency = currency;
        _products = products;
        _items = items;
        _clientDeleted = clientDeleted;

        if (products.isEmpty) {
          _selectedProduct = null;
          _selectedProductId = null;
        } else {
          final exists = _selectedProductId != null &&
              products.any((p) => _toInt(p['id']) == _selectedProductId);

          if (exists) {
            _selectedProduct = products.firstWhere(
              (p) => _toInt(p['id']) == _selectedProductId,
            );
          } else {
            _selectedProduct = products.first;
            _selectedProductId = _toInt(products.first['id']);
          }
        }

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
  Widget _clientDeletedBanner(ColorScheme cs) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.errorContainer.withOpacity(0.55),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: cs.error.withOpacity(0.25),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.person_off_outlined,
            color: cs.onErrorContainer,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Client has been deleted',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: cs.onErrorContainer,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'This invoice still exists, but the client reference is missing.',
                  style: TextStyle(
                    color: cs.onErrorContainer,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  double _productPrice() {
    if (_selectedProduct == null) return 0.0;

    final override = _customPriceCtrl.text.trim().replaceAll(',', '.');
    if (override.isNotEmpty) {
      final p = double.tryParse(override);
      if (p != null && p >= 0) return p;
    }

    return _toD(_selectedProduct?['price'], 0.0);
  }

  double _productTvaRate() {
    if (_selectedProduct == null) return 0.0;
    return _toD(_selectedProduct?['tva_rate'], 0.0);
  }

  _LineTotals _computeLineTotals({
    required double qty,
    required double price,
    required double discountPct,
    required double tvaRate,
  }) {
    final htBeforeDiscount = qty * price;
    final discountValue = htBeforeDiscount * (discountPct / 100.0);
    final ht = (htBeforeDiscount - discountValue).clamp(0.0, double.infinity);
    final tva = ht * (tvaRate / 100.0);
    final ttc = ht + tva;

    return _LineTotals(ht: ht, tva: tva, ttc: ttc);
  }

  Future<void> _recomputeAndUpdateInvoiceTotals() async {
    await _invoicesRepo.recomputeInvoiceTotals(widget.invoiceId);
    await _loadAll();
  }

  Future<void> _addItem() async {
    final l10n = AppLocalizations.of(context)!;

    if (_invoice == null || _selectedProduct == null) return;

    final qty = _qty();

    if (qty <= 0) {
      _toast(l10n.qtyMustBeGreaterThanZero, tone: AlertTone.warning);
      return;
    }

    final price = _productPrice();
    final discountPct = _discountPct().clamp(0.0, 100.0);
    final tvaRate = _productTvaRate();

    final totals = _computeLineTotals(
      qty: qty,
      price: price,
      discountPct: discountPct,
      tvaRate: tvaRate,
    );

    final invoiceNumber = (_invoice!['invoiceNumber'] ?? '').toString();
    final issueDate = (_invoice!['issueDate'] ?? '').toString().split(' ').first;

    await _invoiceItemsRepo.addInvoiceItem(
      invoiceId: widget.invoiceId,
      invoice: invoiceNumber,
      productCode: (_selectedProduct!['code'] ?? '').toString(),
      product: (_selectedProduct!['name'] ?? '').toString(),
      qty: qty,
      tvaRate: tvaRate,
      montantTva: totals.tva,
      price: price,
      discount: discountPct,
      subtotal: totals.ht,
      subtotalTTC: totals.ttc,
      invoiceDate: issueDate,
    );

    _qtyCtrl.text = '1';
    _discountCtrl.text = '0';
    _customPriceCtrl.clear();

    await _recomputeAndUpdateInvoiceTotals();
    _toast(l10n.itemAdded, tone: AlertTone.success);
  }

  Future<void> _deleteItem(int itemId) async {
    final l10n = AppLocalizations.of(context)!;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l10n.deleteItem),
        content: Text(l10n.removeThisItemFromInvoice),
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

    if (confirm != true) return;

    await _invoiceItemsRepo.deleteInvoiceItem(itemId);
    await _recomputeAndUpdateInvoiceTotals();
    _toast(l10n.itemDeleted, tone: AlertTone.success);
  }

  Future<void> _editItem(Map<String, dynamic> item) async {
    final l10n = AppLocalizations.of(context)!;

    final qtyCtrl = TextEditingController(text: _toD(item['qty']).toString());
    final discountCtrl =
        TextEditingController(text: _toD(item['discount']).toString());
    final priceCtrl =
        TextEditingController(text: _toD(item['price']).toString());

    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text((item['product'] ?? l10n.editItem).toString()),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: qtyCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: l10n.qty,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: priceCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: l10n.price,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: discountCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: l10n.discountPercent,
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.save),
          ),
        ],
      ),
    );

    if (saved == true) {
      final qty = _toD(qtyCtrl.text, 1.0);
      final price = _toD(priceCtrl.text, 0.0);
      final discount = _toD(discountCtrl.text, 0.0);
      final tvaRate = _toD(item['tva_rate'], 0.0);

      final totals = _computeLineTotals(
        qty: qty,
        price: price,
        discountPct: discount,
        tvaRate: tvaRate,
      );

      await _invoiceItemsRepo.updateInvoiceItem(
        id: _toInt(item['id']),
        invoiceId: _toInt(item['invoice_id']),
        invoice: (item['invoice'] ?? '').toString(),
        productCode: (item['product_code'] ?? '').toString(),
        product: (item['product'] ?? '').toString(),
        qty: qty,
        tvaRate: tvaRate,
        montantTva: totals.tva,
        price: price,
        discount: discount,
        subtotal: totals.ht,
        subtotalTTC: totals.ttc,
        invoiceDate: (item['invoice_date'] ?? '').toString(),
      );

      await _recomputeAndUpdateInvoiceTotals();
      _toast(l10n.itemUpdated, tone: AlertTone.success);
    }

    qtyCtrl.dispose();
    discountCtrl.dispose();
    priceCtrl.dispose();
  }

  Future<void> _previewPdf() async {
    final l10n = AppLocalizations.of(context)!;

    if (_invoice == null) {
      _toast(l10n.invoiceNotFound, tone: AlertTone.error);
      return;
    }

    if (_items.isEmpty) {
      _toast(l10n.addAtLeastOneItemBeforePreviewPdf, tone: AlertTone.warning);
      return;
    }

    final client = <String, dynamic>{
      'name': _invoice!['clientName'],
      'type': _invoice!['clientType'],
      'fiscalId': _invoice!['clientFiscalId'],
      'cin': _invoice!['clientCin'],
      'email': _invoice!['clientEmail'],
      'phone': _invoice!['clientPhone'],
      'address': _invoice!['clientAddress'],
    };

    final Map<String, String> labels = {
      'invoice': l10n.invoice,
      'issueDate': l10n.issue,
      'dueDate': l10n.due,
      'organization': l10n.organizationName,
      'userFiscalId': l10n.fiscalId,
      'name': 'Name',
      'fiscalId': l10n.fiscalId,
      'cin': l10n.cin,
      'identifier': 'Identifier',
      'address': l10n.address,
      'email': l10n.email,
      'phone': l10n.phone,
      'type': 'Type',
      'items': 'Items',
      'notes': 'Notes',
      'subtotal': 'Subtotal',
      'vat': 'TVA',
      'total': 'Total',
      'product': l10n.product,
      'qty': l10n.qty,
      'price': l10n.price,
      'discount': l10n.discountPercent,
      'ht': 'HT',
      'ttc': 'TTC',
      'website': l10n.website,
      'fax': l10n.fax,
    };

    final prefs = await SharedPreferences.getInstance();
    final logoPath = prefs.getString('profile_image_path');

final bytes = await InvoicePdfService.buildInvoicePdf(
  invoice: _invoice!,
  client: client,
  items: _items,
  colorScheme: Theme.of(context).colorScheme,
  labels: labels,
  logoPath: logoPath,
);

    if (!mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PdfPreviewScreen(
          pdfBytes: bytes,
          title: (_invoice!['invoiceNumber'] ?? l10n.invoice).toString(),
          clientEmail: (_invoice!['clientEmail'] ?? '').toString().trim(),
        ),
      ),
    );
  }

  void _toast(String msg, {AlertTone tone = AlertTone.info}) {
    if (!mounted) return;
    AppAlerts.show(context, message: msg, tone: tone);
  }

  Widget _buildSummaryCard(ColorScheme cs) {
    final l10n = AppLocalizations.of(context)!;

    final invNum = (_invoice!['invoiceNumber'] ?? '').toString();
    final status = (_invoice!['status'] ?? 'UNPAID').toString();
    final clientName = (_invoice!['clientName'] ?? l10n.client).toString();

    final subtotal = _toD(_invoice!['subtotal']);
    final tva = _toD(_invoice!['totalVat']);
    final total = _toD(_invoice!['total']);
    final currency = (_invoice!['currency'] ?? _currency).toString();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: 
        
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    clientName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text('${l10n.invoice}: $invNum'),
                  const SizedBox(height: 4),
                  Text('${l10n.status}: ${status.toUpperCase()}'),
                  const SizedBox(height: 4),
                  Text(
                    '${l10n.issue}: ${(_invoice!['issueDate'] ?? '')}  •  ${l10n.due}: ${(_invoice!['dueDate'] ?? '')}',
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'HT ${CurrencyService.format(subtotal, currency)}',
                  style: TextStyle(color: cs.onSurfaceVariant),
                ),
                Text(
                  'TVA ${CurrencyService.format(tva, currency)}',
                  style: TextStyle(color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: 4),
                Text(
                  CurrencyService.format(total, currency),
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ],
        ),
      
      ),
    );
  }

Future<void> _pickProduct() async {
  final l10n = AppLocalizations.of(context)!;
  final searchCtrl = TextEditingController();

  List<Map<String, dynamic>> filtered =
      List<Map<String, dynamic>>.from(_products);

  final selected = await showModalBottomSheet<Map<String, dynamic>>(
    context: context,
    isScrollControlled: true,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setModalState) {
          void applySearch(String q) {
            final query = q.trim().toLowerCase();

            setModalState(() {
              filtered = query.isEmpty
                  ? List<Map<String, dynamic>>.from(_products)
                  : _products.where((p) {
                      final name = (p['name'] ?? '').toString().toLowerCase();
                      final code = (p['code'] ?? '').toString().toLowerCase();
                      final unit = (p['unit'] ?? '').toString().toLowerCase();

                      return name.contains(query) ||
                          code.contains(query) ||
                          unit.contains(query);
                    }).toList();
            });
          }

          return SafeArea(
            child: Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.72,
                child: Column(
                  children: [
                    const SizedBox(height: 10),
                    Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Theme.of(context).dividerColor,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextField(
                        controller: searchCtrl,
                        onChanged: applySearch,
                        decoration: InputDecoration(
                          hintText: l10n.searchProduct,
                          prefixIcon: const Icon(Icons.search),
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: filtered.isEmpty
                          ? Center(
                              child: Text(l10n.noProductsFound),
                            )
                          : ListView.separated(
                              itemCount: filtered.length,
                              separatorBuilder: (_, __) =>
                                  const Divider(height: 1),
                              itemBuilder: (_, i) {
                                final p = filtered[i];
                                final name = (p['name'] ?? '').toString();
                                final code = (p['code'] ?? '').toString();
                                final unit = (p['unit'] ?? '').toString();
                                final price = CurrencyService.format(_toD(p['price']), _currency);
                                final tva =
                                    _toD(p['tva_rate']).toStringAsFixed(0);

                                return ListTile(
                                  title: Text(
                                    name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Text(
                                    [
                                      if (code.isNotEmpty) code,
                                      if (unit.isNotEmpty) unit,
                                      'TVA $tva%',
                                    ].join(' • '),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  trailing: Text(
                                    price,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  onTap: () => Navigator.pop(context, p),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );

  if (selected != null && mounted) {
    setState(() {
      _selectedProduct = selected;
      _selectedProductId = _toInt(selected['id']);
    });
  }
}

Widget _buildAddItemCard(ColorScheme cs) {
  final l10n = AppLocalizations.of(context)!;

  final lineTotals = _selectedProduct == null
      ? _LineTotals(ht: 0, tva: 0, ttc: 0)
      : _computeLineTotals(
          qty: _qty(),
          price: _productPrice(),
          discountPct: _discountPct().clamp(0, 100),
          tvaRate: _productTvaRate(),
        );

  final selectedProductLabel = _selectedProduct == null
      ? l10n.selectProduct
      : '${(_selectedProduct!['name'] ?? '').toString()} • ${CurrencyService.format(_productPrice(), _currency)}';

  return Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.addItem,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
              ),
              SizedBox(
                width: 40,
                height: 40,
                child: FilledButton(
                  onPressed: _products.isEmpty ? null : _addItem,
                  style: FilledButton.styleFrom(
                    padding: EdgeInsets.zero,
                    shape: const CircleBorder(),
                  ),
                  child: const Icon(Icons.add, size: 20),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 5,
                child: InkWell(
                  onTap: _products.isEmpty ? null : _pickProduct,
                  borderRadius: BorderRadius.circular(12),
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: l10n.product,
                      border: const OutlineInputBorder(),
                      suffixIcon: const Icon(Icons.search),
                    ),
                    child: Text(
                      selectedProductLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _selectedProduct == null
                            ? cs.onSurfaceVariant
                            : cs.onSurface,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _qtyCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: l10n.qty,
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _discountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: l10n.discountPercent,
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _customPriceCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: l10n.priceOverride,
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          SizedBox(
            width: double.infinity,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    Text(
                      'TVA ${_productTvaRate().toStringAsFixed(0)}%',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(width: 18),
                    Text('HT ${CurrencyService.format(lineTotals.ht, _currency)}'),
                    const SizedBox(width: 18),
                    Text('TVA ${CurrencyService.format(lineTotals.tva, _currency)}'),
                    const SizedBox(width: 18),
                    Text(
                      'TTC ${CurrencyService.format(lineTotals.ttc, _currency)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
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

  Widget _buildItemsCard(ColorScheme cs) {
    final l10n = AppLocalizations.of(context)!;

    return Card(
      child: _items.isEmpty
          ? Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text(
                  l10n.noItemsYet,
                  style: TextStyle(color: cs.onSurfaceVariant),
                ),
              ),
            )
          : ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _items.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final it = _items[i];
                final itemId = _toInt(it['id']);

                final name = (it['product'] ?? '').toString();
                final qty = _toD(it['qty']);
                final price = _toD(it['price']);
                final ht = _toD(it['subtotal']);
                final ttc = _toD(it['subtotalTTC']);

                return Dismissible(
                  key: ValueKey('invoice_item_$itemId'),
                  direction: DismissDirection.endToStart,
                  confirmDismiss: (_) async {
                    await _deleteItem(itemId);
                    return false;
                  },
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    color: cs.errorContainer,
                    child: Icon(
                      Icons.delete_outline,
                      color: cs.onErrorContainer,
                    ),
                  ),
                  child: ListTile(
                    title: Text(
                      name,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    subtitle: Text(
                      '${qty.toStringAsFixed(2)} × ${CurrencyService.format(price, _currency)}',
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('HT ${CurrencyService.format(ht, _currency)}'),
                        Text(
                          'TTC ${CurrencyService.format(ttc, _currency)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    onTap: () => _editItem(it),
                    onLongPress: itemId > 0 ? () => _deleteItem(itemId) : null,
                  ),
                );
              },
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.invoice)),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.error, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(_error!, style: TextStyle(color: cs.error)),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _loadAll,
                icon: const Icon(Icons.refresh),
                label: Text(l10n.retry),
              ),
            ],
          ),
        ),
      );
    }

    if (_invoice == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.invoice)),
        body: Center(child: Text(l10n.invoiceNotFound)),
      );
    }

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Text('${l10n.fill} • ${(_invoice!['invoiceNumber'] ?? '')}'),
        actions: [
          IconButton(
            onPressed: _previewPdf,
            icon: const Icon(Icons.picture_as_pdf_outlined),
            tooltip: l10n.previewPdf,
          ),
          IconButton(
            onPressed: _loadAll,
            icon: const Icon(Icons.refresh),
            tooltip: l10n.refresh,
          ),
        ],
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.all(16),
            children: [
              _buildSummaryCard(cs),
              const SizedBox(height: 12),
              if (_clientDeleted) ...[
                _clientDeletedBanner(cs),
                const SizedBox(height: 12),
              ],
              _buildAddItemCard(cs),
              const SizedBox(height: 12),
              _buildItemsCard(cs),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _LineTotals {
  final double ht;
  final double tva;
  final double ttc;

  _LineTotals({
    required this.ht,
    required this.tva,
    required this.ttc,
  });
}