import 'package:flutter/material.dart';
import 'package:ssr_space/theme/glass.dart';
import 'package:ssr_space/theme/tokens.dart';
import 'package:ssr_space/utils/datetime.dart';
import 'package:ssr_space/utils/strings.dart';

/// Premium day-group header: glass pill with date + count badge.
class DayHeader extends StatelessWidget {
  final String dateKey;
  final int count;
  const DayHeader({super.key, required this.dateKey, required this.count});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = dateKey == 'no-date' ? tr('day_no_date') : dayLabel(dateKey);
    final sub = tr('day_count').replaceFirst('{n}', '$count');
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          GlassSpace.xs, GlassSpace.md, GlassSpace.xs, GlassSpace.sm),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
          ),
          GlassChip(
            child: Text(
              sub,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
