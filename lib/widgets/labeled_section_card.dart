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

/// Varian kartu dari [LabeledSectionCard] (Batch 5 — Pengaturan).
/// API sama persis (label/icon/children/margin) agar pemakaian bisa
/// diganti 1:1; body dirender di atas kartu putih flat gaya frame
/// mockup (batch 287 tahap 5b; dulu navy TAHAP 10).
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
    const labelColor = DribTokens.textSecondary;
    // Batch 287 tahap 5b: kartu putih flat plek frame; teks default navy.
    // Kontrol dengan warna eksplisit (error, emas, dsb.) tak ikut berubah.
    return Container(
      margin: m == EdgeInsets.zero ? null : m,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: DribTokens.cardOf(context),
        borderRadius:
            BorderRadius.circular(DribTokens.cardRadius),
        boxShadow: DribTokens.cardShadow,
      ),
      child: Theme(
        data: base.copyWith(
          textTheme: base.textTheme.apply(
            bodyColor: DribTokens.navy,
            displayColor: DribTokens.navy,
          ),
          iconTheme: base.iconTheme.copyWith(color: DribTokens.navy),
          dividerTheme:
              const DividerThemeData(color: DribTokens.border),
          inputDecorationTheme:
              base.inputDecorationTheme.copyWith(
            labelStyle:
                const TextStyle(color: labelColor, fontSize: 13),
            hintStyle:
                const TextStyle(color: labelColor, fontSize: 13),
            floatingLabelStyle:
                const TextStyle(color: labelColor, fontSize: 13),
            prefixIconColor: DribTokens.textSecondary,
            suffixIconColor: DribTokens.textSecondary,
          ),
        ),
        child: DefaultTextStyle(
          style: const TextStyle(color: DribTokens.navy),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (ic == null)
                Text(label,
                    style: const TextStyle(
                        color: DribTokens.navy,
                        fontSize: 13,
                        fontWeight: FontWeight.w800))
              else
                Row(
                  children: [
                    DuoIcon(
                      ic,
                      size: 14,
                      color: DribTokens.primaryStrong,
                    ),
                    const SizedBox(width: SsrSpace.xs),
                    Text(label,
                        style: const TextStyle(
                            color: DribTokens.navy,
                            fontSize: 13,
                            fontWeight: FontWeight.w800)),
                  ],
                ),
              const SizedBox(height: SsrSpace.xs),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}
