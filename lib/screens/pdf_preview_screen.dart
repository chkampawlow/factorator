import 'dart:typed_data';
import 'package:flutter/material.dart';
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

    if (pdfBytes.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: Text(safeTitle),
        ),
        body: const Center(
          child: Text('PDF is empty'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(safeTitle),
      ),
      body: PdfPreview(
        build: (format) async => pdfBytes,
        canChangePageFormat: false,
        canDebug: false,
        allowPrinting: true,
        allowSharing: true,
        loadingWidget: const Center(
          child: CircularProgressIndicator(),
        ),
      ),
    );
  }
}