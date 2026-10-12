import 'package:flutter/material.dart';
import 'package:ssr_space/theme/app_icons.dart';
import 'package:ssr_space/theme/app_theme.dart';
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
