import 'package:flutter/material.dart';
import 'package:ssr_space/theme/app_theme.dart';
import 'package:ssr_space/utils/datetime.dart';
import 'package:ssr_space/utils/strings.dart';

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
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                color: SsrColors.noirInk,
              ),
            ),
          ),
          Text(
            sub,
            style: theme.textTheme.bodySmall?.copyWith(
              color: SsrColors.noirSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
