import 'package:flutter_test/flutter_test.dart';
import 'package:ssr_space/services/goal_forecast.dart';

void main() {
  test('proyeksi tanpa deadline', () {
    final f = forecastGoal(
      saved: 1000000,
      target: 3000000,
      savePerMonth: [500000, 500000, 500000],
      today: DateTime(2026, 10, 9),
    )!;
    expect(f.avgPerMonth, 500000);
    expect(f.projectedMonth, DateTime(2027, 1, 1));
    expect(f.onTrack, true);
  });

  test('meleset deadline: butuh + saran', () {
    final f = forecastGoal(
      saved: 1000000,
      target: 3000000,
      savePerMonth: [500000, 500000, 500000],
      today: DateTime(2026, 10, 9),
      deadline: DateTime(2026, 12, 31),
    )!;
    expect(f.needPerMonth!, closeTo(2000000 / 3, 1));
    expect(f.extraPerMonth!, closeTo(2000000 / 3 - 500000, 1));
    expect(f.onTrack, false);
  });

  test('rata-rata nol: tanpa proyeksi, tetap ada kebutuhan', () {
    final f = forecastGoal(
      saved: 0,
      target: 1000000,
      savePerMonth: [],
      today: DateTime(2026, 10, 9),
      deadline: DateTime(2026, 12, 31),
    )!;
    expect(f.projectedMonth, null);
    expect(f.onTrack, false);
    expect(f.needPerMonth, 1000000 / 3);
  });

  test('tercapai + deadline lewat', () {
    final done = forecastGoal(
      saved: 3000000,
      target: 3000000,
      savePerMonth: [],
      today: DateTime(2026, 10, 9),
    )!;
    expect(done.onTrack, true);
    final late = forecastGoal(
      saved: 100,
      target: 1000,
      savePerMonth: [100],
      today: DateTime(2026, 10, 9),
      deadline: DateTime(2026, 8, 31),
    )!;
    expect(late.overdue, true);
    expect(late.onTrack, false);
  });

  test('dana darurat 3 level + null', () {
    expect(
      emergencyFund(monthlyExpense: 2000000, saved: 1000000)!.level,
      0,
    );
    final mid =
        emergencyFund(monthlyExpense: 2000000, saved: 7000000)!;
    expect(mid.level, 1);
    expect(mid.target3, 6000000);
    expect(mid.target6, 12000000);
    expect(
      emergencyFund(monthlyExpense: 2000000, saved: 13000000)!.level,
      2,
    );
    expect(emergencyFund(monthlyExpense: 0, saved: 99), null);
  });
}
