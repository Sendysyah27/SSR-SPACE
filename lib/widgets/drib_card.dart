import 'package:flutter/material.dart';
import 'package:ssr_space/theme/dribbble_tokens.dart';

/// Kartu putih gaya baru TAHAP 2 restyle: radius 20, bayangan sangat
/// halus. Pengganti SectionCard/GlassCard KHUSUS layar yang sudah
/// direstyle (Beranda); layar lain tetap pakai widget lama.
class DribCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final VoidCallback? onTap;

  const DribCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
    this.margin = EdgeInsets.zero,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: DribTokens.card,
        borderRadius: BorderRadius.circular(DribTokens.cardRadius),
        boxShadow: DribTokens.cardShadow,
      ),
      child: child,
    );
    final tap = onTap;
    if (tap == null) return card;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(DribTokens.cardRadius),
        onTap: tap,
        child: card,
      ),
    );
  }
}
