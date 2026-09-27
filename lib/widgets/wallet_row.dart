import 'package:flutter/material.dart';
import 'package:ssr_space/theme/app_theme.dart';
import 'package:ssr_space/utils/strings.dart';
import 'package:ssr_space/widgets/status_chip.dart';
import 'package:ssr_space/widgets/wallet_art.dart';

/// Satu baris di daftar Dompet: ikon jenis + nama + chip jenis + nominal
/// kanan. `balanceText` wajib sudah diformat lewat amt() (atau teks
/// 'Belum termuat') supaya privacy mode "Samarkan nominal" tetap bekerja.
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
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: SsrSpace.sm),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: SsrColors.noirRaised,
              borderRadius: BorderRadius.circular(SsrRadius.tile),
              border: Border.all(color: SsrColors.noirLine),
            ),
            child: Center(child: WalletArt(type)),
          ),
          const SizedBox(width: SsrSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 2),
                StatusChip(label: typeLabel),
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
                  : SsrTheme.money.copyWith(fontSize: 14),
            ),
          ),
        ],
      ),
    );
    final tap = onTap;
    if (tap == null) return row;
    return InkWell(
      onTap: tap,
      borderRadius: BorderRadius.circular(SsrRadius.tile),
      child: row,
    );
  }
}
