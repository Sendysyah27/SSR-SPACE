import 'package:flutter_test/flutter_test.dart';
import 'package:ssr_space/services/cashflow_forecast.dart';

TxFlow _f(String date, String type, double amount) =>
    TxFlow(date: date, type: type, amount: amount);

void main() {
  test('datar tanpa tagihan', () {
    final fc = projectForecast(
      start: 100000,
      inPerDay: 10000,
      outPerDay: 5000,
      dues: const [],
      fromDate: '2026-10-11',
      days: 3,
    );
    expect(fc.points, [100000, 105000, 110000, 115000]);
    expect(fc.end, 115000);
    expect(fc.min, 100000);
    expect(fc.minDay, 0);
  });

  test('tagihan menggerus di tanggalnya', () {
    final fc = projectForecast(
      start: 100000,
      inPerDay: 0,
      outPerDay: 0,
      dues: const [DueBill(date: '2026-10-13', amount: 50000)],
      fromDate: '2026-10-11',
      days: 3,
    );
    expect(fc.points, [100000, 100000, 50000, 50000]);
    expect(fc.min, 50000);
    expect(fc.minDay, 2);
  });

  test('akhir minus terdeteksi', () {
    final fc = projectForecast(
      start: 10000,
      inPerDay: 0,
      outPerDay: 5000,
      dues: const [],
      fromDate: '2026-10-11',
      days: 3,
    );
    expect(fc.end, -5000);
    expect(fc.minDay, 3);
  });

  test('rate abaikan transfer + tanggal rusak', () {
    final r = dailyRate([
      _f('2026-10-10', 'in', 100000),
      _f('2026-10-10', 'out', 40000),
      _f('2026-10-09', 'transfer', 999999),
      _f('rusak', 'out', 999999),
    ], 10);
    expect(r.inPerDay, 10000);
    expect(r.outPerDay, 4000);
  });

  test('rate kosong = nol', () {
    final r = dailyRate([], 30);
    expect(r.inPerDay, 0);
    expect(r.outPerDay, 0);
  });

  test('tagihan: batas window + nonaktif', () {
    final dues = upcomingBills(
      [
        const BillDue(nextDue: '2026-10-11', amount: 1, active: true),
        const BillDue(nextDue: '2026-10-12', amount: 20000, active: true),
        const BillDue(nextDue: '2026-11-10', amount: 30000, active: true),
        const BillDue(nextDue: '2026-11-11', amount: 99999, active: true),
        const BillDue(nextDue: '2026-10-15', amount: 99999, active: false),
        const BillDue(nextDue: 'rusak', amount: 99999, active: true),
      ],
      '2026-10-11',
      30,
    );
    expect(dues.length, 2);
    expect(dues.map((d) => d.amount), containsAll([20000, 30000]));
  });
}
