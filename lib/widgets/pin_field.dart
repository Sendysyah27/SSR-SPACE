import 'package:flutter/material.dart';
import 'package:ssr_space/theme/app_theme.dart';
import 'package:ssr_space/theme/dribbble_tokens.dart';

/// Baris titik PIN (13px ala mockup), display-only, tanpa TextField.
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

  /// Satu titik PIN 13px ala frame mockup grup Auth: lingkaran border
  /// 2px navy; terisi = navy penuh, kosong = transparan. Kolom yang
  /// tidak sedang dipilih (form dua kolom) cincinnya lebih redup.
  /// Mode non-obscure tidak dipakai pemanggil mana pun — indikator
  /// selalu titik, digit mentah tidak pernah digambar.
  Widget _box(BuildContext context, int i, bool filled) {
    final scheme = Theme.of(context).colorScheme;
    final base = widget.digitColor ?? DribTokens.navy;
    final ring = widget.error != null
        ? scheme.error
        : base.withValues(alpha: widget.selected ? 1 : 0.35);
    return Container(
      width: 13,
      height: 13,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: filled
            ? (widget.error != null ? scheme.error : base)
            : Colors.transparent,
        border: Border.all(color: ring, width: 2),
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
                  if (i > 0) const SizedBox(width: 13),
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
