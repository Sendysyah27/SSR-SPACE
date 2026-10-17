import 'package:flutter_test/flutter_test.dart';
import 'package:ssr_space/services/calm_streak.dart';

DateTime d(int y, int m, int day) => DateTime(y, m, day);

void main() {
  test('3 hari beruntun sampai hari ini', () {
    final s = dailyStreak(
      [d(2026, 10, 7), d(2026, 10, 8), d(2026, 10, 9)],
      d(2026, 10, 9),
    );
    expect(s.days, 3);
    expect(s.todayDone, true);
    expect(s.graceUsed, false);
  });

  test('grace: hari ini kosong tapi kemarin ada', () {
    final s = dailyStreak([d(2026, 10, 8)], d(2026, 10, 9));
    expect(s.days, 1);
    expect(s.todayDone, false);
    expect(s.graceUsed, true);
  });

  test('putus: dua hari kosong', () {
    final s = dailyStreak([d(2026, 10, 7)], d(2026, 10, 9));
    expect(s.days, 0);
    expect(s.graceUsed, false);
  });

  test('bolong di tengah memutus', () {
    final s = dailyStreak(
      [d(2026, 10, 9), d(2026, 10, 7)],
      d(2026, 10, 9),
    );
    expect(s.days, 1);
  });

  test('duplikat sehari sekali, masa depan diabaikan', () {
    final s = dailyStreak(
      [d(2026, 10, 9), d(2026, 10, 9), d(2026, 10, 10)],
      d(2026, 10, 9),
    );
    expect(s.days, 1);
  });

  test('kosong = nol', () {
    final s = dailyStreak([], d(2026, 10, 9));
    expect(s.days, 0);
  });

  test('milestone 3/7/14/30/100', () {
    expect(nextMilestone(3), 7);
    expect(nextMilestone(7), 14);
    expect(nextMilestone(30), 100);
    expect(nextMilestone(100), null);
    expect(isMilestone(7), true);
    expect(isMilestone(14), true);
    expect(isMilestone(30), true);
    expect(isMilestone(100), true);
    expect(isMilestone(29), false);
  });
}
