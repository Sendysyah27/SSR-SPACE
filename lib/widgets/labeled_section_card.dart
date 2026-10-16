import 'package:flutter/material.dart';
import 'package:ssr_space/theme/app_icons.dart';
import 'package:ssr_space/theme/app_theme.dart';
import 'package:ssr_space/theme/dribbble_tokens.dart';
import 'package:ssr_space/theme/glass.dart';
import 'package:ssr_space/widgets/section_card.dart';

/// SectionCard dengan label kecil (bodySmall) + jarak xs di atas isi.
/// [icon] opsional: DuoIcon kecil di depan label (hub + settings).
/// Dipakai di seksi hub Lainnya dan Dompet (kartu total aset) -
/// gaya label persis sama di semua pemakai (bodySmall), jadi aman digabung.
class LabeledSectionCard extends StatelessWidget {
  final String label;
  final IconData? icon;
  final List<Widget> children;
  final EdgeInsetsGeometry margin;
  final Color? color;
  final Color? borderColor;

  const LabeledSectionCard({
    super.key,
    required this.label,
    this.icon,
    required this.children,
    this.margin = EdgeInsets.zero,
    this.color,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final ic = icon;
    return SectionCard(
      margin: margin,
      color: color,
      borderColor: borderColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (ic == null)
            Text(label, style: Theme.of(context).textTheme.bodySmall)
          else
            Row(
              children: [
                DuoIcon(
                  ic,
                  size: 14,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: SsrSpace.xs),
                Text(label, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          const SizedBox(height: SsrSpace.xs),
          ...children,
        ],
      ),
    );
  }
}

/// Varian kaca dari [LabeledSectionCard] (Batch 5 — Pengaturan 2.61.0+168).
/// API sama persis (label/icon/children/margin) agar pemakaian bisa
/// diganti 1:1; body dirender di atas [GlassCard] dengan radius kaca.
class GlassLabeledCard extends StatelessWidget {
  final String label;
  final IconData? icon;
  final List<Widget> children;
  final EdgeInsetsGeometry margin;

  const GlassLabeledCard({
    super.key,
    required this.label,
    this.icon,
    required this.children,
    this.margin = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    final ic = icon;
    final m = margin;
    final base = Theme.of(context);
    const labelColor = Colors.white70;
    // TAHAP 10: kartu navy; teks default putih (kontras 14.22:1).
    // Kontrol dengan warna eksplisit (error, emas, dsb.) tak ikut berubah.
    return Container(
      margin: m == EdgeInsets.zero ? null : m,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: DribTokens.navy,
        borderRadius:
            BorderRadius.circular(DribTokens.cardRadius),
        boxShadow: DribTokens.cardShadow,
      ),
      child: Theme(
        data: base.copyWith(
          textTheme: base.textTheme.apply(
            bodyColor: Colors.white,
            displayColor: Colors.white,
          ),
          iconTheme: base.iconTheme.copyWith(color: Colors.white),
          dividerTheme:
              const DividerThemeData(color: Colors.white24),
          inputDecorationTheme:
              base.inputDecorationTheme.copyWith(
            labelStyle:
                const TextStyle(color: labelColor, fontSize: 13),
            hintStyle:
                const TextStyle(color: labelColor, fontSize: 13),
            floatingLabelStyle:
                const TextStyle(color: labelColor, fontSize: 13),
            prefixIconColor: Colors.white70,
            suffixIconColor: Colors.white70,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (ic == null)
              Text(label,
                  style: const TextStyle(color: labelColor))
            else
              Row(
                children: [
                  DuoIcon(
                    ic,
                    size: 14,
                    color: DribTokens.primary,
                  ),
                  const SizedBox(width: SsrSpace.xs),
                  Text(label,
                      style:
                          const TextStyle(color: labelColor)),
                ],
              ),
            const SizedBox(height: SsrSpace.xs),
            ...children,
          ],
        ),
      ),
    );
  }
}
