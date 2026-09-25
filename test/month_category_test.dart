import 'package:flutter_test/flutter_test.dart';
import 'package:ssr_space/services/category_icons.dart';
import 'package:ssr_space/services/month.dart';
import 'package:ssr_space/theme/app_icons.dart';

void main() {
  test('month helpers move correctly', () {
    expect(prevMonth('2026-01'), '2025-12');
    expect(nextMonth('2026-12'), '2027-01');
    expect(monthLabel('2026-09'), 'September 2026');
    expect(monthStart('2026-09'), '2026-09-01');
    expect(monthEnd('2026-09'), '2026-10-01');
  });

  test('category icons fall back honestly', () {
    expect(iconForCategory('jajan makan'), AppIcons.food);
    expect(iconForCategory('bensin motor'), AppIcons.transport);
    expect(iconForCategory('zzz-tak dikenal'), AppIcons.categoryFallback);
    expect(iconForCategory(null), AppIcons.categoryFallback);
  });
}
