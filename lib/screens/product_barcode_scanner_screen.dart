import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:my_app/l10n/app_localizations.dart';
import 'package:my_app/storage/products_repo.dart';

class ProductBarcodeScannerScreen extends StatefulWidget {
  const ProductBarcodeScannerScreen({super.key});
  @override
  State<ProductBarcodeScannerScreen> createState() =>
      _ProductBarcodeScannerScreenState();
}

class _ProductBarcodeScannerScreenState
    extends State<ProductBarcodeScannerScreen> {
  final _scanner = MobileScannerController(formats: const [BarcodeFormat.all]);
  final _repo = ProductsRepo();
  bool _lookupRunning = false;
  String? _message;

  Future<void> _detected(BarcodeCapture capture) async {
    if (_lookupRunning) return;
    final value = capture.barcodes.firstOrNull?.rawValue?.trim();
    if (value == null || value.isEmpty) return;
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _lookupRunning = true;
      _message = '${l10n.lookingUpBarcode}: $value…';
    });
    await _scanner.stop();
    try {
      final product = await _repo.findByBarcode(value);
      if (mounted) Navigator.pop(context, product);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _lookupRunning = false;
        _message = l10n.productNotFoundBarcode;
      });
      await _scanner.start();
    }
  }

  @override
  void dispose() {
    _scanner.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final instruction = _message ?? l10n.pointCameraBarcode;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.scanProduct),
        actions: [
          IconButton(
            tooltip: l10n.toggleTorch,
            onPressed: _scanner.toggleTorch,
            icon: const Icon(Icons.flashlight_on_outlined),
          ),
        ],
      ),
      body: Semantics(
        label: instruction,
        liveRegion: _lookupRunning,
        child: Stack(
          children: [
            MobileScanner(controller: _scanner, onDetect: _detected),
            ExcludeSemantics(
              child: Center(
                child: Container(
                  width: 280,
                  height: 150,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white, width: 3),
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
              ),
            ),
            PositionedDirectional(
              start: 20,
              end: 20,
              bottom: 36,
              child: Card(
                color: Colors.black87,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Text(
                    instruction,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
