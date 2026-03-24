import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:my_app/core/api_client.dart';
import 'package:my_app/core/api_config.dart';
import 'package:printing/printing.dart';

class PdfPreviewScreen extends StatelessWidget {
  final Uint8List pdfBytes;
  final String title;

  const PdfPreviewScreen({
    super.key,
    required this.pdfBytes,
    this.title = 'Invoice PDF',
  });

  @override
  Widget build(BuildContext context) {
    final safeTitle = title.trim().isEmpty ? 'Invoice PDF' : title.trim();
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final screenWidth = MediaQuery.of(context).size.width;

    if (pdfBytes.isEmpty) {
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
      body: PdfPreview(
        actions: [
          PdfPreviewAction(
            icon: const Icon(Icons.send_rounded),
            onPressed: (context, build, pageFormat) async {
              try {
                final bytes = await build(pageFormat);

                await ApiClient.instance.post(
                  ApiConfig.sendInvoicePdf,
                  authRequired: true,
                  body: {
                    'pdf': base64Encode(bytes),
                    'filename': '$safeTitle.pdf',
                  },
                );

                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('PDF sent successfully'),
                  ),
                );
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      e.toString().replaceFirst('Exception: ', ''),
                    ),
                  ),
                );
              }
            },
          ),
        ],
        build: (format) async => pdfBytes,
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
              color: Colors.black.withOpacity(0.08),
              blurRadius: 16,
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
    );
  }
}