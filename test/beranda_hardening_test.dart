import 'package:flutter_test/flutter_test.dart';
import 'package:ssr_space/models/transaction.dart';
import 'package:ssr_space/services/budget_pace.dart';
import 'package:ssr_space/services/calm_streak.dart';
import 'package:ssr_space/services/currency.dart';
import 'package:ssr_space/services/game_level.dart';
import 'package:ssr_space/services/goal_forecast.dart';
import 'package:ssr_space/services/health_score.dart';
import 'package:ssr_space/services/savings_goal.dart';
import 'package:ssr_space/services/tx_day_group.dart';
import 'package:ssr_space/services/weekly_insight.dart';

/// Hardening Beranda vs data real aneh (temuan FC skeleton→mati):
/// null, string, NaN, Infinity, negatif, kosong. Tak ada yang boleh throw.
void main() {
  group('fromMap toleran', () {
    Map<String, dynamic> row(dynamic amount) => {
          'id': 'x',
          'org_id': 'o',
          'type': 'out',
          'amount': amount,
        };

    test('amount null → 0', () {
      expect(SaasTransaction.fromMap(row(null)).amount, 0);
    });
    test('amount string angka → parse', () {
      expect(SaasTransaction.fromMap(row('15000')).amount, 15000);
    });
    test('amount string rusak → 0', () {
      expect(SaasTransaction.fromMap(row('rusak')).amount, 0);
    });
    test('amount NaN/Infinity → 0', () {
      expect(SaasTransaction.fromMap(row(double.nan)).amount, 0);
      expect(
        SaasTransaction.fromMap(row(double.infinity)).amount,
        0,
      );
    });
    test('id/org null → string kosong', () {
      final t = SaasTransaction.fromMap({'id': null, 'org_id': null});
      expect(t.id, '');
      expect(t.orgId, '');
      expect(t.amount, 0);
    });
  });

  group('health tak pernah throw', () {
    test('budget NaN → 0..100', () {
      final s = budgetScore([
        const HealthBudget(limit: 100, spent: double.nan),
      ]);
      expect(s >= 0 && s <= 100, true);
    });
    test('saving/trend NaN → 0..100', () {
      expect(savingScore(savingOut: double.nan, totalIn: 1000), isA<int>());
      expect(trendScore(curOut: double.nan, prevOut: 500), isA<int>());
      expect(trendScore(curOut: 500, prevOut: double.nan), isA<int>());
    });
    test('computeHealth semua NaN → total 0..100', () {
      final h = computeHealth(
        totalIn: double.nan,
        budgets: const [],
        savingOut: double.nan,
        curOut: double.nan,
        prevOut: double.nan,
        streakDays: -5,
      );
      expect(h.total >= 0 && h.total <= 100, true);
    });
  });

  group('pace/goal/level toleran', () {
    test('budgetPace NaN → safe', () {
      final p = budgetPace(
        spent: double.nan,
        limit: double.nan,
        today: DateTime(2026, 10, 9),
      );
      expect(p.state, PaceState.safe);
    });
    test('emergencyFund NaN → null', () {
      expect(
        emergencyFund(monthlyExpense: double.nan, saved: 1000),
        isNull,
      );
    });
    test('calcXp negatif → >= 0', () {
      expect(
        calcXp(txCount: -3, streakDays: -1, challengesDone: -2, goalsReached: -1),
        greaterThanOrEqualTo(0),
      );
    });
    test('goal linkCategory non-String tak throw', () {
      final g = SavingsGoal.tryParse({
        'id': 'g1',
        'name': 'Darurat',
        'target': 1000000,
        'linkCategory': 5,
      });
      expect(g, isNotNull);
    });
  });

  group('grup/hari/minggu kosong-aneh', () {
    test('groupDayBuckets tanggal null → no-date', () {
      final t = SaasTransaction(
        id: 'a',
        orgId: 'o',
        type: 'out',
        amount: 1000,
      );
      final b = groupDayBuckets([t]);
      expect(b.length, 1);
      expect(b.first.key, 'no-date');
    });
    test('groupDayBuckets kosong → kosong', () {
      expect(groupDayBuckets([]), isEmpty);
    });
    test('dailyStreak kosong → 0', () {
      final s = dailyStreak([], DateTime(2026, 10, 9));
      expect(s.days, 0);
    });
    test('calmWeeks kosong → 8 false', () {
      expect(calmWeeks([], DateTime(2026, 10, 9)), List.filled(8, false));
    });
    test('weeklyInsight kosong → null', () {
      expect(
        buildWeeklyInsight(txs: [], now: DateTime(2026, 10, 9)),
        isNull,
      );
    });
  });

  group('currency tak pernah throw', () {
    test('format NaN/Infinity → string', () {
      expect(CurrencyService.format(double.nan), isA<String>());
      expect(CurrencyService.format(double.infinity), isA<String>());
    });
    test('convert/toIdr NaN → 0', () {
      expect(CurrencyService.convert(double.nan), 0);
      expect(CurrencyService.toIdr(double.nan), 0);
    });
  });
}
