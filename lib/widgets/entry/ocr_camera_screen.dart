import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:ssr_space/utils/strings.dart';

/// Layar kamera khusus Scan OCR: pratinjau + toggle flash + tombol ambil.
///
/// Kembalikan path file foto, atau null bila dibatalkan.
Future<String?> openOcrCamera(BuildContext context) {
  return Navigator.of(context).push<String>(
    MaterialPageRoute(builder: (_) => const _OcrCameraScreen()),
  );
}

class _OcrCameraScreen extends StatefulWidget {
  const _OcrCameraScreen();

  @override
  State<_OcrCameraScreen> createState() => _OcrCameraScreenState();
}

class _OcrCameraScreenState extends State<_OcrCameraScreen> {
  CameraController? _controller;
  String? _err;
  var _flashOn = false;
  var _busy = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) setState(() => _err = tr('ocr_cam_none'));
        return;
      }
      final controller = CameraController(
        cameras.first,
        ResolutionPreset.high,
        enableAudio: false,
      );
      await controller.initialize();
      if (!mounted) {
        controller.dispose();
        return;
      }
      setState(() => _controller = controller);
    } catch (e) {
      if (mounted) setState(() => _err = e.toString());
    }
  }

  Future<void> _toggleFlash() async {
    final c = _controller;
    if (c == null) return;
    setState(() => _flashOn = !_flashOn);
    try {
      await c.setFlashMode(_flashOn ? FlashMode.torch : FlashMode.off);
    } catch (_) {
      if (mounted) setState(() => _flashOn = !_flashOn);
    }
  }

  Future<void> _capture() async {
    final c = _controller;
    if (c == null || _busy) return;
    setState(() => _busy = true);
    try {
      final img = await c.takePicture();
      if (!mounted) return;
      Navigator.of(context).pop(img.path);
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _err = e.toString();
        });
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final c = _controller;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(tr('ocr_cam_title')),
        actions: [
          IconButton(
            tooltip: tr('ocr_flash'),
            icon: Icon(
              _flashOn ? Icons.flash_on : Icons.flash_off,
              color: _flashOn ? Colors.amber : Colors.white,
            ),
            onPressed: c == null ? null : _toggleFlash,
          ),
        ],
      ),
      body: _err != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  _err!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            )
          : c == null
              ? const Center(child: CircularProgressIndicator())
              : Stack(
                  fit: StackFit.expand,
                  children: [
                    CameraPreview(c),
                    // Bingkai panduan struk
                    Center(
                      child: Container(
                        width: MediaQuery.of(context).size.width * 0.85,
                        height: MediaQuery.of(context).size.height * 0.55,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.6),
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 32,
                      child: Center(
                        child: GestureDetector(
                          onTap: _capture,
                          child: Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                              border: Border.all(
                                color: scheme.primary,
                                width: 4,
                              ),
                            ),
                            child: _busy
                                ? const Padding(
                                    padding: EdgeInsets.all(20),
                                    child: CircularProgressIndicator(
                                      strokeWidth: 3,
                                    ),
                                  )
                                : null,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}
