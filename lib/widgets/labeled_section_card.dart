import 'package:flutter/material.dart';
import 'package:ssr_space/theme/app_theme.dart';
import 'package:ssr_space/widgets/section_card.dart';

/// SectionCard dengan label kecil (bodySmall) + jarak xs di atas isi.
/// Dipakai di layar Lainnya (5 kartu) dan Dompet (kartu total aset) —
/// gaya label persis sama di semua pemakai (bodySmall), jadi aman digabung.
class LabeledSectionCard extends StatelessWidget {
  final String label;
  final List<Widget> children;
  final EdgeInsetsGeometry margin;

  const LabeledSectionCard({
    super.key,
    required this.label,
    required this.children,
    this.margin = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      margin: margin,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: SsrSpace.xs),
          ...children,
        ],
      ),
    );
  }
}
