import 'package:flutter_test/flutter_test.dart';
import 'package:ssr_space/services/weekly_insight.dart';

DateTime d(int y, int m, int day) => DateTime(y, m, day);

void main() {
  test('senin awal minggu + kunci ISO', () {
    expect(weekMonday(d(2026, 10, 9)), d(2026, 10, 5));
    expect(weekKey(d(2026, 10, 9)), '2026-W41');
    expect(weekKey(d(2026, 1, 1)), '2026-W01');
  });

  test('awal minggu bisa minggu', () {
    expect(weekMonday(d(2026, 10, 9), 7), d(2026, 10, 4));
    expect(weekMonday(d(2026, 10, 4), 7), d(2026, 10, 4));
    expect(weekMonday(d(2026, 10, 9), 9), d(2026, 10, 5));
  });

  test('insight penuh: total, rata-rata, top naik, saran', () {
    final now = d(2026, 10, 9);
    final txs = [
      WeeklyTx(date: d(2026, 9, 29), amount: 200000, category: 'Makan'),
      WeeklyTx(date: d(2026, 10, 2), amount: 100000, category: 'Makan'),
      WeeklyTx(date: d(2026, 10, 3), amount: 100000, category: 'Jajan'),
      for (var w = 0; w < 4; w++)
        WeeklyTx(date: d(2026, 9, 21 - w * 7), amount: 100000, category: 'Makan'),
      for (var w = 0; w < 4; w++)
        WeeklyTx(date: d(2026, 9, 22 - w * 7), amount: 100000, category: 'Jajan'),
      WeeklyTx(date: d(2026, 10, 6), amount: 999000, category: 'Makan'),
    ];
    final ins = buildWeeklyInsight(txs: txs, now: now)!;
    expect(ins.lastTotal, 400000);
    expect(ins.avgWeekly, 200000);
    expect(ins.hasAvg, true);
    expect(ins.totalPct, 100);
    expect(ins.topCategory, 'Makan');
    expect(ins.topPct, 200);
    expect(ins.saveWeekly, 60000);
    expect(ins.saveMonthly, 240000);
  });

  test('null bila minggu lalu kosong', () {
    final ins = buildWeeklyInsight(
      txs: [WeeklyTx(date: d(2026, 9, 20), amount: 50000, category: 'Makan')],
      now: d(2026, 10, 9),
    );
    expect(ins, null);
  });

  test('tanpa riwayat: top nominal terbesar, saran tetap ada', () {
    final ins = buildWeeklyInsight(
      txs: [WeeklyTx(date: d(2026, 9, 30), amount: 50000, category: 'Jajan')],
      now: d(2026, 10, 9),
    )!;
    expect(ins.hasAvg, false);
    expect(ins.topPct, null);
    expect(ins.topCategory, 'Jajan');
    expect(ins.saveWeekly, 10000);
  });

  test('hari paling boros minggu lalu', () {
    final ins = buildWeeklyInsight(
      txs: [
        WeeklyTx(date: d(2026, 9, 29), amount: 100000, category: 'Makan'),
        WeeklyTx(date: d(2026, 10, 1), amount: 200000, category: 'Makan'),
        WeeklyTx(date: d(2026, 10, 3), amount: 50000, category: 'Jajan'),
      ],
      now: d(2026, 10, 9),
    )!;
    expect(ins.topWeekday, 4);
    expect(ins.topDayTotal, 200000);
  });

  test('anomali: 1 transaksi >= 3x rata-rata kategori', () {
    final txs = [
      for (var w = 0; w < 4; w++)
        WeeklyTx(date: d(2026, 9, 21 - w * 7), amount: 20000, category: 'Makan'),
      WeeklyTx(date: d(2026, 9, 30), amount: 100000, category: 'Makan'),
      WeeklyTx(date: d(2026, 10, 1), amount: 50000, category: 'Jajan'),
    ];
    final ins = buildWeeklyInsight(txs: txs, now: d(2026, 10, 9))!;
    expect(ins.anomalies.length, 1);
    expect(ins.anomalies.first.category, 'Makan');
    expect(ins.anomalies.first.amount, 100000);
    expect(ins.anomalies.first.avg, 20000);
  });

  test('anomali: di bawah lantai 50rb bukan anomali', () {
    final txs = [
      for (var w = 0; w < 4; w++)
        WeeklyTx(date: d(2026, 9, 21 - w * 7), amount: 10000, category: 'Makan'),
      WeeklyTx(date: d(2026, 9, 30), amount: 40000, category: 'Makan'),
    ];
    final ins = buildWeeklyInsight(txs: txs, now: d(2026, 10, 9))!;
    expect(ins.anomalies, isEmpty);
  });

  test('anomali: maks 3 urut nominal desc', () {
    final txs = [
      for (var w = 0; w < 4; w++)
        WeeklyTx(date: d(2026, 9, 21 - w * 7), amount: 10000, category: 'Makan'),
      for (var i = 0; i < 5; i++)
        WeeklyTx(
          date: d(2026, 9, 28 + i),
          amount: 100000.0 + i * 10000,
          category: 'Makan',
        ),
    ];
    final ins = buildWeeklyInsight(txs: txs, now: d(2026, 10, 9))!;
    expect(ins.anomalies.length, 3);
    expect(ins.anomalies.first.amount, 140000);
  });

  test('tanpa riwayat kategori: bukan anomali', () {
    final ins = buildWeeklyInsight(
      txs: [WeeklyTx(date: d(2026, 9, 30), amount: 500000, category: 'Jajan')],
      now: d(2026, 10, 9),
    )!;
    expect(ins.anomalies, isEmpty);
  });
}
