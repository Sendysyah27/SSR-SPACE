import 'package:flutter/material.dart';
import 'package:ssr_space/theme/dribbble_tokens.dart';

/// Tombol geser-untuk-konfirmasi TAHAP 3 (baru, belum dipakai layar).
///
/// Niat: gantikan dialog hapus transaksi (wiring tahap lanjutan — perilaku
/// hapus saat ini TIDAK diubah). Geser jempol ke ujung kanan melewati
/// ambang = [onConfirm] sekali, lalu jempol kembali sendiri.
///
/// Tanpa animasi berat: satu pergeseran posisi mengikuti jari + kembali
/// 200ms bila dilepas sebelum ambang.
class SwipeToConfirmButton extends StatefulWidget {
  /// Teks badan tombol (mis. "Geser untuk menghapus").
  final String label;

  /// Ikon jempol geser.
  final IconData icon;

  /// Dipanggil tepat sekali saat geser melewati ambang.
  final VoidCallback onConfirm;

  /// Nonaktif = abu, tak bisa digeser.
  final bool enabled;

  const SwipeToConfirmButton({
    super.key,
    required this.label,
    required this.onConfirm,
    this.icon = Icons.delete_outline,
    this.enabled = true,
  });

  @override
  State<SwipeToConfirmButton> createState() => _SwipeToConfirmButtonState();
}

class _SwipeToConfirmButtonState extends State<SwipeToConfirmButton>
    with SingleTickerProviderStateMixin {
  double _dx = 0;
  bool _fired = false;

  static const double _thumb = 48;
  static const double _pad = 4;

  void _reset() {
    if (!mounted) return;
    setState(() => _dx = 0);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth;
        // Ambang 70% lebar; lebar tak terbatas = tombol mati aman.
        final threshold =
            maxW.isFinite ? (maxW - _thumb - _pad * 2) * 0.7 : -1.0;
        final travel = (maxW.isFinite ? maxW - _thumb - _pad * 2 : 0.0)
            .clamp(0.0, double.infinity);
        final pos = _dx.clamp(0.0, travel);
        return Opacity(
          opacity: widget.enabled ? 1 : 0.5,
          child: Container(
            height: 56,
            decoration: BoxDecoration(
              color: DribTokens.navy,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Stack(
              children: [
                Center(
                  child: Text(
                    widget.label,
                    style: TextStyle(
                      color: DribTokens.onNavy.withValues(alpha: 0.85),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Positioned(
                  left: _pad + pos,
                  top: _pad,
                  child: GestureDetector(
                    onHorizontalDragUpdate: (d) {
                      if (!widget.enabled || _fired) return;
                      setState(() => _dx += d.delta.dx);
                    },
                    onHorizontalDragEnd: (_) {
                      if (!widget.enabled || _fired) return;
                      if (threshold >= 0 && _dx >= threshold) {
                        _fired = true;
                        widget.onConfirm();
                        Future.delayed(
                          const Duration(milliseconds: 300),
                          () {
                            _fired = false;
                            _reset();
                          },
                        );
                      } else {
                        _reset();
                      }
                    },
                    child: Container(
                      width: _thumb,
                      height: _thumb,
                      decoration: const BoxDecoration(
                        color: DribTokens.primary,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        widget.icon,
                        color: DribTokens.onNavy,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
