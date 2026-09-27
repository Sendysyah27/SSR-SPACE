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
        return AppColors.chipAutoBg;
      case StatusTone.danger:
        return AppColors.chipWarnBg;
      case StatusTone.ink:
        return AppColors.goldSoft;
      case StatusTone.neutral:
        return AppColors.line;
    }
  }

  Color get _fg {
    switch (tone) {
      case StatusTone.accent:
        return AppColors.emerald;
      case StatusTone.danger:
        return AppColors.rust;
      case StatusTone.ink:
        return AppColors.chipSurplusText;
      case StatusTone.neutral:
        return AppColors.inkSoft;
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = tone == StatusTone.ink ? label.toUpperCase() : label;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            DuoIcon(icon!, size: 12, color: _fg),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: TextStyle(
              fontFamily: SsrFonts.body,
              fontSize: 12.5,
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
