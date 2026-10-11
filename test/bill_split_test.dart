import 'package:flutter_test/flutter_test.dart';
import 'package:ssr_space/services/bill_split.dart';

SplitBill _bill({
  List<SplitShare> shares = const [
    SplitShare(userId: 'u1', amount: 33334),
    SplitShare(userId: 'u2', amount: 33333),
    SplitShare(userId: 'u3', amount: 33333),
  ],
  Set<String> settled = const {},
}) => SplitBill(
  id: 'b1',
  title: 'Makan bareng',
  txId: 'tx1',
  total: 100000,
  payerId: 'u1',
  shares: shares,
  settled: settled,
);

void main() {
  test('rata 100rb/3: sisa ke pertama, jumlah pas', () {
    final m = equalShares(100000, ['u1', 'u2', 'u3']);
    expect(m['u1'], 33334);
    expect(m['u2'], 33333);
    expect(m['u3'], 33333);
    expect(m.values.fold(0.0, (a, b) => a + b), 100000);
  });

  test('rata 1 orang = penuh, kosong = {}', () {
    expect(equalShares(50000, ['u1']), {'u1': 50000});
    expect(equalShares(50000, []), isEmpty);
  });

  test('rata nominal kecil jumlah tetap pas', () {
    final m = equalShares(2, ['u1', 'u2', 'u3']);
    expect(m.values.fold(0.0, (a, b) => a + b), 2);
  });

  test('custom pas = null (ok)', () {
    expect(validateCustomShares(100000, {'u1': 60000, 'u2': 40000}), isNull);
  });

  test('custom kurang/lebih = mismatch', () {
    expect(
      validateCustomShares(100000, {'u1': 60000, 'u2': 30000}),
      'mismatch',
    );
    expect(
      validateCustomShares(100000, {'u1': 60000, 'u2': 50000}),
      'mismatch',
    );
  });

  test('custom kosong/nol/negatif ditolak', () {
    expect(validateCustomShares(100000, {}), 'empty');
    expect(validateCustomShares(100000, {'u1': 0}), 'nonPositive');
    expect(validateCustomShares(100000, {'u1': -5000}), 'nonPositive');
  });

  test('utang: pembayar dikecualikan', () {
    final d = debtsOf(_bill());
    expect(d.length, 2);
    expect(d.map((e) => e.from), containsAll(['u2', 'u3']));
    expect(d.every((e) => e.to == 'u1'), isTrue);
    expect(d.firstWhere((e) => e.from == 'u2').amount, 33333);
  });

  test('utang lewati yang sudah lunas', () {
    final d = debtsOf(_bill(settled: {'u2'}));
    expect(d.length, 1);
    expect(d.first.from, 'u3');
  });

  test('hitung progres lunas', () {
    expect(shareCount(_bill()), 3);
    expect(settledCount(_bill()), 0);
    expect(settledCount(_bill(settled: {'u2', 'u3'})), 2);
  });

  test('tryParse rusak = null, round-trip utuh', () {
    expect(SplitBill.tryParse(null), isNull);
    expect(SplitBill.tryParse({'id': 'x'}), isNull);
    expect(SplitBill.tryParse('rusak'), isNull);
    final b = _bill(settled: {'u2'});
    final back = SplitBill.tryParse(b.toJson())!;
    expect(back.id, 'b1');
    expect(back.total, 100000);
    expect(back.shares.length, 3);
    expect(back.settled, {'u2'});
  });

  test('label peserta: ID pendek + Saya', () {
    expect(shortMemberLabel('abcdef123456', true), 'abcdef12 · Saya');
    expect(shortMemberLabel('ab', false), 'ab');
  });
}
