import 'package:flutter_test/flutter_test.dart';
import 'package:ssr_space/services/health_score.dart';

void main() {
  test('sehat: budget aman, nabung 20%, belanja turun', () {
    final h = computeHealth(
      totalIn: 5000000,
      budgets: const [HealthBudget(limit: 2000000, spent: 1000000)],
      savingOut: 1000000,
      curOut: 1500000,
      prevOut: 2000000,
      streakDays: 10,
    );
    expect(h.budget, 100);
    expect(h.saving, 100);
    expect(h.trend, 100);
    expect(h.streak, 33);
    expect(h.total, (100 * 0.4 + 100 * 0.3 + 100 * 0.2 + 33 * 0.1).round());
  });

  test('jebol: over 50%, tak nabung, belanja naik 50%', () {
    final h = computeHealth(
      totalIn: 5000000,
      budgets: const [HealthBudget(limit: 1000000, spent: 1500000)],
      savingOut: 0,
      curOut: 3000000,
      prevOut: 2000000,
      streakDays: 0,
    );
    expect(h.budget, 50);
    expect(h.saving, 0);
    expect(h.trend, 50);
    expect(h.streak, 0);
  });

  test('netral tanpa budget dan tanpa data', () {
    final h = computeHealth(
      totalIn: 0,
      budgets: const [],
      savingOut: 0,
      curOut: 0,
      prevOut: 0,
      streakDays: 0,
    );
    expect(h.budget, 70);
    expect(h.saving, 50);
    expect(h.trend, 70);
  });

  test('streak 30 hari = 100, nabung tanpa pemasukan = 100', () {
    final h = computeHealth(
      totalIn: 0,
      budgets: const [],
      savingOut: 50000,
      curOut: 0,
      prevOut: 0,
      streakDays: 30,
    );
    expect(h.saving, 100);
    expect(h.streak, 100);
  });

  test('belanja tanpa pembanding bulan lalu = 50', () {
    final h = computeHealth(
      totalIn: 1000000,
      budgets: const [],
      savingOut: 0,
      curOut: 500000,
      prevOut: 0,
      streakDays: 0,
    );
    expect(h.trend, 50);
  });
}
