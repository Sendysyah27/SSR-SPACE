import 'package:flutter_test/flutter_test.dart';
import 'package:ssr_space/services/family_summary.dart';

MemberTx _t(String type, double amount, String? by, [String date = '2026-10-05']) =>
    MemberTx(type: type, amount: amount, createdBy: by, date: date);

void main() {
  test('agregasi per anggota + hitung', () {
    final m = memberMonthTotals([
      _t('out', 50000, 'u1'),
      _t('out', 30000, 'u1'),
      _t('in', 100000, 'u2'),
    ], '2026-10');
    expect(m['u1']!.outTotal, 80000);
    expect(m['u1']!.inTotal, 0);
    expect(m['u1']!.count, 2);
    expect(m['u2']!.inTotal, 100000);
    expect(m['u2']!.count, 1);
  });

  test('transfer diabaikan', () {
    final m = memberMonthTotals([_t('transfer', 99999, 'u1')], '2026-10');
    expect(m, isEmpty);
  });

  test('tanpa pencatat dilewati', () {
    final m = memberMonthTotals(
      [_t('out', 1000, null), _t('out', 2000, '')],
      '2026-10',
    );
    expect(m, isEmpty);
  });

  test('bulan lain dikecualikan', () {
    final m = memberMonthTotals([_t('out', 5000, 'u1', '2026-09-30')], '2026-10');
    expect(m, isEmpty);
  });

  test('kosong = kosong', () {
    expect(memberMonthTotals([], '2026-10'), isEmpty);
  });
}
