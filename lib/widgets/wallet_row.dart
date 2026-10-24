import 'package:flutter/material.dart';
import 'package:ssr_space/theme/app_theme.dart';
import 'package:ssr_space/theme/dribbble_tokens.dart';
import 'package:ssr_space/utils/strings.dart';
import 'package:ssr_space/widgets/wallet_art.dart';

/// Satu baris di daftar Dompet: ikon jenis + nama + chip jenis + nominal
/// kanan. `balanceText` wajib sudah diformat lewat amt() (atau teks
/// 'Belum termuat') supaya privacy mode "Samarkan nominal" tetap bekerja.
/// Pasangan pastel ikon per jenis dompet ala frame Dompet mockup:
/// kotak pastel rounded + ikon/glyph brand di tengah.
({Color bg, Color fg}) walletTypePastel(String type) {
  switch (type) {
    case 'bank':
      return (bg: const Color(0xFFCFF5DA), fg: const Color(0xFF1F7A4D));
    case 'ewallet':
      return (bg: DribTokens.purpleBg, fg: DribTokens.purple);
    case 'savings':
      return (bg: const Color(0xFFD9F5E9), fg: DribTokens.successText);
    case 'investment':
      return (bg: const Color(0xFFFFF0C2), fg: const Color(0xFFA87B0A));
    default:
      return (bg: DribTokens.blueLight, fg: DribTokens.primaryStrong);
  }
}

class WalletRow extends StatelessWidget {
  final String name;
  final String type;
  final String typeLabel;
  final String balanceText;
  final VoidCallback? onTap;

  const WalletRow({
    super.key,
    required this.name,
    required this.type,
    required this.typeLabel,
    required this.balanceText,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final pastel = walletTypePastel(type);
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: SsrSpace.sm),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: pastel.bg,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(child: WalletArt(type, name: name)),
          ),
          const SizedBox(width: SsrSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: DribTokens.navy,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  typeLabel,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: DribTokens.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: SsrSpace.sm),
          Flexible(
            child: Text(
              balanceText,
              textAlign: TextAlign.end,
              style: balanceText == tr('w_notloaded')
                  ? Theme.of(context).textTheme.bodySmall
                  : const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13.5,
                      color: DribTokens.navy,
                      fontFeatures: [
                        FontFeature.tabularFigures()
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
    final tap = onTap;
    if (tap == null) return row;
    return InkWell(
      onTap: tap,
      borderRadius: BorderRadius.circular(20),
      child: row,
    );
  }
}
