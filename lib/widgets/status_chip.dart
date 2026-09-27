import 'package:flutter/material.dart';
import 'package:ssr_space/theme/app_icons.dart';
import 'package:ssr_space/theme/app_theme.dart';

enum StatusTone { neutral, accent, danger, ink }

class StatusChip extends StatelessWidget {
  final String label;
  final StatusTone tone;
  final IconData? icon;

  const StatusChip({
    super.key,
    required this.label,
    this.tone = StatusTone.neutral,
    this.icon,
  });

  Color get _bg {
    switch (tone) {
      case StatusTone.accent:
        return SsrColors.mint.withValues(alpha: 0.14);
      case StatusTone.danger:
        return SsrColors.rose.withValues(alpha: 0.14);
      case StatusTone.ink:
        return SsrColors.noirInk;
      case StatusTone.neutral:
        return SsrColors.noirRaised;
    }
  }

  Color get _fg {
    switch (tone) {
      case StatusTone.accent:
        return SsrColors.mint;
      case StatusTone.danger:
        return SsrColors.rose;
      case StatusTone.ink:
        return SsrColors.noirBg;
      case StatusTone.neutral:
        return SsrColors.noirSecondary;
    }
  }

  Color get _border {
    switch (tone) {
      case StatusTone.accent:
        return SsrColors.mint.withValues(alpha: 0.45);
      case StatusTone.danger:
        return SsrColors.rose.withValues(alpha: 0.45);
      case StatusTone.ink:
        return SsrColors.noirInk;
      case StatusTone.neutral:
        return SsrColors.noirLine;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(SsrRadius.chip),
        border: Border.all(color: _border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            DuoIcon(icon!, size: 12, color: _fg),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: _fg,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}
