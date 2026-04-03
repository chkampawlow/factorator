import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:my_app/l10n/app_localizations.dart';
import 'package:my_app/services/currency_service.dart';

import '../services/settings_service.dart';
import '../storage/products_repo.dart';
import '../services/exchange_rate_service.dart';

class AddProductScreen extends StatefulWidget {
  final Map<String, dynamic>? product;

  const AddProductScreen({super.key, this.product});

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen>
    with SingleTickerProviderStateMixin {
  final _repo = ProductsRepo();
  final _settingsService = SettingsService();

  final _formKey = GlobalKey<FormState>();

  final _name = TextEditingController();
  final _price = TextEditingController();
  final _tvaRate = TextEditingController();
  final _unit = TextEditingController();
  final _code = TextEditingController();

  bool _loading = false;
  String _currency = 'TND';

  late final AnimationController _animController;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  bool get isEdit => widget.product != null;

  @override
  void initState() {
    super.initState();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _fade = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );

    _slide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animController,
        curve: Curves.easeOutCubic,
      ),
    );

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

    _name.addListener(_refresh);
    _price.addListener(_refresh);
    _tvaRate.addListener(_refresh);
    _unit.addListener(_refresh);
  }

  Future<void> _loadCurrency() async {
    final currency = await _settingsService.getCurrency();
    if (!mounted) return;
    setState(() {
      _currency = currency;
    });
    _animController.forward();
  }

  @override
  void dispose() {
    _name.removeListener(_refresh);
    _price.removeListener(_refresh);
    _tvaRate.removeListener(_refresh);
    _unit.removeListener(_refresh);

    _code.dispose();
    _name.dispose();
    _price.dispose();
    _tvaRate.dispose();
    _unit.dispose();
    _animController.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  double? _parseNum(String s) {
    final cleaned = s.trim().replaceAll(',', '.');
    return double.tryParse(cleaned);
  }

  String? _requiredValidator(String? value) {
    final l10n = AppLocalizations.of(context)!;
    if (value == null || value.trim().isEmpty) {
      return l10n.requiredField;
    }
    return null;
  }

  String? _priceValidator(String? value) {
    final l10n = AppLocalizations.of(context)!;
    if (value == null || value.trim().isEmpty) {
      return l10n.requiredField;
    }
    if (_parseNum(value) == null) {
      return l10n.invalidNumber;
    }
    return null;
  }

  double _priceBaseTnd() {
    final entered = _parseNum(_price.text) ?? 0.0;
    final rate = ExchangeRateService.rates[_currency] ?? 1.0;
    if (rate == 0) return entered;
    return entered / rate;
  }

  String _pricePreview() {
    final base = _priceBaseTnd();
    return CurrencyService.format(base, _currency);
  }

  double _tvaValue() {
    return _parseNum(_tvaRate.text) ?? 0.0;
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;

    if (_loading) return;

    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    try {
      final code = _code.text.trim().isEmpty ? null : _code.text.trim();
      final name = _name.text.trim();
      final unit = _unit.text.trim().isEmpty ? null : _unit.text.trim();

      final entered = _parseNum(_price.text);
      final tvaRate = _parseNum(_tvaRate.text);

      if (entered == null || tvaRate == null) {
        throw Exception(l10n.priceAndTvaMustBeValidNumbers);
      }

      final price = _priceBaseTnd();

      if (isEdit) {
        final rawId = widget.product!['id'];
        final id = rawId is int ? rawId : int.tryParse(rawId.toString());

        if (id == null) {
          throw Exception(l10n.invalidProductId);
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
          SnackBar(content: Text(l10n.productUpdatedSuccessfully)),
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
          SnackBar(content: Text(l10n.productSavedSuccessfully)),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? l10n.editProduct : l10n.addProduct),
      ),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fade,
          child: SlideTransition(
            position: _slide,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - 16,
                    ),
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => FocusScope.of(context).unfocus(),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            // Top gradient card (same language as expenses)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    cs.primaryContainer.withOpacity(0.45),
                                    cs.surface,
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(22),
                                border: Border.all(
                                  color: cs.outlineVariant
                                      .withOpacity(isDark ? 0.28 : 0.18),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    height: 44,
                                    width: 44,
                                    decoration: BoxDecoration(
                                      color: cs.surface.withOpacity(0.7),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: cs.outlineVariant.withOpacity(0.18),
                                      ),
                                    ),
                                    child: Icon(
                                      Icons.inventory_2_outlined,
                                      color: cs.primary,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          isEdit ? l10n.editProduct : l10n.addProduct,
                                          style: t.titleLarge?.copyWith(
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          isEdit
                                              ? l10n.updateProductDetails
                                              : l10n.createNewProductOrService,
                                          style: t.bodyMedium?.copyWith(
                                            color: cs.onSurfaceVariant,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 14),

                            // Glass card like expenses
                            ClipRRect(
                              borderRadius: BorderRadius.circular(22),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: cs.surfaceContainerHighest.withOpacity(0.55),
                                    borderRadius: BorderRadius.circular(22),
                                    border: Border.all(
                                      color: cs.outlineVariant.withOpacity(0.28),
                                    ),
                                  ),
                                  child: Column(
                                    children: [
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
                                        keyboardType:
                                            const TextInputType.numberWithOptions(decimal: true),
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
                                                  DropdownMenuItem(
                                                      value: 'TND', child: Text('TND')),
                                                  DropdownMenuItem(
                                                      value: 'EUR', child: Text('EUR')),
                                                  DropdownMenuItem(
                                                      value: 'USD', child: Text('USD')),
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
                                        keyboardType:
                                            const TextInputType.numberWithOptions(decimal: true),
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
                                          DropdownMenuItem(
                                              value: 'pcs', child: Text('pcs (Pieces)')),
                                          DropdownMenuItem(
                                              value: 'kg', child: Text('kg (Kilogram)')),
                                          DropdownMenuItem(
                                              value: 'g', child: Text('g (Gram)')),
                                          DropdownMenuItem(
                                              value: 'L', child: Text('L (Liter)')),
                                          DropdownMenuItem(
                                              value: 'm', child: Text('m (Meter)')),
                                          DropdownMenuItem(
                                              value: 'h', child: Text('h (Hour)')),
                                          DropdownMenuItem(value: 'day', child: Text('day')),
                                          DropdownMenuItem(
                                              value: 'service', child: Text('service')),
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
                            ),

                            const SizedBox(height: 14),

                            // Preview card
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: cs.surface,
                                borderRadius: BorderRadius.circular(22),
                                border: Border.all(
                                  color: cs.outlineVariant.withOpacity(0.28),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _name.text.trim().isEmpty
                                        ? l10n.productServiceName
                                        : _name.text.trim(),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: t.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          _pricePreview(),
                                          style: t.titleMedium?.copyWith(
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ),
                                      if (_tvaRate.text.trim().isNotEmpty)
                                        Text(
                                          '${_tvaValue().toStringAsFixed(2)} %',
                                          style: t.bodySmall?.copyWith(
                                            color: cs.onSurfaceVariant,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 16),

                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: _loading
                                        ? null
                                        : () => Navigator.pop(context),
                                    child: Text(l10n.cancelButton),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  flex: 2,
                                  child: FilledButton(
                                    onPressed: _loading ? null : _save,
                                    child: _loading
                                        ? SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(cs.onPrimary),
                                            ),
                                          )
                                        : Text(isEdit ? l10n.saveChanges : l10n.saveProduct),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}