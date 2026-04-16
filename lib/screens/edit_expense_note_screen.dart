import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:my_app/l10n/app_localizations.dart';
import 'package:my_app/widgets/app_alerts.dart';
import 'package:my_app/services/currency_service.dart';
import 'package:my_app/services/settings_service.dart';
import 'package:my_app/storage/expense_notes_repo.dart';

class EditExpenseNoteScreen extends StatefulWidget {
  final Map<String, dynamic> expenseNote;

  const EditExpenseNoteScreen({
    super.key,
    required this.expenseNote,
  });

  @override
  State<EditExpenseNoteScreen> createState() => _EditExpenseNoteScreenState();
}

class _EditExpenseNoteScreenState extends State<EditExpenseNoteScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final ExpenseNotesRepo _repo = ExpenseNotesRepo();
  final SettingsService _settingsService = SettingsService();

  late final TextEditingController _titleController;
  late final TextEditingController _amountController;
  late final TextEditingController _categoryController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _receiptPathController;

  late final AnimationController _animController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  late DateTime _selectedDate;
  late String _selectedStatus;

  bool _submitting = false;
  String _currency = 'TND';

  final List<String> _statuses = const [
    'pending',
    'paid',
    'rejected',
  ];

  @override
  void initState() {
    super.initState();

    final n = widget.expenseNote;

    _titleController =
        TextEditingController(text: (n['title'] ?? '').toString());
    _amountController =
        TextEditingController(text: (n['amount'] ?? '').toString());
    _categoryController =
        TextEditingController(text: (n['category'] ?? '').toString());
    _descriptionController =
        TextEditingController(text: (n['description'] ?? '').toString());
    _receiptPathController =
        TextEditingController(text: (n['receipt_path'] ?? '').toString());

    _selectedStatus = _normalizeStatus((n['status'] ?? 'pending').toString());

    final rawDate = (n['expense_date'] ?? n['date'] ?? '').toString();
    _selectedDate = DateTime.tryParse(rawDate) ?? DateTime.now();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnimation =
        CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic);
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );

    _titleController.addListener(_refresh);
    _amountController.addListener(_refresh);
    _categoryController.addListener(_refresh);

    _init();
  }

  Future<void> _init() async {
    final currency = await _settingsService.getCurrency();
    if (!mounted) return;
    setState(() => _currency = currency);
    _animController.forward();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _titleController.removeListener(_refresh);
    _amountController.removeListener(_refresh);
    _categoryController.removeListener(_refresh);

    _titleController.dispose();
    _amountController.dispose();
    _categoryController.dispose();
    _descriptionController.dispose();
    _receiptPathController.dispose();
    _animController.dispose();
    super.dispose();
  }

  String _normalizeStatus(String s) {
    final v = s.trim().toLowerCase();
    if (v == 'approved' || v == 'paid' || v == 'reimbursed') return 'paid';
    if (v == 'rejected' || v == 'cancelled' || v == 'canceled') {
      return 'rejected';
    }
    return 'pending';
  }

  String _statusLabel(AppLocalizations l10n, String status) {
    final v = _normalizeStatus(status);
    if (v == 'paid') return l10n.statusPaid;
    if (v == 'rejected') return l10n.statusRejected;
    return l10n.statusPending;
  }

  double _parseAmount() {
    final txt = _amountController.text.trim().replaceAll(',', '.');
    return double.tryParse(txt) ?? 0.0;
  }

  String _amountPreview() {
    return CurrencyService.format(_parseAmount(), _currency);
  }

  Future<void> _pickDate() async {
    final theme = Theme.of(context);

    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: theme.copyWith(
            colorScheme: theme.colorScheme,
            dialogTheme: const DialogThemeData(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(24)),
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;
    if (_submitting) return;
    if (!_formKey.currentState!.validate()) return;

    final id = int.tryParse(widget.expenseNote['id'].toString()) ?? 0;
    if (id <= 0) {
      _snack(l10n.updateFailed, isError: true);
      return;
    }

    final amount = _parseAmount();
    if (amount < 0) {
      _snack(l10n.updateFailed, isError: true);
      return;
    }

    setState(() => _submitting = true);

    try {
      await _repo.updateExpenseNote(
        id: id,
        title: _titleController.text.trim(),
        category: _categoryController.text.trim(),
        amount: amount,
        date: DateFormat('yyyy-MM-dd').format(_selectedDate),
        description: _descriptionController.text.trim(),
        receiptPath: _receiptPathController.text.trim(),
        status: _selectedStatus,
      );

      if (!mounted) return;
      _snack(l10n.expenseNoteUpdatedSuccess);
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      _snack(
        '${l10n.updateFailed}: ${e.toString().replaceFirst('Exception: ', '')}',
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    if (isError) {
      AppAlerts.error(context, msg);
    } else {
      AppAlerts.success(context, msg);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.editExpenseNoteTitle),
      ),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - 16,
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  cs.primaryContainer.withValues(alpha: 0.45),
                                  cs.surface,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(
                                color: cs.outlineVariant
                                    .withValues(alpha: isDark ? 0.28 : 0.18),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.editExpenseNoteTitle,
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  l10n.editExpenseNoteSubtitle,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: cs.onSurfaceVariant,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          _field(
                            context,
                            controller: _titleController,
                            label: l10n.title,
                            hint: l10n.title,
                            icon: Icons.title_rounded,
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return l10n.requiredField;
                              }
                              if (v.trim().length < 2) {
                                return l10n.invalidField;
                              }
                              return null;
                            },
                            action: TextInputAction.next,
                          ),
                          const SizedBox(height: 12),
                          _field(
                            context,
                            controller: _amountController,
                            label: l10n.amount,
                            hint: l10n.amount,
                            icon: Icons.payments_outlined,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return l10n.requiredField;
                              }
                              final p = double.tryParse(
                                v.trim().replaceAll(',', '.'),
                              );
                              if (p == null || p < 0) {
                                return l10n.invalidField;
                              }
                              return null;
                            },
                            action: TextInputAction.next,
                          ),
                          const SizedBox(height: 12),
                          _field(
                            context,
                            controller: _categoryController,
                            label: l10n.categoryLabel,
                            hint: l10n.categoryLabel,
                            icon: Icons.category_outlined,
                            action: TextInputAction.next,
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            initialValue: _selectedStatus,
                            items: _statuses
                                .map(
                                  (s) => DropdownMenuItem(
                                    value: s,
                                    child: Text(_statusLabel(l10n, s)),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) => setState(
                                () => _selectedStatus = v ?? 'pending'),
                            decoration: InputDecoration(
                              labelText: l10n.status,
                              prefixIcon: const Icon(Icons.flag_outlined),
                              filled: true,
                              fillColor: cs.surface,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(
                                  color: cs.outlineVariant.withValues(
                                    alpha: 0.35,
                                  ),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(
                                  color: cs.primary,
                                  width: 1.5,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: _pickDate,
                            child: InputDecorator(
                              decoration: InputDecoration(
                                labelText: l10n.dateLabel,
                                prefixIcon:
                                    const Icon(Icons.calendar_today_rounded),
                                filled: true,
                                fillColor: cs.surface,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide.none,
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(
                                    color: cs.outlineVariant.withValues(
                                      alpha: 0.35,
                                    ),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(
                                    color: cs.primary,
                                    width: 1.5,
                                  ),
                                ),
                              ),
                              child: Text(
                                DateFormat.yMMMd(l10n.localeName)
                                    .format(_selectedDate),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          _field(
                            context,
                            controller: _receiptPathController,
                            label: l10n.receiptPathLabel,
                            hint: l10n.receiptPathHint,
                            icon: Icons.attach_file_rounded,
                            action: TextInputAction.next,
                          ),
                          const SizedBox(height: 12),
                          _field(
                            context,
                            controller: _descriptionController,
                            label: l10n.description,
                            hint: l10n.description,
                            icon: Icons.notes_rounded,
                            minLines: 4,
                            maxLines: 8,
                            action: TextInputAction.newline,
                          ),
                          const SizedBox(height: 14),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: cs.surface,
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(
                                color: cs.outlineVariant.withValues(
                                  alpha: 0.28,
                                ),
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _titleController.text.trim().isEmpty
                                        ? l10n.expenseNotePreviewTitleFallback
                                        : _titleController.text.trim(),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style:
                                        theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  _amountPreview(),
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: _submitting
                                      ? null
                                      : () => Navigator.pop(context),
                                  child: Text(l10n.cancelButton),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                flex: 2,
                                child: FilledButton(
                                  onPressed: _submitting ? null : _save,
                                  child: _submitting
                                      ? SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                              cs.onPrimary,
                                            ),
                                          ),
                                        )
                                      : Text(l10n.updateButton),
                                ),
                              ),
                            ],
                          ),
                        ],
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

  Widget _field(
    BuildContext context, {
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    TextInputAction? action,
    String? Function(String?)? validator,
    int minLines = 1,
    int maxLines = 1,
  }) {
    final cs = Theme.of(context).colorScheme;

    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      textInputAction: action,
      minLines: minLines,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: cs.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: cs.outlineVariant.withValues(alpha: 0.35),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: cs.primary, width: 1.5),
        ),
      ),
    );
  }
}
