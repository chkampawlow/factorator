import 'package:flutter/material.dart';
import '../storage/products_repo.dart';
import '../widgets/primary_button.dart';

class AddProductScreen extends StatefulWidget {
  final Map<String, dynamic>? product; // null = add, not null = edit

  const AddProductScreen({super.key, this.product});

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final _repo = ProductsRepo();

  final _name = TextEditingController();
  final _price = TextEditingController();
  final _tvaRate = TextEditingController();
  final _unit = TextEditingController();

  bool _loading = false;

  bool get isEdit => widget.product != null;

  @override
  void initState() {
    super.initState();

    final p = widget.product;

    if (p != null) {
      _name.text = (p['name'] ?? '').toString();
      _price.text = (p['price'] ?? '').toString();
      _tvaRate.text = (p['tva_rate'] ?? 0).toString();
      _unit.text = (p['unit'] ?? '').toString();
    } else {
      _tvaRate.text = "0";
    }
  }

  @override
  void dispose() {
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

  Future<void> _save() async {
    if (_loading) return;

    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    try {
      final name = _name.text.trim();
      final unit = _unit.text.trim().isEmpty ? null : _unit.text.trim();

      final price = _parseNum(_price.text);
      final tvaRate = _parseNum(_tvaRate.text);

      if (price == null || tvaRate == null) {
        throw Exception("Price and TVA must be valid numbers.");
      }

      if (isEdit) {
        final id = widget.product!['id'];

        await _repo.updateProduct(
          id: id is int ? id : int.parse(id.toString()),
          name: name,
          price: price,
          tvaRate: tvaRate,
          unit: unit,
        );
      } else {
        await _repo.addProduct(
          name: name,
          price: price,
          tvaRate: tvaRate,
          unit: unit,
        );
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }

    if (mounted) {
      setState(() => _loading = false);
    }
  }

  InputDecoration _fieldDeco(
    BuildContext context, {
    required String label,
    String? hint,
    IconData? icon,
  }) {
    final cs = Theme.of(context).colorScheme;

    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: icon == null ? null : Icon(icon),
      filled: true,
      fillColor: cs.surfaceContainerHighest.withOpacity(.45),
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

    const bottomSafeSpace = 90.0;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEdit ? "Edit Product" : "Add Product",
          style: t.titleMedium?.copyWith(fontWeight: FontWeight.w900),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.only(
            left: 16,
            right: 16,
            bottom: 16,
          ),
          child: PrimaryButton(
            text: isEdit ? "Save Changes" : "Save Product",
            loading: _loading,
            onTap: _save,
          ),
        ),
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => FocusScope.of(context).unfocus(),
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              16,
              16,
              16,
              16 + bottomSafeSpace,
            ),
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
                            ? "Update product details"
                            : "Create a new product/service",
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
                controller: _name,
                decoration: _fieldDeco(
                  context,
                  label: "Product / Service name",
                  hint: "e.g. Web design, Consulting…",
                  icon: Icons.text_fields,
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? "Required" : null,
                textInputAction: TextInputAction.next,
              ),

              const SizedBox(height: 12),

              TextFormField(
                controller: _price,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: _fieldDeco(
                  context,
                  label: "Price",
                  hint: "e.g. 120 or 120,50",
                  icon: Icons.payments_outlined,
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? "Required" : null,
                textInputAction: TextInputAction.next,
              ),

              const SizedBox(height: 12),

              TextFormField(
                controller: _tvaRate,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: _fieldDeco(
                  context,
                  label: "TVA %",
                  hint: "e.g. 19",
                  icon: Icons.percent,
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? "Required" : null,
                textInputAction: TextInputAction.next,
              ),

              const SizedBox(height: 12),

              TextFormField(
                controller: _unit,
                decoration: _fieldDeco(
                  context,
                  label: "Unit (optional)",
                  hint: "hour / piece / kg…",
                  icon: Icons.straighten,
                ),
                textInputAction: TextInputAction.done,
              ),
            ],
          ),
        ),
      ),
    );
  }
}