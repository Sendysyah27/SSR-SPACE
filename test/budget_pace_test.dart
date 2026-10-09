import 'package:flutter_test/flutter_test.dart';
import 'package:ssr_space/services/budget_pace.dart';

DateTime d(int y, int m, int day) => DateTime(y, m, day);

void main() {
  test('aman: laju cukup sampai akhir bulan', () {
    final p = budgetPace(spent: 200000, limit: 1000000, today: d(2026, 10, 9));
    expect(p.state, PaceState.safe);
    expect(p.depletedDate, null);
  });

  test('bahaya: sudah jebol', () {
    final p = budgetPace(spent: 1200000, limit: 1000000, today: d(2026, 10, 9));
    expect(p.state, PaceState.danger);
  });

  test('bahaya: speeding, habis dalam 7 hari', () {
    final p = budgetPace(spent: 800000, limit: 1000000, today: d(2026, 10, 3));
    expect(p.state, PaceState.danger);
    expect(p.depletedDate, isNotNull);
  });

  test('waspada: habis sebelum akhir bulan tapi masih lama', () {
    final p = budgetPace(spent: 500000, limit: 1000000, today: d(2026, 10, 9));
    expect(p.state, PaceState.warn);
    expect(p.depletedDate, isNotNull);
  });

  test('aman: belum pakai sama sekali', () {
    final p = budgetPace(spent: 0, limit: 1000000, today: d(2026, 10, 9));
    expect(p.state, PaceState.safe);
  });

  test('aman: limit nol (tanpa batas)', () {
    final p = budgetPace(spent: 0, limit: 0, today: d(2026, 10, 9));
    expect(p.state, PaceState.safe);
  });
}
