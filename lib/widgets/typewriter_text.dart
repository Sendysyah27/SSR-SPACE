import 'dart:async';

import 'package:flutter/material.dart';

// Teks mesin tik Mode Asisten (batch 285 tahap A, pola _TypewriterText
// Ollo): teks balasan yang SUDAH diterima utuh dirender progresif di
// sisi klien — tanpa perubahan protokol/server. Kecepatan stabil dan
// adaptif: teks panjang dipercepat agar selesai <= ~2,8 detik. Ketuk
// teks -> tampil utuh seketika. Satu Timer.periodic ringan; timer
// dibatalkan saat selesai, saat diketuk, dan saat widget dibuang.

/// Durasi total target reveal untuk teks sepanjang [length] char:
/// 28 ms/char, dibatasi 400 ms .. 2800 ms. Murni (testable).
int typewriterDurationMs(int length) {
  if (length <= 0) return 0;
  final ms = length * 28;
  if (ms < 400) return 400;
  if (ms > 2800) return 2800;
  return ms;
}

/// Jumlah karakter yang tampil setelah [elapsedMs] ms untuk teks
/// sepanjang [length]. 0 di awal, [length] di akhir. Murni.
int typewriterShown(int length, int elapsedMs) {
  if (length <= 0) return 0;
  if (elapsedMs <= 0) return 0;
  final total = typewriterDurationMs(length);
  if (elapsedMs >= total) return length;
  final n = (length * elapsedMs) ~/ total;
  return n < 1 ? 1 : n;
}

class TypewriterText extends StatefulWidget {
  final String text;
  final TextStyle? style;

  /// Dipanggil sekali saat reveal selesai (tuntas atau diketuk).
  final VoidCallback? onDone;

  const TypewriterText({
    super.key,
    required this.text,
    this.style,
    this.onDone,
  });

  @override
  State<TypewriterText> createState() => _TypewriterTextState();
}

class _TypewriterTextState extends State<TypewriterText> {
  static const _tickMs = 30;
  Timer? _timer;
  int _elapsed = 0;
  int _shown = 0;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    if (widget.text.isEmpty) {
      _done = true;
      return;
    }
    _timer = Timer.periodic(const Duration(milliseconds: _tickMs), (_) {
      if (!mounted) return;
      _elapsed += _tickMs;
      final n = typewriterShown(widget.text.length, _elapsed);
      if (n >= widget.text.length) {
        setState(() => _shown = widget.text.length);
        _finish();
      } else if (n != _shown) {
        setState(() => _shown = n);
      }
    });
  }

  void _finish() {
    _timer?.cancel();
    _timer = null;
    if (_done) return;
    _done = true;
    widget.onDone?.call();
  }

  void _skip() {
    if (_done) return;
    setState(() => _shown = widget.text.length);
    _finish();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timer = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shown = _shown > widget.text.length ? widget.text.length : _shown;
    return GestureDetector(
      onTap: _skip,
      child: Text(
        widget.text.substring(0, shown),
        style: widget.style,
      ),
    );
  }
}
