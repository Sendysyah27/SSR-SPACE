import 'package:flutter/material.dart';
import 'package:ssr_space/theme/app_theme.dart';

class SectionCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final Color? color;
  final Color? borderColor;

  const SectionCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
    this.margin = EdgeInsets.zero,
    this.color,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: padding,
      decoration: sectionCardDecoration(context, color: color, borderColor: borderColor),
      child: child,
    );
  }
}

/// Dekorasi kartu yang SAMA persis dengan [SectionCard], untuk Sliver
/// yang tak bisa dibungkus Container (riwayat lazy di dompet/laporan).
/// Dipakai via DecoratedSliver(position background) + SliverPadding.
BoxDecoration sectionCardDecoration(
  BuildContext context, {
  Color? color,
  Color? borderColor,
}) {
  final scheme = Theme.of(context).colorScheme;
  final dark = Theme.of(context).brightness == Brightness.dark;
  return BoxDecoration(
    color: color ?? scheme.surface,
    borderRadius: BorderRadius.circular(SsrRadius.card),
    border: Border.all(color: borderColor ?? scheme.outline),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: dark ? 0.4 : 0.08),
        blurRadius: 30,
        offset: const Offset(0, 10),
      ),
    ],
  );
}
