import 'package:flutter_test/flutter_test.dart';
import 'package:ssr_space/services/weekly_insight.dart';

DateTime d(int y, int m, int day) => DateTime(y, m, day);

void main() {
  test('senin awal minggu + kunci ISO', () {
    expect(weekMonday(d(2026, 10, 9)), d(2026, 10, 5));
    expect(weekKey(d(2026, 10, 9)), '2026-W41');
    expect(weekKey(d(2026, 1, 1)), '2026-W01');
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
}
