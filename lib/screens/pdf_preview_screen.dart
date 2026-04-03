import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:my_app/widgets/app_alerts.dart';
import 'package:my_app/core/api_client.dart';
import 'package:my_app/core/api_config.dart';
import 'package:printing/printing.dart';

class PdfPreviewScreen extends StatefulWidget {
  final Uint8List pdfBytes;
  final String title;
  /// Client email used as recipient. If null/empty, the send-email action is disabled.
  final String? clientEmail;

  const PdfPreviewScreen({
    super.key,
    required this.pdfBytes,
    this.title = 'Invoice PDF',
    this.clientEmail,
  });

  @override
  State<PdfPreviewScreen> createState() => _PdfPreviewScreenState();
}

class _PdfPreviewScreenState extends State<PdfPreviewScreen> {
  bool _sending = false;
  bool _emailSent = false;

  Future<bool> _confirmSendTo(String email) async {
    final cs = Theme.of(context).colorScheme;

    final res = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Send invoice PDF'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('This PDF will be sent to:'),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest.withOpacity(0.55),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: cs.outlineVariant.withOpacity(0.25)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.alternate_email_rounded, color: cs.onSurfaceVariant),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        email,
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: cs.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Continue?',
                style: TextStyle(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Send'),
            ),
          ],
        );
      },
    );

    return res == true;
  }

  @override
  Widget build(BuildContext context) {
    final safeTitle = widget.title.trim().isEmpty ? 'Invoice PDF' : widget.title.trim();
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final screenWidth = MediaQuery.of(context).size.width;
    final clientEmail = widget.clientEmail?.trim() ?? '';
    final canSendEmail = clientEmail.isNotEmpty;

    if (widget.pdfBytes.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: Text(safeTitle),
          centerTitle: true,
        ),
        body: const Center(
          child: Text('PDF is empty'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(safeTitle),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          PdfPreview(
            actions: [
              PdfPreviewAction(
                icon: Icon(
                  _emailSent ? Icons.check_circle_rounded : Icons.send_rounded,
                  color: (!canSendEmail || _emailSent)
                      ? cs.onSurfaceVariant.withOpacity(0.45)
                      : null,
                ),
                onPressed: (context, build, pageFormat) async {
                  if (_sending || _emailSent) return;
                  if (!canSendEmail) {
                    AppAlerts.warning(context, 'Client email is missing');
                    return;
                  }

                  final ok = await _confirmSendTo(clientEmail);
                  if (!ok) return;

                  setState(() {
                    _sending = true;
                  });

                  try {
                    final bytes = await build(pageFormat);

                    final res = await ApiClient.instance.post(
                      ApiConfig.sendInvoicePdf,
                      authRequired: true,
                      body: {
                        'pdf': base64Encode(bytes),
                        'filename': '$safeTitle.pdf',
                        'language': Localizations.localeOf(context).languageCode,

                        // Recipient: send under multiple keys to match backend variations.
                        'to': clientEmail,
                        'email': clientEmail,
                        'client_email': clientEmail,
                        'recipient': clientEmail,
                      },
                    );

                    // Validate backend response when it returns JSON.
                    if (res is Map) {
                      final ok = res['success'] == true || res['ok'] == true;
                      if (!ok) {
                        final msg = (res['message'] ?? res['error'] ?? 'Failed to send email').toString();
                        throw Exception(msg);
                      }
                    }

                    if (!mounted) return;
                    setState(() {
                      _emailSent = true;
                    });
                    AppAlerts.success(context, 'Sent to $clientEmail');
                  } catch (e) {
                    if (!mounted) return;
                    AppAlerts.error(
                      context,
                      e.toString().replaceFirst('Exception: ', ''),
                    );
                  } finally {
                    if (mounted) {
                      setState(() {
                        _sending = false;
                      });
                    }
                  }
                },
              ),
            ],
            build: (format) async => widget.pdfBytes,
            canChangePageFormat: false,
            canChangeOrientation: false,
            canDebug: false,
            allowPrinting: true,
            allowSharing: true,
            enableScrollToPage: true,
            maxPageWidth: screenWidth,
            padding: const EdgeInsets.all(8),
            previewPageMargin: const EdgeInsets.all(8),
            pdfFileName: '$safeTitle.pdf',
            scrollViewDecoration: BoxDecoration(
              color: cs.surface,
            ),
            pdfPreviewPageDecoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: theme.shadowColor.withOpacity(theme.brightness == Brightness.dark ? 0.22 : 0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            actionBarTheme: PdfActionBarTheme(
              backgroundColor: cs.surface,
              iconColor: cs.primary,
            ),
            onError: (context, error) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.picture_as_pdf_outlined,
                      size: 44,
                      color: cs.error,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Unable to preview this PDF',
                      style: theme.textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      error.toString(),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            loadingWidget: const Center(
              child: CircularProgressIndicator(),
            ),
          ),
          if (_sending)
            Positioned.fill(
              child: Container(
                color: cs.scrim.withOpacity(0.18),
                child: const Center(
                  child: Card(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text('Sending email...'),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}