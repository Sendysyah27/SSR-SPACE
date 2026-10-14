import 'package:flutter/material.dart';
import 'package:ssr_space/theme/app_icons.dart';
import 'package:ssr_space/theme/app_theme.dart';

enum StatusTone { neutral, accent, danger, ink }

class StatusChip extends StatelessWidget {
  final String label;
  final StatusTone tone;
  final IconData? icon;
  final bool isSmall;

  const StatusChip({
    super.key,
    required this.label,
    this.tone = StatusTone.neutral,
    this.icon,
    this.isSmall = false,
  });

  Color _bgOf(bool dark, ColorScheme scheme) {
    switch (tone) {
      case StatusTone.accent:
        return AppColors.chipAutoBg;
      case StatusTone.danger:
        return AppColors.chipWarnBg;
      case StatusTone.ink:
        return AppColors.goldSoft;
      case StatusTone.neutral:
        return scheme.outline;
    }
  }

  Color _fgOf(bool dark, ColorScheme scheme) {
    switch (tone) {
      case StatusTone.accent:
        return scheme.primary;
      case StatusTone.danger:
        return scheme.error;
      case StatusTone.ink:
        return AppColors.chipSurplusText;
      case StatusTone.neutral:
        return scheme.onSurfaceVariant;
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;
    final bg = _bgOf(dark, scheme);
    final fg = _fgOf(dark, scheme);
    final text = tone == StatusTone.ink ? label.toUpperCase() : label;
    final padding = isSmall ? EdgeInsets.symmetric(horizontal: 8, vertical: 3) : EdgeInsets.symmetric(horizontal: 12, vertical: 5);
    final fontSize = isSmall ? 11.0 : 12.5;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            DuoIcon(icon!, size: isSmall ? 10 : 12, color: fg),
            const SizedBox(width: isSmall ? 3 : 4),
          ],
          Text(
            text,
            style: TextStyle(
              fontFamily: SsrFonts.body,
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
              color: fg,
              height: isSmall ? 1.0 : 1.2,
            ),
          ),
        ],
      ),
    );
  }
}
