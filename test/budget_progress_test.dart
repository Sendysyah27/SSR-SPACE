import 'package:flutter_test/flutter_test.dart';
import 'package:ssr_space/core/saas/budget_service.dart';

void main() {
  test('budget progress caps at 1', () {
    expect(budgetProgress(50, 100), 0.5);
    expect(budgetProgress(150, 100), 1);
    expect(budgetProgress(0, 0), 0);
  });

  test('current month format', () {
    expect(RegExp(r'^\d{4}-\d{2}$').hasMatch(currentMonth()), true);
  });
}
