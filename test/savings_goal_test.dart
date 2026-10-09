import 'package:flutter_test/flutter_test.dart';
import 'package:ssr_space/services/savings_goal.dart';

void main() {
  test('progres auto + manual, sisa, cap', () {
    const g = SavingsGoal(
      id: 'a',
      name: 'Motor',
      target: 10000000,
      savedManual: 1000000,
      auto: true,
    );
    expect(g.progress(2000000), 0.3);
    expect(g.remaining(2000000), 7000000);
    const over = SavingsGoal(
      id: 'c',
      name: 'X',
      target: 100,
      auto: false,
      savedManual: 250,
    );
    expect(over.progress(0), 1);
    expect(over.remaining(0), -150);
  });

  test('mode manual abaikan porsi auto', () {
    const g = SavingsGoal(
      id: 'b',
      name: 'HP',
      target: 3000000,
      savedManual: 500000,
      auto: false,
    );
    expect(g.progress(999000000), 500000 / 3000000);
  });

  test('sisa hari deadline', () {
    const g = SavingsGoal(
      id: 'e',
      name: 'Y',
      target: 100,
      deadline: '2026-12-31',
    );
    expect(g.daysLeft(DateTime(2026, 10, 9)), 83);
    expect(g.daysLeft(DateTime(2027, 1, 2)), -2);
    const noDl = SavingsGoal(id: 'f', name: 'Z', target: 100);
    expect(noDl.daysLeft(DateTime(2026, 10, 9)), null);
  });

  test('parse toleran + default', () {
    expect(SavingsGoal.tryParse({'a': 1}), null);
    expect(
      SavingsGoal.tryParse(
        {'id': 'x', 'name': 'Ok', 'target': 5000, 'deadline': 'besok'},
      ),
      null,
    );
    // Tanggal kompak (8 char, tryParse lolos) ditolak sebelum substring.
    expect(
      SavingsGoal.tryParse(
        {'id': 'x', 'name': 'Ok', 'target': 5000, 'deadline': '20260928'},
      ),
      null,
    );
    final ok = SavingsGoal.tryParse({'id': 'x', 'name': 'Ok', 'target': 5000})!;
    expect(ok.auto, true);
    expect(ok.icon, 'Tabungan');
    expect(ok.savedManual, 0);
  });
}
