import 'package:flutter/material.dart';
import 'package:ssr_space/theme/dribbble_tokens.dart';

/// Kartu saldo gradient navy TAHAP 3 restyle (komponen baru, tak dipakai
/// layar mana pun dulu — wiring tahap lanjutan).
///
/// Teks selalu putih di atas gradient [DribTokens.balanceGradient].
class BalanceCard extends StatelessWidget {
  /// Label kecil di atas angka (mis. "Total saldo").
  final String label;

  /// Nominal yang sudah diformat (mis. via amt()).
  final String amount;

  /// Baris tambahan di bawah angka (mis. chip status / keterangan).
  final Widget? footer;

  const BalanceCard({
    super.key,
    required this.label,
    required this.amount,
    this.footer,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: DribTokens.balanceGradient,
        borderRadius:
            BorderRadius.circular(DribTokens.sheetRadius),
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
          Text(
            amount,
            style: DribTokens.bigNumber(size: 34, color: DribTokens.onNavy),
          ),
          if (footer != null) ...[
            const SizedBox(height: 12),
            footer!,
          ],
        ],
      ),
    );
  }
}
