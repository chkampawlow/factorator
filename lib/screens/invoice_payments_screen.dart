import 'package:image_picker/image_picker.dart';
import 'package:file_selector/file_selector.dart';
import 'package:my_app/screens/pdf_preview_screen.dart';
import 'package:my_app/core/payment_input.dart';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:my_app/core/api_client.dart';
import 'package:my_app/core/api_config.dart';
import 'package:my_app/core/permission_service.dart';
import 'package:my_app/core/session_service.dart';

class InvoicePaymentsScreen extends StatefulWidget {
  const InvoicePaymentsScreen({super.key, required this.invoiceId});
  final int invoiceId;
  @override
  State<InvoicePaymentsScreen> createState() => _InvoicePaymentsScreenState();
}

class _InvoicePaymentsScreenState extends State<InvoicePaymentsScreen> {
  final _amount = TextEditingController();
  final _reference = TextEditingController();
  final _account = TextEditingController();
  final _rate = TextEditingController(text: '1');
  Map<String, dynamic>? _ledger;
  String? _error;
  String _method = 'CASH';
  String _currency = 'TND';
  DateTime _date = DateTime.now();
  bool _saving = false;
  bool _pickingProof = false;
  XFile? _proof;
  int? _loadingProof;
  String _invoiceNumber = '';
  String? _key;
  String? _requestFingerprint;
  String t(String en, String fr, String ar) =>
      switch (Localizations.localeOf(context).languageCode) {
        'fr' => fr,
        'ar' => ar,
        _ => en,
      };
  String _methodLabel(String method) => switch (method) {
        'CASH' => t('Cash', 'Espèces', 'نقدًا'),
        'CHEQUE' => t('Cheque', 'Chèque', 'شيك'),
        'BANK_TRANSFER' =>
          t('Bank transfer', 'Virement bancaire', 'تحويل بنكي'),
        'CARD' => t('Card', 'Carte', 'بطاقة'),
        'DRAFT' => t('Bill of exchange', 'Traite', 'كمبيالة'),
        'OTHER' => t('Other', 'Autre', 'أخرى'),
        _ => method,
      };
  bool get _canRecord {
    final session = SessionService.instance.current;
    return session != null &&
        PermissionService(session).allows('payments.record');
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _amount.dispose();
    _reference.dispose();
    _account.dispose();
    _rate.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        ApiClient.instance.get(ApiConfig.invoiceSettlements,
            authRequired: true, queryParams: {'invoice_id': widget.invoiceId}),
        ApiClient.instance.get(ApiConfig.getInvoiceById,
            authRequired: true, queryParams: {'id': widget.invoiceId}),
      ]);
      final ledger = Map<String, dynamic>.from(results[0] as Map);
      final invoice = (results[1] as Map)['invoice'] as Map;
      if (!mounted) return;
      setState(() {
        final firstLoad = _ledger == null;
        _ledger = ledger;
        _error = null;
        final currency = '${invoice['currency'] ?? 'TND'}'.toUpperCase();
        if (firstLoad && currency != 'TND') _rate.clear();
        _currency = currency;
        _invoiceNumber = '${invoice['invoice'] ?? ''}';
      });
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    }
  }

  Future<void> _pickProof(String source) async {
    if (_saving || _pickingProof) return;
    setState(() => _pickingProof = true);
    try {
      final file = source == 'file'
          ? await openFile(acceptedTypeGroups: const [
              XTypeGroup(
                  label: 'Payment proof',
                  extensions: ['pdf', 'jpg', 'jpeg', 'png', 'webp'])
            ])
          : await ImagePicker().pickImage(
              source:
                  source == 'camera' ? ImageSource.camera : ImageSource.gallery,
              imageQuality: 85);
      if (file == null || !mounted) return;
      if (!validPaymentProof(file.name, await file.length())) {
        throw Exception(t(
            'Use a PDF, JPEG, PNG or WebP up to 10 MB.',
            'Utilisez un PDF, JPEG, PNG ou WebP de 10 Mo maximum.',
            'استخدم PDF أو JPEG أو PNG أو WebP بحد أقصى 10 ميغابايت.'));
      }
      if (mounted) setState(() => _proof = file);
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _pickingProof = false);
    }
  }

  Future<void> _showProof(int id) async {
    if (_loadingProof != null) return;
    setState(() => _loadingProof = id);
    try {
      final bytes = await ApiClient.instance.getPaymentProof(id);
      if (!mounted) return;
      final isPdf =
          bytes.length >= 5 && String.fromCharCodes(bytes.take(5)) == '%PDF-';
      if (isPdf) {
        await Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => PdfPreviewScreen(
                    pdfBytes: bytes,
                    title: t('Payment proof', 'Justificatif de paiement',
                        'إثبات الدفع'))));
      } else {
        await Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => Scaffold(
                    appBar: AppBar(
                        title: Text(t('Payment proof',
                            'Justificatif de paiement', 'إثبات الدفع'))),
                    body: Center(
                        child: InteractiveViewer(
                            child: Image.memory(bytes,
                                errorBuilder: (_, __, ___) => Text(t(
                                    'Cannot display this proof.',
                                    'Impossible d’afficher ce justificatif.',
                                    'تعذر عرض الإثبات.'))))))));
      }
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _loadingProof = null);
    }
  }

  Future<void> _save() async {
    if (_saving || _pickingProof || !_canRecord) return;
    final amount = double.tryParse(_amount.text.trim().replaceAll(',', '.'));
    final rate = double.tryParse(_rate.text.trim().replaceAll(',', '.'));
    final summary = _ledger?['summary'] as Map? ?? {};
    final remaining = double.tryParse('${summary['remaining_balance']}');
    if (!validInvoicePayment(
        amount: amount,
        remaining: remaining,
        rate: rate,
        method: _method,
        reference: _reference.text)) {
      setState(() => _error = t(
          'Enter a valid amount, exchange rate and required reference. Amount cannot exceed the balance.',
          'Saisissez un montant, un taux et la référence requise. Le montant ne peut pas dépasser le solde.',
          'أدخل مبلغًا وسعر صرف ومرجعًا صالحًا. لا يمكن تجاوز الرصيد.'));
      return;
    }
    final fields = <String, String>{
      'invoice_id': '${widget.invoiceId}',
      'amount': '$amount',
      'payment_date': _date.toIso8601String().split('T').first,
      'method': _method,
      'account_name': _account.text.trim(),
      'reference_number': _reference.text.trim(),
      'exchange_rate': _currency == 'TND' ? '1' : '$rate',
    };
    final fingerprint = '${fields.toString()}|${_proof?.path ?? ''}';
    if (_key == null || _requestFingerprint != fingerprint) {
      _key =
          'mobile-payment-${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 32)}';
      _requestFingerprint = fingerprint;
    }
    fields['idempotency_key'] = _key!;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ApiClient.instance.multipartPostFiles(
        '${ApiConfig.baseUrl}/invoice_settlements/add_payment.php',
        fileField: 'proof',
        filePaths: _proof == null ? const [] : [_proof!.path],
        fields: fields,
      );
      if (!mounted) return;
      _key = null;
      _requestFingerprint = null;
      setState(() => _proof = null);
      _amount.clear();
      _reference.clear();
      await _load();
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final summary = _ledger?['summary'] as Map? ?? {};
    final payments = _ledger?['payments'] as List? ?? [];
    return Scaffold(
      appBar: AppBar(
          title: Text(
              t('Invoice payments', 'Paiements de facture', 'دفعات الفاتورة'))),
      body: _ledger == null && _error == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(20),
                  children: [
                    if (_error != null)
                      Text(_error!,
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error)),
                    if (_ledger == null)
                      TextButton(
                          onPressed: _load,
                          child:
                              Text(t('Retry', 'Réessayer', 'إعادة المحاولة'))),
                    if (_ledger != null) ...[
                      Text(_invoiceNumber,
                          style: Theme.of(context).textTheme.titleLarge),
                      Text(
                          '${t('Paid', 'Payé', 'المدفوع')}: ${summary['payment_total']} $_currency'),
                      Text(
                          '${t('Remaining balance', 'Solde restant', 'الرصيد المتبقي')}: ${summary['remaining_balance']} $_currency',
                          style: Theme.of(context).textTheme.titleLarge),
                      Text('${summary['derived_status'] ?? ''}'),
                      Text(
                          '${t('Invoice total', 'Total facture', 'إجمالي الفاتورة')}: ${summary['gross_total']} $_currency'),
                      Text(
                          '${t('Credits', 'Avoirs', 'الإشعارات الدائنة')}: ${summary['credit_total']} $_currency'),
                      Text(
                          '${t('Withholding', 'Retenue à la source', 'الخصم من المصدر')}: ${summary['withholding_total']} $_currency'),
                      Text(
                          '${t('Net payable', 'Net à payer', 'صافي المستحق')}: ${summary['net_payable']} $_currency'),
                      const Divider(),
                      for (final payment in payments.whereType<Map>())
                        ListTile(
                          isThreeLine: true,
                          trailing: ['1', 'true']
                                  .contains('${payment['has_attachment']}')
                              ? IconButton(
                                  icon: const Icon(Icons.attach_file),
                                  tooltip: t('View proof',
                                      'Voir le justificatif', 'عرض الإثبات'),
                                  onPressed: _loadingProof != null
                                      ? null
                                      : () => _showProof(
                                          int.parse('${payment['id']}')))
                              : null,
                          title: Text(
                              '${payment['amount']} $_currency • ${_methodLabel('${payment['method']}')}'),
                          subtitle: Text(
                              '${payment['payment_date']} • ${payment['reference_number'] ?? ''} • ${payment['status']}\n${t('Account', 'Compte', 'الحساب')}: ${payment['account_name'] ?? ''}\n${t('Recorded by', 'Enregistré par', 'سجلها')}: ${payment['recorded_by_name'] ?? ''}\n${t('Exchange rate', 'Taux de change', 'سعر الصرف')}: ${payment['exchange_rate'] ?? ''} • ${payment['amount_tnd'] ?? ''} TND'),
                        ),
                      if (_canRecord &&
                          (double.tryParse('${summary['remaining_balance']}') ??
                                  0) >
                              0) ...[
                        TextField(
                            controller: _amount,
                            enabled: !_saving,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            decoration: InputDecoration(
                                labelText:
                                    '${t('Payment amount', 'Montant du paiement', 'مبلغ الدفع')} ($_currency)')),
                        DropdownButtonFormField<String>(
                            initialValue: _method,
                            items: [
                              'CASH',
                              'CHEQUE',
                              'BANK_TRANSFER',
                              'CARD',
                              'DRAFT',
                              'OTHER'
                            ]
                                .map((method) => DropdownMenuItem(
                                    value: method,
                                    child: Text(_methodLabel(method))))
                                .toList(),
                            onChanged: _saving
                                ? null
                                : (value) => setState(() => _method = value!)),
                        TextField(
                            controller: _reference,
                            enabled: !_saving,
                            decoration: InputDecoration(
                                labelText:
                                    t('Reference', 'Référence', 'المرجع'))),
                        TextField(
                            controller: _account,
                            enabled: !_saving,
                            decoration: InputDecoration(
                                labelText: t('Account', 'Compte', 'الحساب'))),
                        if (_currency != 'TND')
                          TextField(
                              controller: _rate,
                              enabled: !_saving,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              decoration: InputDecoration(
                                  labelText: t(
                                      'Exchange rate to TND',
                                      'Taux de change vers TND',
                                      'سعر الصرف إلى الدينار'))),
                        TextButton(
                            onPressed: _saving
                                ? null
                                : () async {
                                    final date = await showDatePicker(
                                        context: context,
                                        initialDate: _date,
                                        firstDate: DateTime(2000),
                                        lastDate: DateTime(2100));
                                    if (date != null && mounted) {
                                      setState(() => _date = date);
                                    }
                                  },
                            child:
                                Text(_date.toIso8601String().split('T').first)),
                        Wrap(spacing: 8, children: [
                          OutlinedButton.icon(
                              onPressed: _saving || _pickingProof
                                  ? null
                                  : () => _pickProof('camera'),
                              icon: const Icon(Icons.camera_alt_outlined),
                              label: Text(t('Photo', 'Photo', 'صورة'))),
                          OutlinedButton.icon(
                              onPressed: _saving || _pickingProof
                                  ? null
                                  : () => _pickProof('gallery'),
                              icon: const Icon(Icons.photo_library_outlined),
                              label: Text(t('Gallery', 'Galerie', 'المعرض'))),
                          OutlinedButton.icon(
                              onPressed: _saving || _pickingProof
                                  ? null
                                  : () => _pickProof('file'),
                              icon: const Icon(Icons.attach_file),
                              label: Text(t('Attach proof',
                                  'Joindre un justificatif', 'إرفاق إثبات'))),
                        ]),
                        if (_proof != null)
                          ListTile(
                              title: Text(_proof!.name),
                              trailing: IconButton(
                                  icon: const Icon(Icons.close),
                                  onPressed: _saving
                                      ? null
                                      : () => setState(() => _proof = null))),
                        FilledButton(
                            onPressed: _saving || _pickingProof ? null : _save,
                            child: Text(t('Record payment',
                                'Enregistrer le paiement', 'تسجيل الدفع'))),
                      ],
                    ],
                  ])),
    );
  }
}
