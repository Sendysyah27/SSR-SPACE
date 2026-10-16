import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:ssr_space/theme/dribbble_tokens.dart';

/// Baris transaksi gaya referensi TAHAP 3 (baru, belum dipakai layar).
///
/// Ikon kategori dalam kotak membulat pastel + nama + tanggal, nominal
/// tabular rata kanan (hijau masuk / merah keluar).
class TransactionItem extends StatelessWidget {
  /// Path aset SVG ikon kategori (lihat svgForCategory).
  final String iconSvg;

  /// Warna ikon di atas kotak pastel (kotak = warna 14% alpha).
  final Color tint;

  /// Nama transaksi / kategori.
  final String title;

  /// Tanggal tampil ("26 Sep 2026 • 12:04").
  final String date;

  /// Nominal yang sudah diformat (mis. via amt()).
  final String amount;

  /// True = pemasukan (hijau), false = pengeluaran (merah).
  final bool isIncome;

  /// True = netral navy (mis. transfer). Mengalahkan [isIncome].
  final bool neutral;

  final VoidCallback? onTap;

  const TransactionItem({
    super.key,
    required this.iconSvg,
    required this.tint,
    required this.title,
    required this.date,
    required this.amount,
    required this.isIncome,
    this.neutral = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius:
            BorderRadius.circular(DribTokens.cardRadius),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: tint.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: SvgPicture.asset(
                    iconSvg,
                    width: 24,
                    height: 24,
                    colorFilter: ColorFilter.mode(tint, BlendMode.srcIn),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      date,
                      style: TextStyle(
                        fontSize: 12,
                        color: DribTokens.navy.withValues(alpha: 0.55),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                amount,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: neutral
                      ? DribTokens.navy
                      : isIncome
                          ? Colors.green.shade700
                          : Colors.red.shade700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
