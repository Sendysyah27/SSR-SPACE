import 'package:flutter/material.dart';
import 'package:ssr_space/core/theme/app_theme.dart';

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
        return SsrColors.accentSoft;
      case StatusTone.danger:
        return SsrColors.dangerSoft;
      case StatusTone.ink:
        return SsrColors.ink;
      case StatusTone.neutral:
        return SsrColors.surfaceMuted;
    }
  }

  Color get _fg {
    switch (tone) {
      case StatusTone.accent:
        return SsrColors.accent;
      case StatusTone.danger:
        return SsrColors.danger;
      case StatusTone.ink:
        return Colors.white;
      case StatusTone.neutral:
        return SsrColors.secondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(SsrRadius.chip),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: _fg),
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
