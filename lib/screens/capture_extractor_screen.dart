import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:my_app/core/api_exception.dart';
import 'package:my_app/core/extraction_models.dart';
import 'package:my_app/core/permission_service.dart';
import 'package:my_app/l10n/app_localizations.dart';
import 'package:my_app/screens/extraction_review_screen.dart';
import 'package:my_app/screens/product_barcode_scanner_screen.dart';
import 'package:my_app/screens/scan_invoice_screen.dart';
import 'package:my_app/services/extractor_service.dart';
import 'package:my_app/widgets/app_alerts.dart';
import 'package:my_app/widgets/app_top_bar.dart';
import 'package:path/path.dart' as path;

class CaptureExtractorScreen extends StatefulWidget {
  const CaptureExtractorScreen({
    super.key,
    required this.onToggleTheme,
    required this.onChangePrimaryColor,
    required this.onChangeLanguage,
    required this.currentPrimaryColor,
    required this.permissions,
    this.initialFilePaths = const [],
  });

  final VoidCallback onToggleTheme;
  final void Function(Color color) onChangePrimaryColor;
  final void Function(String code) onChangeLanguage;
  final Color currentPrimaryColor;
  final PermissionService permissions;
  final List<String> initialFilePaths;

  @override
  State<CaptureExtractorScreen> createState() => _CaptureExtractorScreenState();
}

class _CaptureExtractorScreenState extends State<CaptureExtractorScreen> {
  static const _documentTypes = XTypeGroup(
    label: 'Invoices and receipts',
    extensions: ['pdf', 'png', 'jpg', 'jpeg', 'tif', 'tiff', 'bmp', 'webp'],
    uniformTypeIdentifiers: [
      'com.adobe.pdf',
      'public.png',
      'public.jpeg',
      'public.tiff',
      'com.microsoft.bmp',
      'public.webp',
    ],
  );

  final _extractor = ExtractorService();
  late final List<String> _filePaths;
  ExtractionBatch? _batch;
  String? _error;
  bool _running = false;
  double _uploadProgress = 0;

  PermissionService get _permissions => widget.permissions;
  bool get _canExtract => _permissions.can(AppPermission.extractorUse);

  @override
  void initState() {
    super.initState();
    _filePaths = widget.initialFilePaths.toSet().take(10).toList();
  }

  Future<void> _takePhoto() async {
    final filePath = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => ScanInvoiceScreen(
          onToggleTheme: widget.onToggleTheme,
          onChangePrimaryColor: widget.onChangePrimaryColor,
          onChangeLanguage: widget.onChangeLanguage,
          currentPrimaryColor: widget.currentPrimaryColor,
        ),
      ),
    );
    if (!mounted || filePath == null || filePath.trim().isEmpty) return;
    _addFiles([filePath]);
  }

  Future<void> _chooseFiles() async {
    try {
      final files = await openFiles(acceptedTypeGroups: const [_documentTypes]);
      if (!mounted || files.isEmpty) return;
      _addFiles(files.map((file) => file.path));
    } catch (error) {
      if (!mounted) return;
      AppAlerts.error(
        context,
        error.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  void _addFiles(Iterable<String> paths) {
    final merged = {..._filePaths, ...paths.where((value) => value.isNotEmpty)};
    setState(() {
      _filePaths
        ..clear()
        ..addAll(merged.take(ExtractorService.maxFiles));
      _batch = null;
      _error = null;
    });
  }

  Future<void> _scanBarcode() async {
    final product = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (_) => const ProductBarcodeScannerScreen()),
    );
    if (!mounted || product == null) return;
    final label = (product['name'] ?? product['code'] ?? '').toString().trim();
    if (label.isNotEmpty) AppAlerts.success(context, label);
  }

  Future<void> _runExtraction() async {
    final l10n = AppLocalizations.of(context)!;
    if (_filePaths.isEmpty) {
      AppAlerts.info(context, l10n.extractorNoFilesSelected);
      return;
    }
    if (!_canExtract) {
      AppAlerts.error(context, l10n.extractorPermissionDenied);
      return;
    }

    setState(() {
      _running = true;
      _uploadProgress = 0;
      _error = null;
      _batch = null;
    });
    try {
      final result = await _extractor.extractFiles(
        _filePaths,
        onProgress: (progress) {
          if (!mounted) return;
          setState(() => _uploadProgress = progress);
        },
      );
      if (!mounted) return;
      setState(() => _batch = result);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = _messageFor(error, l10n));
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  String _messageFor(Object error, AppLocalizations l10n) {
    if (error is ApiException) {
      return switch (error.code) {
        'ENDPOINT_NOT_FOUND' => l10n.extractorServerUpdateRequired,
        'FORBIDDEN' => l10n.extractorPermissionDenied,
        'NETWORK_UNAVAILABLE' => l10n.serverUnavailable,
        'NETWORK_TIMEOUT' => l10n.requestTimedOut,
        _ => error.toString(),
      };
    }
    return error.toString().replaceFirst('Exception: ', '');
  }

  Future<void> _review(ExtractionItem item) async {
    if (item.document == null) return;
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => ExtractionReviewScreen(
          item: item,
          permissions: _permissions,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppTopBar(
        title: l10n.captureCenterTitle,
        onToggleTheme: widget.onToggleTheme,
        onChangePrimaryColor: widget.onChangePrimaryColor,
        onChangeLanguage: widget.onChangeLanguage,
        currentPrimaryColor: widget.currentPrimaryColor,
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 36),
              children: [
                Text(
                  l10n.captureCenterTitle,
                  style: theme.textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.captureCenterSubtitle,
                  style: theme.textTheme.bodyLarge
                      ?.copyWith(color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: 18),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth < 650
                        ? constraints.maxWidth
                        : (constraints.maxWidth - 24) / 3;
                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _CaptureAction(
                          width: width,
                          icon: Icons.photo_camera_outlined,
                          label: l10n.captureTakePhoto,
                          onTap: _running ? null : _takePhoto,
                        ),
                        _CaptureAction(
                          width: width,
                          icon: Icons.upload_file_outlined,
                          label: l10n.captureChooseFiles,
                          onTap: _running ? null : _chooseFiles,
                        ),
                        _CaptureAction(
                          width: width,
                          icon: Icons.qr_code_scanner_rounded,
                          label: l10n.captureScanBarcode,
                          onTap: _running ? null : _scanBarcode,
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 18),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.auto_awesome_rounded, color: cs.primary),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                l10n.extractorTitle,
                                style: theme.textTheme.titleLarge
                                    ?.copyWith(fontWeight: FontWeight.w900),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(l10n.extractorReady),
                        const SizedBox(height: 4),
                        Text(
                          l10n.extractorFileLimits,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: cs.onSurfaceVariant),
                        ),
                        if (!_canExtract) ...[
                          const SizedBox(height: 12),
                          Text(
                            l10n.extractorPermissionDenied,
                            style: TextStyle(
                              color: cs.error,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                        const SizedBox(height: 14),
                        Text(
                          l10n.extractorSelectedFiles(_filePaths.length),
                          style: theme.textTheme.titleSmall,
                        ),
                        if (_filePaths.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          ..._filePaths.asMap().entries.map(
                                (entry) => ListTile(
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  leading:
                                      const Icon(Icons.description_outlined),
                                  title: Text(
                                    path.basename(entry.value),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  trailing: IconButton(
                                    tooltip: l10n.extractorRemoveFile,
                                    onPressed: _running
                                        ? null
                                        : () => setState(() {
                                              _filePaths.removeAt(entry.key);
                                              _batch = null;
                                            }),
                                    icon: const Icon(Icons.close_rounded),
                                  ),
                                ),
                              ),
                        ],
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _running || !_canExtract
                                ? null
                                : _runExtraction,
                            icon: _running
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.2,
                                    ),
                                  )
                                : const Icon(Icons.auto_fix_high_rounded),
                            label: Text(l10n.extractorRun),
                          ),
                        ),
                        if (_running) ...[
                          const SizedBox(height: 12),
                          LinearProgressIndicator(
                            value: _uploadProgress < 1 ? _uploadProgress : null,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _uploadProgress < 1
                                ? l10n.extractorUploading(
                                    (_uploadProgress * 100).round(),
                                  )
                                : l10n.extractorProcessing,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  color: cs.tertiaryContainer.withValues(alpha: .35),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.fact_check_outlined, color: cs.tertiary),
                        const SizedBox(width: 10),
                        Expanded(child: Text(l10n.extractorReviewRequired)),
                      ],
                    ),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Card(
                    color: cs.errorContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Text(
                        _error!,
                        style: TextStyle(color: cs.onErrorContainer),
                      ),
                    ),
                  ),
                ],
                if (_batch != null) ...[
                  const SizedBox(height: 18),
                  _BatchSummaryCard(summary: _batch!.summary),
                  const SizedBox(height: 12),
                  ..._batch!.items.map(
                    (item) => _ExtractionResultCard(
                      item: item,
                      onReview: () => _review(item),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CaptureAction extends StatelessWidget {
  const _CaptureAction({
    required this.width,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final double width;
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: width,
        child: Card(
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Icon(icon, size: 30),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      label,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}

class _BatchSummaryCard extends StatelessWidget {
  const _BatchSummaryCard({required this.summary});

  final ExtractionSummary summary;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 24,
          runSpacing: 12,
          children: [
            _metric(
              l10n.extractorBatchSummary(
                summary.processed,
                summary.requested,
              ),
              Icons.task_alt_rounded,
            ),
            _metric(
              '${l10n.extractorSuccessRate}: ${summary.successRate.toStringAsFixed(0)}%',
              Icons.speed_rounded,
            ),
            _metric(
              '${l10n.extractorPages}: ${summary.totalPages}',
              Icons.file_copy_outlined,
            ),
          ],
        ),
      ),
    );
  }

  Widget _metric(String text, IconData icon) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 7),
          Text(text, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      );
}

class _ExtractionResultCard extends StatelessWidget {
  const _ExtractionResultCard({required this.item, required this.onReview});

  final ExtractionItem item;
  final VoidCallback onReview;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final document = item.document;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  item.success
                      ? Icons.check_circle_outline
                      : Icons.error_outline,
                  color: item.success ? cs.primary : cs.error,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    item.fileName,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                Text(item.sizeLabel),
              ],
            ),
            const SizedBox(height: 8),
            if (document != null) ...[
              Text(
                [
                  document.invoiceNumber,
                  document.supplierName,
                  if (document.total != null)
                    '${document.total!.toStringAsFixed(3)} ${document.currency}',
                ].where((value) => value.isNotEmpty).join(' · '),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: LinearProgressIndicator(
                      value: document.overallConfidence,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    l10n.extractorConfidence(
                      (document.overallConfidence * 100).round(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: FilledButton.tonalIcon(
                  onPressed: onReview,
                  icon: const Icon(Icons.fact_check_outlined),
                  label: Text(l10n.extractorReview),
                ),
              ),
            ] else
              Text(
                item.error.isEmpty ? l10n.extractorFailed : item.error,
                style: TextStyle(color: cs.error),
              ),
          ],
        ),
      ),
    );
  }
}
