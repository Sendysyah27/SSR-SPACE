import 'package:flutter/material.dart';
import 'tokens.dart';

/// Glassmorphism primitives (Batch 1 — Design System 2.61.0+164).
/// Kartu kaca: gradient statis + border putih + shadow halus.
/// Batch 7 (2.61.0+170): BackdropFilter blur DIHAPUS demi performa
/// (blur real-time mahal di GPU); efek kaca disimulasikan gradient.
/// Selalu pakai di atas background gelap agar efek kaca terlihat.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(GlassSpace.md),
    this.margin,
    this.borderRadius = GlassRadius.lg,
    this.blur = 18,
    this.opacity = 0.10,
    this.borderOpacity = 0.08,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final double blur;
  final double opacity;
  final double borderOpacity;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(borderRadius);
    // Batch 7 (2.61.0+170): tanpa BackdropFilter — gradient statis
    // meniru kaca buram tanpa cost GPU. Param `blur` dipertahankan
    // demi kompatibilitas API tapi diabaikan.
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: radius,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: opacity + 0.06),
            Colors.white.withValues(alpha: opacity + 0.01),
            Colors.white.withValues(alpha: opacity - 0.03),
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: borderOpacity + 0.04),
          width: 1,
        ),
        boxShadow: GlassElevation.card,
      ),
      child: child,
    );
    if (margin != null) {
      return Padding(
        padding: margin!,
        child: _tapWrap(card),
      );
    }
    return _tapWrap(card);
  }

  Widget _tapWrap(Widget c) {
    if (onTap == null) return c;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(borderRadius),
        onTap: onTap,
        child: c,
      ),
    );
  }
}

/// Panel kaca besar — untuk hero / dashboard atas.
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(GlassSpace.lg),
    this.borderRadius = GlassRadius.xl,
    this.blur = 24,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final double blur;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: padding,
      borderRadius: borderRadius,
      blur: blur,
      opacity: 0.14,
      borderOpacity: 0.12,
      child: child,
    );
  }
}

/// Chip kaca kecil — untuk label / status mengambang.
class GlassChip extends StatelessWidget {
  const GlassChip({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(
      horizontal: GlassSpace.sm,
      vertical: GlassSpace.xs,
    ),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: padding,
      borderRadius: GlassRadius.full,
      blur: 12,
      opacity: 0.12,
      child: child,
    );
  }
}

/// Dekorasi gaya-kaca untuk Sliver. Selaras visual dengan GlassCard
/// (semua kaca kini memakai gradient statis tanpa BackdropFilter).
BoxDecoration glassSliverDecoration({double borderRadius = GlassRadius.lg}) {
  return BoxDecoration(
    borderRadius: BorderRadius.circular(borderRadius),
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Colors.white.withValues(alpha: 0.14),
        Colors.white.withValues(alpha: 0.08),
      ],
    ),
    border: Border.all(
      color: Colors.white.withValues(alpha: 0.08),
      width: 1,
    ),
    boxShadow: GlassElevation.card,
  );
}
