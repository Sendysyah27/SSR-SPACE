import 'package:flutter/material.dart';
import 'package:ssr_space/theme/app_theme.dart';
import 'package:ssr_space/widgets/status_chip.dart';

/// Satu baris di daftar Dompet: ikon dompet + nama + chip jenis + nominal
/// kanan. `balanceText` wajib sudah diformat lewat amt() (atau teks
/// 'Belum termuat') supaya privacy mode "Samarkan nominal" tetap bekerja.
class WalletRow extends StatelessWidget {
  final String name;
  final String typeLabel;
  final String balanceText;

  const WalletRow({
    super.key,
    required this.name,
    required this.typeLabel,
    required this.balanceText,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: SsrSpace.sm),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: SsrColors.accentSoft,
              borderRadius: BorderRadius.circular(SsrRadius.tile),
            ),
            child: const Icon(
              Icons.account_balance_wallet_outlined,
              color: SsrColors.accent,
              size: 22,
            ),
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
              style: balanceText == 'Belum termuat'
                  ? Theme.of(context).textTheme.bodySmall
                  : SsrTheme.money.copyWith(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
