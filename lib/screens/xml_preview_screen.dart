import 'package:flutter/material.dart';

class XmlPreviewScreen extends StatelessWidget {
  final String xmlContent;

  const XmlPreviewScreen({
    super.key,
    required this.xmlContent,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Invoice XML"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(.35),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant.withOpacity(.25),
            ),
          ),
          child: SingleChildScrollView(
            child: SelectableText(
              xmlContent,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ),
        ),
      ),
    );
  }
}