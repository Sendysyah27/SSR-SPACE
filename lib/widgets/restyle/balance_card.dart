import 'package:flutter/material.dart';
import 'package:ssr_space/services/app_settings.dart';
import 'package:ssr_space/theme/dribbble_tokens.dart';

/// Kartu saldo gradient TAHAP 3 restyle.
///
/// Varian gradient: 'navy' (bawaan, [DribTokens.balanceGradient]), 'ocean'
/// ([DribTokens.oceanDeep]), 'midnight' ([DribTokens.midnightBlue]),
/// 'steel' ([DribTokens.steelBlue]).
///
/// Teks selalu putih ([DribTokens.onNavy]) di atas semua varian.
///
/// [themeId] = varian tetap. Null = ikut pengaturan global [cardTheme]
/// (diubah dari Pengaturan > Tema kartu saldo) dan ikut berubah otomatis.
class BalanceCard extends StatelessWidget {
  /// Label kecil di atas angka (mis. "Total saldo").
  final String label;

  /// Nominal yang sudah diformat (mis. via amt()).
  final String amount;

  /// Baris tambahan di bawah angka (mis. chip status / keterangan).
  final Widget? footer;

  /// Varian gradient tetap; null = ikut [cardTheme] global.
  final String? themeId;

  /// Tap pada angka nominal (mis. ke Laporan). Null = tidak bisa di-tap.
  final VoidCallback? onAmountTap;

  const BalanceCard({
    super.key,
    required this.label,
    required this.amount,
    this.footer,
    this.themeId,
    this.onAmountTap,
  });

  /// Gradient untuk satu id tema; tak dikenal -> navy (bawaan).
  static LinearGradient _gradientFor(String id) {
    if (id == 'ocean') return DribTokens.oceanDeep;
    if (id == 'midnight') return DribTokens.midnightBlue;
    if (id == 'steel') return DribTokens.steelBlue;
    return DribTokens.balanceGradient;
  }

  Widget _card(LinearGradient gradient) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(DribTokens.sheetRadius),
        boxShadow: DribTokens.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            label,
            style: TextStyle(
              color: DribTokens.onNavy.withValues(alpha: 0.75),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: onAmountTap,
            behavior:
                onAmountTap == null ? null : HitTestBehavior.opaque,
            child: Text(
              amount,
              style: DribTokens.bigNumber(size: 34, color: DribTokens.onNavy),
            ),
          ),
          if (footer != null) ...[
            const SizedBox(height: 12),
            footer!,
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fixed = themeId;
    if (fixed != null) return _card(_gradientFor(fixed));
    return ValueListenableBuilder<String>(
      valueListenable: cardTheme,
      builder: (context, value, _) => _card(_gradientFor(value)),
    );
  }
}
