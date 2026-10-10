import 'package:flutter_test/flutter_test.dart';
import 'package:ssr_space/services/month_figures.dart';

List<MonthMixRow> rows() => const [
      MonthMixRow(type: 'in', category: 'Gaji', sum: 5000),
      MonthMixRow(type: 'out', category: 'Makan', sum: 1200),
      MonthMixRow(type: 'out', category: 'Makan > Kopi', sum: 300),
      MonthMixRow(type: 'out', category: 'Tabungan', sum: 1000),
      MonthMixRow(type: 'out', category: '', sum: 100),
      MonthMixRow(type: 'transfer', category: 'X', sum: 700),
    ];

void main() {
  test('total + iris tabungan + net (transfer diabaikan)', () {
    final f = foldMonthMix(rows(), otherLabel: 'Lainnya', totalN: 6);
    expect(f.totalIn, 5000);
    expect(f.totalOut, 2600);
    expect(f.savingOut, 1000);
    expect(f.spendOut, 1600);
    expect(f.net, 2400);
    expect(f.totalN, 6);
  });

  test('peta kategori: sub terlipat, kosong jadi Lainnya', () {
    final f = foldMonthMix(rows(), otherLabel: 'Lainnya');
    expect(f.catTotals['Makan'], 1500);
    expect(f.catTotals['Tabungan'], 1000);
    expect(f.catTotals['Lainnya'], 100);
    expect(f.catTotals.containsKey('X'), isFalse);
  });

  test('peta tanpa-tabungan untuk banding/health', () {
    final f = foldMonthMix(rows(), otherLabel: 'Lainnya');
    expect(f.catTotalsNoSaving['Makan'], 1500);
    expect(f.catTotalsNoSaving.containsKey('Tabungan'), isFalse);
  });

  test('kosong = nol semua (aman dibagi)', () {
    const f = MonthFigures.empty;
    expect(f.net, 0);
    expect(f.catTotals, isEmpty);
    final g = foldMonthMix(const [], otherLabel: 'Lainnya');
    expect(g.totalIn, 0);
    expect(g.spendOut, 0);
  });

  test('konverter fallback dari map transaksi', () {
    final m = mixRowsFromTx([
      {'type': 'in', 'category': 'Gaji', 'amount': 2000},
      {'type': 'out', 'category': null, 'amount': 500},
    ]);
    expect(m.length, 2);
    final f = foldMonthMix(m, otherLabel: 'Lainnya');
    expect(f.totalIn, 2000);
    expect(f.catTotals['Lainnya'], 500);
  });
}
