import 'package:flutter/material.dart';
import 'package:my_app/l10n/app_localizations.dart';
import '../services/settings_service.dart';
import '../storage/products_repo.dart';
import '../services/exchange_rate_service.dart';

class AddProductScreen extends StatefulWidget {
  final Map<String, dynamic>? product;

  const AddProductScreen({super.key, this.product});

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final _repo = ProductsRepo();
  final _settingsService = SettingsService();

  final _name = TextEditingController();
  final _price = TextEditingController();
  final _tvaRate = TextEditingController();
  final _unit = TextEditingController();
  final _code = TextEditingController();

  bool _loading = false;
  String _currency = 'TND';

  bool get isEdit => widget.product != null;

  @override
  void initState() {
    super.initState();
    _loadCurrency();

    final p = widget.product;

    if (p != null) {
      _code.text = (p['code'] ?? '').toString();
      _name.text = (p['name'] ?? '').toString();
      _price.text = (p['price'] ?? '').toString();
      _tvaRate.text = (p['tva_rate'] ?? p['tvaRate'] ?? 0).toString();
      _unit.text = (p['unit'] ?? '').toString();
    } else {
      _tvaRate.text = '19';
    }
  }

  Future<void> _loadCurrency() async {
    final currency = await _settingsService.getCurrency();
    if (!mounted) return;
    setState(() {
      _currency = currency;
    });
  }

  @override
  void dispose() {
    _code.dispose();
    _name.dispose();
    _price.dispose();
    _tvaRate.dispose();
    _unit.dispose();
    super.dispose();
  }

  double? _parseNum(String s) {
    final cleaned = s.trim().replaceAll(',', '.');
    return double.tryParse(cleaned);
  }

  String? _requiredValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return AppLocalizations.of(context)!.requiredField;
    }
    return null;
  }

  String? _priceValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return AppLocalizations.of(context)!.requiredField;
    }
    if (_parseNum(value) == null) {
      return AppLocalizations.of(context)!.invalidNumber;
    }
    return null;
  }

  Future<void> _save() async {
    if (_loading) return;

    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    try {
      final code = _code.text.trim().isEmpty ? null : _code.text.trim();
      final name = _name.text.trim();
      final unit = _unit.text.trim().isEmpty ? null : _unit.text.trim();

      final entered = _parseNum(_price.text);

      if (entered == null) {
        throw Exception(AppLocalizations.of(context)!.priceAndTvaMustBeValidNumbers);
      }

      // convert entered currency to TND (base)
      final rate = ExchangeRateService.rates[_currency] ?? 1.0;
      final price = entered / rate;

      final tvaRate = _parseNum(_tvaRate.text);

      if (tvaRate == null) {
        throw Exception(AppLocalizations.of(context)!.priceAndTvaMustBeValidNumbers);
      }

      if (isEdit) {
        final rawId = widget.product!['id'];
        final id = rawId is int ? rawId : int.tryParse(rawId.toString());

        if (id == null) {
          throw Exception(AppLocalizations.of(context)!.invalidProductId);
        }

        await _repo.updateProduct(
          id: id,
          code: code,
          name: name,
          price: price,
          tvaRate: tvaRate,
          unit: unit,
        );

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.productUpdatedSuccessfully)),
        );
      } else {
        await _repo.addProduct(
          code: code,
          name: name,
          price: price,
          tvaRate: tvaRate,
          unit: unit,
        );

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.productSavedSuccessfully)),
        );
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceFirst('Exception: ', ''),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  final _formKey = GlobalKey<FormState>();

  InputDecoration _fieldDeco(
    BuildContext context, {
    required String label,
    String? hint,
    IconData? icon,
    String? suffixText,
    Widget? suffixIcon,
  }) {
    final cs = Theme.of(context).colorScheme;

    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: icon == null ? null : Icon(icon),
      suffixText: suffixText,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: cs.surfaceContainerHighest.withOpacity(.40),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(
          color: cs.outlineVariant.withOpacity(.22),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(
          color: cs.primary.withOpacity(.95),
          width: 1.5,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEdit ? l10n.editProduct : l10n.addProduct,
          style: t.titleMedium?.copyWith(fontWeight: FontWeight.w900),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: IconButton(
              onPressed: _loading ? null : _save,
              tooltip: isEdit ? l10n.saveChanges : l10n.saveProduct,
              icon: _loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.2),
                    )
                  : Icon(isEdit ? Icons.check : Icons.add),
            ),
          ),
        ],
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => FocusScope.of(context).unfocus(),
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest.withOpacity(.40),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: cs.outlineVariant.withOpacity(.18),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      height: 44,
                      width: 44,
                      decoration: BoxDecoration(
                        color: cs.surface.withOpacity(.7),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: cs.outlineVariant.withOpacity(.18),
                        ),
                      ),
                      child: Icon(
                        Icons.inventory_2_outlined,
                        color: cs.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        isEdit
                            ? l10n.updateProductDetails
                            : l10n.createNewProductOrService,
                        style: t.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _code,
                decoration: _fieldDeco(
                  context,
                  label: l10n.codeOptional,
                  hint: l10n.productCodeExample,
                  icon: Icons.qr_code_2_outlined,
                ),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _name,
                decoration: _fieldDeco(
                  context,
                  label: l10n.productServiceName,
                  hint: l10n.productServiceNameExample,
                  icon: Icons.text_fields,
                ),
                validator: _requiredValidator,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _price,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: _fieldDeco(
                  context,
                  label: l10n.price,
                  hint: l10n.priceExample,
                  icon: Icons.payments_outlined,
                  suffixIcon: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _currency,
                        isDense: true,
                        borderRadius: BorderRadius.circular(12),
                        items: const [
                          DropdownMenuItem(value: 'TND', child: Text('TND')),
                          DropdownMenuItem(value: 'EUR', child: Text('EUR')),
                          DropdownMenuItem(value: 'USD', child: Text('USD')),
                        ],
                        onChanged: (v) {
                          if (v == null) return;
                          setState(() => _currency = v);
                        },
                      ),
                    ),
                  ),
                ),
                validator: _priceValidator,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _tvaRate,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: _fieldDeco(
                  context,
                  label: l10n.tvaPercent,
                  hint: l10n.tvaExample,
                  icon: Icons.percent,
                  suffixText: ' %',
                ),
                validator: _priceValidator,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _unit.text.isEmpty ? null : _unit.text,
                decoration: _fieldDeco(
                  context,
                  label: l10n.unitOptional,
                  icon: Icons.straighten,
                ),
                items: const [
                  DropdownMenuItem(value: 'pcs', child: Text('pcs (Pieces)')),
                  DropdownMenuItem(value: 'kg', child: Text('kg (Kilogram)')),
                  DropdownMenuItem(value: 'g', child: Text('g (Gram)')),
                  DropdownMenuItem(value: 'L', child: Text('L (Liter)')),
                  DropdownMenuItem(value: 'm', child: Text('m (Meter)')),
                  DropdownMenuItem(value: 'h', child: Text('h (Hour)')),
                  DropdownMenuItem(value: 'day', child: Text('day')),
                  DropdownMenuItem(value: 'service', child: Text('service')),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => _unit.text = v);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}