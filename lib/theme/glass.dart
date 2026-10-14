import 'dart:ui';
import 'package:flutter/material.dart';
import 'tokens.dart';

/// Glassmorphism primitives (Batch 1 — Design System 2.61.0+164).
/// Kartu kaca: gradient halus + border putih 8% + blur backdrop.
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
    final card = ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: radius,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: opacity + 0.04),
                Colors.white.withValues(alpha: opacity - 0.02),
              ],
            ),
            border: Border.all(
              color: Colors.white.withValues(alpha: borderOpacity),
              width: 1,
            ),
            boxShadow: GlassElevation.card,
          ),
          child: child,
        ),
      ),
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

/// Dekorasi gaya-kaca untuk Sliver (tanpa blur — DecoratedSliver
/// tak mendukung BackdropFilter). Selaras visual dengan GlassCard.
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
