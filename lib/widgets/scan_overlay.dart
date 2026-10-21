import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ssr_space/theme/app_theme.dart';
import 'package:ssr_space/utils/strings.dart';

// Overlay animasi selama OCR berjalan (kamera maupun galeri — keduanya
// lewat fase proses yang sama): tirai gelap + bingkai + garis laser
// menyapu vertikal. Batas jujur: pengambilan gambar memakai intent
// kamera sistem (tanpa preview in-app), jadi laser live saat bidik
// butuh plugin kamera — di luar scope; animasi ini menutup fase proses.
class ScanOverlay extends StatelessWidget {
  const ScanOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: Colors.black54,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _LaserBox(),
              const SizedBox(height: SsrSpace.md),
              ScanStatusText(
                // Style dari Theme (runtime) — SENGAJA non-const:
                // const di rantai overlay ini memicu konflik
                // prefer_const_* vs const_with_non_const di
                // analyzer CI (Container tak bisa const di sana).
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Kotak struk + laser menyapu (1.4 dtk bolak-balik, repaint kecil).
class _LaserBox extends StatefulWidget {
  const _LaserBox();

  @override
  State<_LaserBox> createState() => _LaserBoxState();
}

class _LaserBoxState extends State<_LaserBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 240,
      height: 160,
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, _) => CustomPaint(
          painter: _LaserPainter(progress: _c.value, color: scheme.primary),
        ),
      ),
    );
  }
}

class _LaserPainter extends CustomPainter {
  final double progress;
  final Color color;

  _LaserPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final corner = Paint()
      ..color = Colors.white
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    const arm = 22.0;
    final w = size.width;
    final h = size.height;
    // Empat sudut bingkai.
    canvas.drawLine(const Offset(0, arm), Offset.zero, corner);
    canvas.drawLine(Offset.zero, const Offset(arm, 0), corner);
    canvas.drawLine(Offset(w - arm, 0), Offset(w, 0), corner);
    canvas.drawLine(Offset(w, 0), Offset(w, arm), corner);
    canvas.drawLine(Offset(w, h - arm), Offset(w, h), corner);
    canvas.drawLine(Offset(w, h), Offset(w - arm, h), corner);
    canvas.drawLine(Offset(arm, h), Offset(0, h), corner);
    canvas.drawLine(Offset(0, h), Offset(0, h - arm), corner);
    // Garis laser + pijar.
    final y = 12 + progress * (h - 24);
    final glow = Paint()
      ..color = color.withValues(alpha: 0.35)
      ..strokeWidth = 8;
    final beam = Paint()
      ..color = color
      ..strokeWidth = 2.5;
    canvas.drawLine(Offset(8, y), Offset(w - 8, y), glow);
    canvas.drawLine(Offset(8, y), Offset(w - 8, y), beam);
  }

  @override
  bool shouldRepaint(_LaserPainter old) => old.progress != progress;
}

/// Teks status scan berjalan (batch 284 tahap D, pola teks status
/// Ollo): "Memindai struk…" lalu "Menganalisis…" bergantian selama
/// proses scan berjalan — tanpa animasi berat / library baru.
class ScanStatusText extends StatefulWidget {
  final TextStyle? style;
  final TextAlign? textAlign;
  const ScanStatusText({super.key, this.style, this.textAlign});

  @override
  State<ScanStatusText> createState() => _ScanStatusTextState();
}

class _ScanStatusTextState extends State<ScanStatusText> {
  int _phase = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 2600), (_) {
      if (mounted) setState(() => _phase = (_phase + 1) % 2);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      tr(_phase == 0 ? 'scan_status_reading' : 'scan_status_analyzing'),
      style: widget.style,
      textAlign: widget.textAlign,
    );
  }
}
