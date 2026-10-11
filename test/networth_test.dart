import 'package:flutter_test/flutter_test.dart';
import 'package:ssr_space/services/networth.dart';

void main() {
  test('aset = dompet + piutang, net = aset - utang', () {
    final w = netWorth(
      liquid: 1000000,
      savings: 500000,
      investments: 200000,
      receivable: 300000,
      debt: 400000,
    );
    expect(w.assets, 2000000);
    expect(w.debt, 400000);
    expect(w.net, 1600000);
  });

  test('kosong = nol semua', () {
    final w = netWorth(
      liquid: 0,
      savings: 0,
      investments: 0,
      receivable: 0,
      debt: 0,
    );
    expect(w.assets, 0);
    expect(w.net, 0);
    expect(w.hasData, isFalse);
  });

  test('ada utang saja tetap data', () {
    final w = netWorth(
      liquid: 0,
      savings: 0,
      investments: 0,
      receivable: 0,
      debt: 100000,
    );
    expect(w.hasData, isTrue);
    expect(w.net, -100000);
  });

  test('walk-back estimasi dari kini', () {
    // Kini 1000; bln lalu net -50; 2 bln lalu +100.
    final pts = walkBackEstimates(currentNet: 1000, pastMonthlyNets: [100, -50]);
    expect(pts, [950, 1050]);
  });

  test('walk-back kosong = tanpa titik', () {
    expect(walkBackEstimates(currentNet: 500, pastMonthlyNets: []), []);
  });
}
