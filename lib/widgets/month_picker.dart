import 'package:flutter/material.dart';
import 'package:ssr_space/services/month.dart';
import 'package:ssr_space/theme/app_icons.dart';

class MonthPicker extends StatelessWidget {
  final String month;
  final ValueChanged<String> onChanged;
  const MonthPicker({super.key, required this.month, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    final isCurrent = month == currentMonth();
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          tooltip: 'Bulan lalu',
          icon: const DuoIcon(AppIcons.monthPrev),
          onPressed: () => onChanged(prevMonth(month)),
        ),
        Text(monthLabel(month), style: Theme.of(context).textTheme.titleMedium),
        IconButton(
          tooltip: 'Bulan depan',
          icon: const DuoIcon(AppIcons.monthNext),
          onPressed: isCurrent ? null : () => onChanged(nextMonth(month)),
        ),
      ],
    );
  }
}
