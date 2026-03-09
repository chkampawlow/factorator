import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class XmlPreviewScreen extends StatelessWidget {
  final String xmlContent;

  const XmlPreviewScreen({
    super.key,
    required this.xmlContent,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Invoice XML"),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy),
            tooltip: "Copy XML",
            onPressed: () {
              Clipboard.setData(ClipboardData(text: xmlContent));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("XML copied to clipboard")),
              );
            },
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cs.surfaceVariant.withOpacity(.4),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: cs.outline.withOpacity(.25),
            ),
          ),
          child: Scrollbar(
            child: SingleChildScrollView(
              child: SelectableText(
                xmlContent,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}