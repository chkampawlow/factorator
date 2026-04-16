import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:my_app/l10n/app_localizations.dart';
import 'package:my_app/widgets/app_top_bar.dart';

class ScanInvoiceScreen extends StatefulWidget {
  final VoidCallback onToggleTheme;
  final void Function(Color color) onChangePrimaryColor;
  final void Function(String code) onChangeLanguage;
  final Color currentPrimaryColor;

  // After capture, we’ll return the image path:
  // Navigator.pop(context, imagePath);

  const ScanInvoiceScreen({
    super.key,
    required this.onToggleTheme,
    required this.onChangePrimaryColor,
    required this.onChangeLanguage,
    required this.currentPrimaryColor,
  });

  @override
  State<ScanInvoiceScreen> createState() => _ScanInvoiceScreenState();
}

class _ScanInvoiceScreenState extends State<ScanInvoiceScreen> {
  CameraController? _controller;
  bool _initializing = true;
  bool _taking = false;
  bool _flashOn = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    setState(() {
      _initializing = true;
      _error = null;
    });

    final perm = await Permission.camera.request();
    if (!perm.isGranted) {
      setState(() {
        _initializing = false;
        _error = 'Camera permission denied';
      });
      return;
    }

    try {
      final cams = await availableCameras();
      final back = cams.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cams.first,
      );

      final c = CameraController(
        back,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      await c.initialize();
      await c.setFlashMode(FlashMode.off);

      if (!mounted) return;
      setState(() {
        _controller = c;
        _initializing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _initializing = false;
        _error = e.toString();
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _toggleFlash() async {
    final c = _controller;
    if (c == null) return;

    try {
      final next = !_flashOn;
      await c.setFlashMode(next ? FlashMode.torch : FlashMode.off);
      if (!mounted) return;
      setState(() => _flashOn = next);
    } catch (_) {}
  }

  Future<void> _pickFromGallery() async {
    // Ask permission before opening gallery
    PermissionStatus perm;
    if (Platform.isIOS) {
      perm = await Permission.photos.request();
    } else {
      // Android: READ_MEDIA_IMAGES (API 33+) is mapped by permission_handler to `photos`.
      // On some devices you may still need `storage`.
      perm = await Permission.photos.request();
      if (!perm.isGranted) {
        perm = await Permission.storage.request();
      }
    }

    if (!perm.isGranted) {
      if (!mounted) return;
      setState(() => _error = 'Gallery permission denied');
      return;
    }

    final picker = ImagePicker();
    final x = await picker.pickImage(source: ImageSource.gallery, imageQuality: 95);
    if (x == null) return;

    if (!mounted) return;
    Navigator.pop(context, x.path);
  }

  Future<void> _capture() async {
    final c = _controller;
    if (c == null || _taking) return;

    setState(() => _taking = true);
    try {
      final x = await c.takePicture();

      // Optionally copy to app dir for stable path
      final dir = await getApplicationDocumentsDirectory();
      final out = File('${dir.path}/scan_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await File(x.path).copy(out.path);

      if (!mounted) return;
      Navigator.pop(context, out.path);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _taking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppTopBar(
        title: l10n.scanInvoiceTitle,
        onToggleTheme: widget.onToggleTheme,
        onChangePrimaryColor: widget.onChangePrimaryColor,
        onChangeLanguage: widget.onChangeLanguage,
        currentPrimaryColor: widget.currentPrimaryColor,
      ),
      body: SafeArea(
        top: false,
        child: _initializing
            ? const Center(child: CircularProgressIndicator())
            : (_error != null)
                ? Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.error, style: theme.textTheme.titleLarge),
                        const SizedBox(height: 8),
                        Text(_error!, style: TextStyle(color: cs.error)),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: _init,
                          icon: const Icon(Icons.refresh),
                          label: Text(l10n.retry),
                        ),
                      ],
                    ),
                  )
                : _buildCameraUi(context),
      ),
    );
  }

  Widget _buildCameraUi(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final c = _controller!;

    return Stack(
      children: [
        // camera preview
        Positioned.fill(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(0),
            child: CameraPreview(c),
          ),
        ),

        // dark top/bottom gradient like your screenshot
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFF0B1F2A).withOpacity(0.88),
                  Colors.transparent,
                  Colors.transparent,
                  const Color(0xFF0B1F2A).withOpacity(0.88),
                ],
              ),
            ),
          ),
        ),

        // scan frame corners
        Positioned.fill(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 90, 28, 160),
            child: CustomPaint(
              painter: _ScanFramePainter(color: const Color(0xFF16C7FF)),
            ),
          ),
        ),

        // top left chip "Facture"
        Positioned(
          left: 18,
          top: 18,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.white.withOpacity(0.15)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.receipt_long_outlined, color: Colors.white, size: 18),
                const SizedBox(width: 10),
                Text(
                  l10n.invoice,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ),

        // top right flash button
        Positioned(
          right: 18,
          top: 14,
          child: _RoundButton(
            icon: _flashOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
            onTap: _toggleFlash,
          ),
        ),

        // guidance bar
        Positioned(
          left: 18,
          right: 18,
          bottom: 140,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.35),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withOpacity(0.10)),
            ),
            child: Row(
              children: [
                const Icon(Icons.auto_awesome_rounded, color: Color(0xFF16C7FF), size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l10n.scanInvoiceAlign, // “Alignez la facture dans le cadre”
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),

        // bottom controls
        Positioned(
          left: 0,
          right: 0,
          bottom: 18,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _RoundButton(
                icon: Icons.photo_library_outlined,
                onTap: _pickFromGallery,
              ),
              const SizedBox(width: 26),
              _CaptureButton(
                onTap: _taking ? null : _capture,
              ),
              const SizedBox(width: 26),
              _RoundButton(
                icon: Icons.tune_rounded,
                onTap: () {
                  // later: crop/edges/settings
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RoundButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _RoundButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 54,
        height: 54,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(enabled ? 0.12 : 0.08),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withOpacity(0.14)),
        ),
        child: Icon(icon, color: Colors.white, size: 24),
      ),
    );
  }
}

class _CaptureButton extends StatelessWidget {
  final VoidCallback? onTap;

  const _CaptureButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 86,
        height: 86,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFF16C7FF).withOpacity(0.55), width: 3),
        ),
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: enabled ? const Color(0xFF16C7FF) : Colors.white24,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF16C7FF).withOpacity(0.35),
                blurRadius: 18,
                offset: const Offset(0, 8),
              )
            ],
          ),
          child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 34),
        ),
      ),
    );
  }
}

class _ScanFramePainter extends CustomPainter {
  final Color color;
  const _ScanFramePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const corner = 52.0;
    final rect = Offset.zero & size;

    // top-left
    canvas.drawLine(rect.topLeft, rect.topLeft + const Offset(corner, 0), paint);
    canvas.drawLine(rect.topLeft, rect.topLeft + const Offset(0, corner), paint);
    // top-right
    canvas.drawLine(rect.topRight, rect.topRight + const Offset(-corner, 0), paint);
    canvas.drawLine(rect.topRight, rect.topRight + const Offset(0, corner), paint);
    // bottom-left
    canvas.drawLine(rect.bottomLeft, rect.bottomLeft + const Offset(corner, 0), paint);
    canvas.drawLine(rect.bottomLeft, rect.bottomLeft + const Offset(0, -corner), paint);
    // bottom-right
    canvas.drawLine(rect.bottomRight, rect.bottomRight + const Offset(-corner, 0), paint);
    canvas.drawLine(rect.bottomRight, rect.bottomRight + const Offset(0, -corner), paint);
  }

  @override
  bool shouldRepaint(covariant _ScanFramePainter oldDelegate) => oldDelegate.color != color;
}