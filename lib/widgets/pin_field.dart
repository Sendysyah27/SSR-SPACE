import 'package:flutter/material.dart';
import 'package:ssr_space/theme/app_theme.dart';

/// Baris kotak PIN, display-only, tanpa TextField.
///
/// Sengaja TIDAK memakai TextField: keyboard sistem tak pernah dibuka
/// (input lewat `PinPad`) dan border InputDecorationTheme tak bisa bocor
/// jadi pil penuh-lebar di belakang kotak (regresi 2.4.9+37).
/// Isi dibaca dari [controller] lewat listener; ketuk [onCompleted]
/// sekali saat panjang mencapai [length] (guard anti-tembak-ganda).
class PinField extends StatefulWidget {
  final TextEditingController controller;
  final int length;
  final String? error;
  final ValueChanged<String>? onCompleted;
  final bool obscure;

  /// Tandai kolom yang jadi sasaran pad (kosong → border primer).
  /// Form dua-kolom atur ini; satu kolom cukup default.
  final bool selected;

  /// Ketuk kotak → pilih kolom ini sebagai sasaran pad (form dua-kolom).
  final VoidCallback? onTap;

  /// Warna digit eksplisit (mis. putih di atas kartu navy).
  /// Null = scheme.onSurface (latar terang).
  final Color? digitColor;

  const PinField({
    super.key,
    required this.controller,
    this.length = 6,
    this.error,
    this.onCompleted,
    this.obscure = true,
    this.selected = true,
    this.onTap,
    this.digitColor,
  });

  @override
  State<PinField> createState() => _PinFieldState();
}

class _PinFieldState extends State<PinField> {
  bool _fired = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
  }

  void _onChanged() {
    if (mounted) setState(() {});
    final v = widget.controller.text;
    if (v.length < widget.length) {
      _fired = false;
      return;
    }
    if (_fired) return;
    _fired = true;
    widget.onCompleted?.call(v);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    super.dispose();
  }

  Widget _box(BuildContext context, int i, bool filled) {
    final scheme = Theme.of(context).colorScheme;
    final lit = filled || widget.selected;
    return Container(
      width: 40,
      height: 48,
      decoration: BoxDecoration(
        color: filled
            ? scheme.primary.withValues(alpha: 0.08)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(SsrRadius.input),
        border: Border.all(
          color: widget.error != null
              ? scheme.error
              : lit
              ? scheme.primary
              : scheme.outline,
          width: lit || widget.error != null ? 1.5 : 1,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        filled ? (widget.obscure ? '•' : widget.controller.text[i]) : '',
        style: TextStyle(
          fontFamily: SsrFonts.numeric,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: widget.digitColor ?? scheme.onSurface,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = widget.controller.text;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < widget.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  _box(context, i, i < text.length),
                ],
              ],
            ),
          ),
        ),
        if (widget.error != null) ...[
          const SizedBox(height: SsrSpace.xs),
          Text(
            widget.error!,
            style: TextStyle(
              color: Theme.of(context).colorScheme.error,
              fontSize: 12,
            ),
          ),
        ],
      ],
    );
  }
}
