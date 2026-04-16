import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:my_app/l10n/app_localizations.dart';
import 'package:my_app/screens/pdf_preview_screen.dart';
import 'package:my_app/screens/add_client_screen.dart';
import 'package:my_app/widgets/app_alerts.dart';
import 'package:my_app/services/auth_service.dart';
import 'package:my_app/services/currency_service.dart';
import 'package:my_app/services/invoice_pdf_service.dart';
import 'package:my_app/services/settings_service.dart';
import 'package:my_app/storage/clients_repo.dart';
import 'package:my_app/storage/invoice_items_repo.dart';
import 'package:my_app/storage/invoices_repo.dart';
import 'package:my_app/storage/products_repo.dart';
import 'package:my_app/screens/add_product_screen.dart';
import 'package:my_app/widgets/app_top_bar.dart';
import 'package:shared_preferences/shared_preferences.dart';

class InvoiceEditScreen extends StatefulWidget {
  final int invoiceId;
  final VoidCallback onToggleTheme;
  final void Function(Color color) onChangePrimaryColor;
  final void Function(String code) onChangeLanguage;
  final Color currentPrimaryColor;

  const InvoiceEditScreen({
    super.key,
    required this.invoiceId,
    required this.onToggleTheme,
    required this.onChangePrimaryColor,
    required this.onChangeLanguage,
    required this.currentPrimaryColor,
  });

  @override
  State<InvoiceEditScreen> createState() => _InvoiceEditScreenState();
}

class _InvoiceEditScreenState extends State<InvoiceEditScreen> {
  bool _loading = true;
  String? _error;
  bool _clientDeleted = false;
  bool _updatingStatus = false;

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
  final TextEditingController _discountCtrl = TextEditingController(text: '1');
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

  void _upsertAndSelectProduct(Map<String, dynamic> product) {
    final sid = _toInt(product['id']);
    if (sid <= 0) return;

    final idx = _products.indexWhere((p) => _toInt(p['id']) == sid);
    if (idx >= 0) {
      _products[idx] = product;
    } else {
      _products.insert(0, product);
    }

    _selectedProduct = product;
    _selectedProductId = sid;
  }

  double _toD(dynamic v, [double fallback = 0.0]) {
    if (v == null) return fallback;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString().replaceAll(',', '.')) ?? fallback;
  }

  double _qty() =>
      double.tryParse(_qtyCtrl.text.trim().replaceAll(',', '.')) ?? 1.0;

  double _discountPct() => _clampDiscount(
        double.tryParse(_discountCtrl.text.trim().replaceAll(',', '.')) ?? 1.0,
      );

  double _clampDiscount(double value) => value.clamp(1.0, 100.0).toDouble();

  void _setDiscount(double value) {
    final next = _clampDiscount(value).round().toString();
    if (_discountCtrl.text == next) return;

    _discountCtrl.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: next.length),
    );
    setState(() {});
  }

  void _stepDiscount(int delta) {
    _setDiscount(_discountPct() + delta);
  }

  String _dateOnly(dynamic value) {
    return (value ?? '').toString().split(' ').first;
  }

  DateTime? _parseDateOnly(dynamic value) {
    final raw = _dateOnly(value);
    if (raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  Future<void> _changeIssueDate() async {
    final l10n = AppLocalizations.of(context)!;
    if (_invoice == null) return;
    if (!_isDraftInvoice) {
      _toast(l10n.invoiceLockedAfterValidation, tone: AlertTone.warning);
      return;
    }

    final currentIssue =
        _parseDateOnly(_invoice!['issueDate']) ?? DateTime.now();
    final currentDue = _parseDateOnly(_invoice!['dueDate']);
    final selected = await showDatePicker(
      context: context,
      initialDate: currentIssue,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (selected == null || !mounted) return;

    final dueDate = currentDue == null
        ? null
        : selected.add(currentDue.difference(currentIssue));

    try {
      await _invoicesRepo.updateInvoiceDates(
        id: widget.invoiceId,
        issueDate: selected,
        dueDate: dueDate,
      );

      if (!mounted) return;
      await _loadAll();
      _toast(l10n.invoiceStatusUpdated, tone: AlertTone.success);
    } catch (e) {
      if (!mounted) return;
      _toast(
        e.toString().replaceFirst('Exception: ', ''),
        tone: AlertTone.error,
      );
    }
  }

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
          if (client.isEmpty) {
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
        'clientId': (clientId ?? 0),
        'invoiceNumber': remoteInv['invoice'],
        'issueDate': remoteInv['invoice_date'],
        'dueDate': remoteInv['invoice_due_date'],
        'subtotal': remoteInv['subtotal'],
        'totalVat': remoteInv['montant_tva'],
        'total': remoteInv['total'],
        'status': remoteInv['status'],
        'clientName': (client != null)
            ? (client['name'] ?? '').toString()
            : (remoteInv['custom_name'] ?? '').toString(),
        'clientEmail': (client != null)
            ? (client['email'] ?? '').toString()
            : (remoteInv['custom_email'] ?? '').toString(),
        'clientPhone':
            (client != null) ? (client['phone'] ?? '').toString() : '',
        'clientAddress':
            (client != null) ? (client['address'] ?? '').toString() : '',
        'clientType': (client != null)
            ? ((client['type'] ?? 'individual').toString())
            : 'manual',
        'clientFiscalId': (client != null)
            ? ((client['fiscalId'] ?? client['fiscal_id'] ?? '').toString())
            : '',
        'clientCin': (client != null) ? ((client['cin'] ?? '').toString()) : '',
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

  bool get _isDraftInvoice {
    return (_invoice?['status'] ?? '').toString().trim().toUpperCase() ==
        'DRAFT';
  }

  bool get _canMarkDraftAsUnpaid {
    return _isDraftInvoice && _items.isNotEmpty && !_updatingStatus;
  }

  Future<void> _markDraftAsUnpaid() async {
    final l10n = AppLocalizations.of(context)!;
    if (_invoice == null || !_canMarkDraftAsUnpaid) {
      if (_isDraftInvoice && _items.isEmpty) {
        _toast(
          l10n.addAtLeastOneItemBeforePreviewPdf,
          tone: AlertTone.warning,
        );
      }
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l10n.confirmValidateInvoiceTitle),
        content: Text(l10n.confirmValidateInvoiceBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.check_rounded),
            label: Text(l10n.validateInvoice),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _updatingStatus = true);

    try {
      await _invoicesRepo.updateInvoiceStatus(widget.invoiceId, 'UNPAID');
      if (!mounted) return;

      setState(() {
        _invoice!['status'] = 'UNPAID';
        _updatingStatus = false;
      });

      _toast(l10n.invoiceStatusUpdated, tone: AlertTone.success);
    } catch (e) {
      if (!mounted) return;

      setState(() => _updatingStatus = false);
      _toast(
        e.toString().replaceFirst('Exception: ', ''),
        tone: AlertTone.error,
      );
    }
  }

  Future<void> _addItem() async {
    final l10n = AppLocalizations.of(context)!;

    if (_invoice == null || _selectedProduct == null) return;
    if (!_isDraftInvoice) {
      _toast(l10n.invoiceLockedAfterValidation, tone: AlertTone.warning);
      return;
    }

    final qty = _qty();

    if (qty <= 0) {
      _toast(l10n.qtyMustBeGreaterThanZero, tone: AlertTone.warning);
      return;
    }

    final price = _productPrice();
    final discountPct = _discountPct();
    final tvaRate = _productTvaRate();

    final totals = _computeLineTotals(
      qty: qty,
      price: price,
      discountPct: discountPct,
      tvaRate: tvaRate,
    );

    final invoiceNumber = (_invoice!['invoiceNumber'] ?? '').toString();
    final issueDate =
        (_invoice!['issueDate'] ?? '').toString().split(' ').first;

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
    _discountCtrl.text = '1';
    _customPriceCtrl.clear();

    await _recomputeAndUpdateInvoiceTotals();
    _toast(l10n.itemAdded, tone: AlertTone.success);
  }

  Future<void> _deleteItem(int itemId) async {
    final l10n = AppLocalizations.of(context)!;
    if (!_isDraftInvoice) {
      _toast(l10n.invoiceLockedAfterValidation, tone: AlertTone.warning);
      return;
    }

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
    if (!_isDraftInvoice) {
      _toast(l10n.invoiceLockedAfterValidation, tone: AlertTone.warning);
      return;
    }

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
        child: Row(
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
                  InkWell(
                    onTap: _changeIssueDate,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              '${l10n.issue}: ${_dateOnly(_invoice!['issueDate'])}',
                            ),
                          ),
                          if (_isDraftInvoice) ...[
                            const SizedBox(width: 5),
                            Icon(
                              Icons.edit_calendar_outlined,
                              size: 16,
                              color: cs.primary,
                            ),
                          ],
                        ],
                      ),
                    ),
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
                        child: (_products.isEmpty || filtered.isEmpty)
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 18,
                                    vertical: 10,
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.inventory_2_outlined,
                                        size: 46,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        _products.isEmpty
                                            ? l10n.noProductsYet
                                            : l10n.noProductsFound,
                                        textAlign: TextAlign.center,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleSmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.w900,
                                            ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        l10n.createYourFirstProduct,
                                        textAlign: TextAlign.center,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                      const SizedBox(height: 14),
                                      SizedBox(
                                        width: double.infinity,
                                        height: 48,
                                        child: FilledButton.icon(
                                          icon: const Icon(Icons.add_rounded),
                                          label: Text(
                                            searchCtrl.text.trim().isEmpty
                                                ? l10n.addProduct
                                                : '${l10n.addProduct}: ${searchCtrl.text.trim()}',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          onPressed: () async {
                                            final q = searchCtrl.text.trim();

                                            final created = await Navigator
                                                .push<Map<String, dynamic>>(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    AddProductScreen(
                                                  product: q.isEmpty
                                                      ? null
                                                      : <String, dynamic>{
                                                          'name': q
                                                        },
                                                ),
                                              ),
                                            );

                                            if (!mounted) return;

                                            if (created != null) {
                                              setState(() {
                                                _upsertAndSelectProduct(
                                                    created);
                                              });
                                              Navigator.pop(context, created);
                                              return;
                                            }

                                            // Fallback if the add screen returns `true` (older behavior)
                                            final legacy =
                                                await Navigator.push<bool>(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    AddProductScreen(
                                                  product: q.isEmpty
                                                      ? null
                                                      : <String, dynamic>{
                                                          'name': q
                                                        },
                                                ),
                                              ),
                                            );
                                            if (legacy == true && mounted) {
                                              await _loadAll();
                                              if (!mounted) return;
                                              if (_products.isNotEmpty) {
                                                Navigator.pop(
                                                    context, _products.first);
                                              }
                                            }
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
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
                                  final price = CurrencyService.format(
                                      _toD(p['price']), _currency);
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
                      // Footer Add Product button (persistent)
                      const SizedBox(height: 10),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.add_rounded),
                            label: Text(
                              searchCtrl.text.trim().isEmpty
                                  ? l10n.addProduct
                                  : '${l10n.addProduct}: ${searchCtrl.text.trim()}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            onPressed: () async {
                              final qRaw = searchCtrl.text.trim();

                              final created =
                                  await Navigator.push<Map<String, dynamic>>(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => AddProductScreen(
                                    product: qRaw.isEmpty
                                        ? null
                                        : <String, dynamic>{'name': qRaw},
                                  ),
                                ),
                              );

                              if (!mounted) return;

                              if (created != null) {
                                setModalState(() {
                                  // update local list + filtered list
                                  final sid = _toInt(created['id']);
                                  if (sid > 0) {
                                    final idx = _products.indexWhere(
                                        (p) => _toInt(p['id']) == sid);
                                    if (idx >= 0) {
                                      _products[idx] = created;
                                    } else {
                                      _products.insert(0, created);
                                    }

                                    final q = qRaw.toLowerCase();
                                    filtered = q.isEmpty
                                        ? List<Map<String, dynamic>>.from(
                                            _products)
                                        : _products.where((p) {
                                            final name = (p['name'] ?? '')
                                                .toString()
                                                .toLowerCase();
                                            final code = (p['code'] ?? '')
                                                .toString()
                                                .toLowerCase();
                                            final unit = (p['unit'] ?? '')
                                                .toString()
                                                .toLowerCase();
                                            return name.contains(q) ||
                                                code.contains(q) ||
                                                unit.contains(q);
                                          }).toList();
                                  }
                                });

                                // Close picker and select new product
                                Navigator.pop(context, created);
                                return;
                              }

                              // Fallback legacy bool
                              final legacy = await Navigator.push<bool>(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => AddProductScreen(
                                    product: qRaw.isEmpty
                                        ? null
                                        : <String, dynamic>{'name': qRaw},
                                  ),
                                ),
                              );

                              if (legacy == true && mounted) {
                                await _loadAll();
                                if (!mounted) return;

                                final q = qRaw.toLowerCase();
                                setModalState(() {
                                  filtered = q.isEmpty
                                      ? List<Map<String, dynamic>>.from(
                                          _products)
                                      : _products.where((p) {
                                          final name = (p['name'] ?? '')
                                              .toString()
                                              .toLowerCase();
                                          final code = (p['code'] ?? '')
                                              .toString()
                                              .toLowerCase();
                                          final unit = (p['unit'] ?? '')
                                              .toString()
                                              .toLowerCase();
                                          return name.contains(q) ||
                                              code.contains(q) ||
                                              unit.contains(q);
                                        }).toList();
                                });

                                if (_products.isNotEmpty &&
                                    (q.isEmpty || filtered.isNotEmpty)) {
                                  Navigator.pop(
                                      context,
                                      (q.isEmpty
                                          ? _products.first
                                          : filtered.first));
                                }
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
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
            discountPct: _discountPct(),
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
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: l10n.qty,
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 48,
                  height: 56,
                  child: FilledButton(
                    onPressed: _products.isEmpty ? null : _addItem,
                    style: FilledButton.styleFrom(
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Icon(Icons.check_rounded, size: 24),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: l10n.discountPercent,
                      border: const OutlineInputBorder(),
                    ),
                    child: Row(
                      children: [
                        _DiscountStepButton(
                          icon: Icons.remove_rounded,
                          onTap: () => _stepDiscount(-1),
                        ),
                        Expanded(
                          child: TextField(
                            controller: _discountCtrl,
                            textAlign: TextAlign.center,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              LengthLimitingTextInputFormatter(3),
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              isDense: true,
                              suffixText: '%',
                            ),
                            onChanged: (value) {
                              if (value.isEmpty) {
                                setState(() {});
                                return;
                              }
                              final parsed = int.tryParse(value);
                              if (parsed == null) return;
                              if (parsed < 1 || parsed > 100) {
                                _setDiscount(parsed.toDouble());
                              } else {
                                setState(() {});
                              }
                            },
                            onEditingComplete: () {
                              _setDiscount(_discountPct());
                              FocusScope.of(context).unfocus();
                            },
                          ),
                        ),
                        _DiscountStepButton(
                          icon: Icons.add_rounded,
                          onTap: () => _stepDiscount(1),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _customPriceCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
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
                child: Column(
                  children: [
                    _linePreviewRow(
                      context,
                      label: 'HT',
                      value: CurrencyService.format(lineTotals.ht, _currency),
                    ),
                    const SizedBox(height: 8),
                    _linePreviewRow(
                      context,
                      label: 'TTC',
                      value: CurrencyService.format(
                        lineTotals.ttc,
                        _currency,
                      ),
                      isTotal: true,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _linePreviewRow(
    BuildContext context, {
    required String label,
    required String value,
    bool isTotal = false,
  }) {
    final cs = Theme.of(context).colorScheme;

    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            color: cs.onSurfaceVariant,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontWeight: isTotal ? FontWeight.w900 : FontWeight.w700,
              color: isTotal ? cs.onSurface : cs.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }

  Widget _lockedInvoiceBanner(ColorScheme cs) {
    final l10n = AppLocalizations.of(context)!;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lock_outline_rounded, color: cs.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              l10n.invoiceLockedAfterValidation,
              style: TextStyle(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
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
                  direction: _isDraftInvoice
                      ? DismissDirection.endToStart
                      : DismissDirection.none,
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
                    onTap: _isDraftInvoice ? () => _editItem(it) : null,
                    onLongPress: _isDraftInvoice && itemId > 0
                        ? () => _deleteItem(itemId)
                        : null,
                  ),
                );
              },
            ),
    );
  }

  Widget _emptyProductsState(ColorScheme cs) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 52,
              color: cs.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              l10n.noProductsYet,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              l10n.createYourFirstProduct,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                icon: const Icon(Icons.add_rounded),
                label: Text(l10n.addProduct),
                onPressed: () async {
                  final created = await Navigator.push<Map<String, dynamic>>(
                    context,
                    MaterialPageRoute(builder: (_) => const AddProductScreen()),
                  );

                  if (!mounted) return;

                  if (created != null) {
                    setState(() {
                      _upsertAndSelectProduct(created);
                    });
                    return;
                  }

                  // Legacy bool fallback
                  final legacy = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(builder: (_) => const AddProductScreen()),
                  );
                  if (legacy == true && mounted) {
                    await _loadAll();
                    if (!mounted) return;
                    if (_products.isNotEmpty) {
                      await _pickProduct();
                    }
                  }
                },
              ),
            ),
          ],
        ),
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
      appBar: AppTopBar(
        title: '${l10n.fill} • ${(_invoice!['invoiceNumber'] ?? '')}',
        onToggleTheme: widget.onToggleTheme,
        onChangePrimaryColor: widget.onChangePrimaryColor,
        onChangeLanguage: widget.onChangeLanguage,
        currentPrimaryColor: widget.currentPrimaryColor,
        showProfileAction: false,
        actions: [
          // PDF preview
          IconButton(
            onPressed: _previewPdf,
            icon: const Icon(Icons.picture_as_pdf_outlined),
            tooltip: l10n.previewPdf,
          ),

          // Validate (Draft -> UNPAID) — visible but not huge
          if (_isDraftInvoice)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilledButton.tonalIcon(
                onPressed: _canMarkDraftAsUnpaid ? _markDraftAsUnpaid : null,
                icon: const Icon(Icons.verified_rounded),
                label: Text(l10n.validateInvoice),
              ),
            )
          else
            const SizedBox(width: 8),
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
              if (!_isDraftInvoice) ...[
                _lockedInvoiceBanner(cs),
                const SizedBox(height: 12),
                _buildItemsCard(cs),
              ] else if (_products.isEmpty) ...[
                _emptyProductsState(cs),
              ] else ...[
                _buildAddItemCard(cs),
                const SizedBox(height: 12),
                _buildItemsCard(cs),
              ],
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

class _DiscountStepButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _DiscountStepButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: cs.primaryContainer.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 20, color: cs.onPrimaryContainer),
      ),
    );
  }
}

class _ClientPickerSheet extends StatefulWidget {
  final ClientsRepo clientsRepo;

  const _ClientPickerSheet({
    required this.clientsRepo,
  });

  @override
  State<_ClientPickerSheet> createState() => _ClientPickerSheetState();
}

class _ClientPickerSheetState extends State<_ClientPickerSheet> {
  final TextEditingController _searchCtrl = TextEditingController();

  List<Map<String, dynamic>> _clients = [];
  List<Map<String, dynamic>> _filtered = [];

  bool _loading = true;
  String? _error;

  bool _looksLikeCin(String v) {
    final s = v.trim();
    // Tunisia CIN is 8 digits. Avoid treating names like "Karim123" as an id.
    return RegExp(r'^\d{8}$').hasMatch(s);
  }

  bool _looksLikeFiscalId(String v) {
    final s = v.trim().toUpperCase();
    return RegExp(r'^\d{7}[A-Z]$').hasMatch(s);
  }

  bool _clientExists(String value) {
    final v = value.trim().toLowerCase();
    if (v.isEmpty) return true;

    return _clients.any((c) {
      final name = (c['name'] ?? '').toString().trim().toLowerCase();
      final mf = (c['fiscalId'] ?? c['fiscal_id'] ?? '')
          .toString()
          .trim()
          .toLowerCase();
      final cin = (c['cin'] ?? '').toString().trim().toLowerCase();
      return name == v || mf == v || cin == v;
    });
  }

  @override
  void initState() {
    super.initState();
    _load();

    _searchCtrl.addListener(() {
      final q = _searchCtrl.text.trim().toLowerCase();
      setState(() {
        _filtered = q.isEmpty
            ? _clients
            : _clients.where((c) {
                final name = (c['name'] ?? '').toString().toLowerCase();
                final mf = (c['fiscalId'] ?? c['fiscal_id'] ?? '')
                    .toString()
                    .toLowerCase();
                final cin = (c['cin'] ?? '').toString().toLowerCase();
                return name.contains(q) || mf.contains(q) || cin.contains(q);
              }).toList();
      });
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // Keep your existing repo method (you used this earlier).
      final data = await widget.clientsRepo.getAllClientsarchived();
      if (!mounted) return;
      setState(() {
        _clients = data;
        _filtered = data;
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
      return;
    }

    if (_clients.isNotEmpty) {
      Navigator.pop(context, _clients.first);
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
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest.withValues(alpha: .55),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: cs.outlineVariant.withValues(alpha: .22)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 86,
                height: 86,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      cs.primaryContainer,
                      cs.tertiaryContainer.withValues(alpha: .82),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: cs.primary.withValues(alpha: .18),
                      blurRadius: 24,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(
                      Icons.receipt_long_rounded,
                      size: 44,
                      color: cs.onPrimaryContainer.withValues(alpha: .28),
                    ),
                    Align(
                      alignment: Alignment.bottomRight,
                      child: Container(
                        margin: const EdgeInsets.all(10),
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: cs.surface,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.person_add_alt_1_rounded,
                          size: 20,
                          color: cs.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Text(
                _clients.isEmpty ? l10n.noCustomersYet : l10n.noResults,
                textAlign: TextAlign.center,
                style: textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              Text(
                hasSearch
                    ? '${l10n.addNewClient}: ${searchValue.trim()}'
                    : l10n.createFirstCustomerToSeeHere,
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton.icon(
                  icon: const Icon(Icons.person_add_alt_1_rounded),
                  label: Text(
                    hasSearch
                        ? '${l10n.addNewClient}: ${searchValue.trim()}'
                        : l10n.addNewClient,
                  ),
                  onPressed: () => _addClientFromSearch(searchValue),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final cs = Theme.of(context).colorScheme;

    final searchValue = _searchCtrl.text.trim();
    final showAddButton = searchValue.isNotEmpty &&
        !_clientExists(searchValue) &&
        _filtered.isEmpty;

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
              if (showAddButton)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton.icon(
                      icon: const Icon(Icons.person_add),
                      label: Text(
                        _looksLikeCin(searchValue)
                            ? '${l10n.addNewClient}: $searchValue (CIN)'
                            : '${l10n.addNewClient}: $searchValue',
                      ),
                      onPressed: () => _addClientFromSearch(searchValue),
                    ),
                  ),
                ),
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
                                color: cs.errorContainer.withOpacity(0.55),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: cs.error.withOpacity(0.25),
                                ),
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
                            ? _clientEmptyState(context, searchValue)
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

                                  final subtitleParts = <String>[];
                                  if (email.trim().isNotEmpty)
                                    subtitleParts.add(email.trim());
                                  if (mf.trim().isNotEmpty)
                                    subtitleParts.add('MF: ${mf.trim()}');
                                  if (cin.trim().isNotEmpty)
                                    subtitleParts.add('CIN: ${cin.trim()}');

                                  return ListTile(
                                    title: Text(
                                      name.isEmpty ? l10n.client : name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    subtitle: subtitleParts.isEmpty
                                        ? null
                                        : Text(
                                            subtitleParts.join(' • '),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                    onTap: () => Navigator.pop(context, c),
                                  );
                                },
                              ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
