import 'package:flutter_test/flutter_test.dart';
import 'package:ssr_space/services/month_compare.dart';

void main() {
  test('urut |delta|, persen benar, kategori baru null', () {
    final cmp = compareMonths(
      {'Makan': 500000, 'Jajan': 100000, 'Baru': 50000},
      {'Makan': 300000, 'Jajan': 300000, 'Hilang': 200000},
    );
    expect(cmp.length, 4);
    expect(cmp[0].category, 'Makan');
    expect(cmp[0].delta, 200000);
    expect(cmp[0].pct!, closeTo(66.67, 0.01));
    expect(cmp[1].category, 'Jajan');
    expect(cmp[1].pct!, closeTo(-66.67, 0.01));
    final baru = cmp.firstWhere((e) => e.category == 'Baru');
    expect(baru.pct, null);
    expect(baru.delta, 50000);
  });

  test('kosong = kosong', () {
    expect(compareMonths({}, {}), isEmpty);
  });
}
