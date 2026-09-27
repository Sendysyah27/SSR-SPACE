import 'package:flutter_test/flutter_test.dart';
import 'package:ssr_space/services/wallet_usage.dart';

void main() {
  test('satu pakai menaikkan hitung satu', () {
    expect(recordUse({}, 'w1'), {'w1': 1});
    expect(recordUse({'w1': 1}, 'w1'), {'w1': 2});
  });

  test('id kosong diabaikan', () {
    expect(recordUse({}, ''), isEmpty);
  });

  test('cap membuang entri terkecil saat penuh', () {
    var m = <String, int>{};
    for (var i = 0; i < walletUsageCap; i++) {
      m = recordUse(m, 'w$i');
    }
    m = recordUse(m, 'baru');
    expect(m.length, walletUsageCap);
    expect(m.containsKey('baru'), isTrue);
  });

  test('sort hitung besar dulu seri ikut abjad', () {
    final counts = {'w2': 3, 'w1': 3, 'w3': 1};
    final names = {'w1': 'BCA', 'w2': 'DANA', 'w3': 'Kas'};
    expect(sortIdsByUse(counts, names), ['w1', 'w2', 'w3']);
  });

  test('decode korup kembali ke kosong dan encode roundtrip', () {
    expect(decodeUsage('bukan-json'), isEmpty);
    expect(decodeUsage(null), isEmpty);
    final m = {'w1': 2};
    expect(decodeUsage(encodeUsage(m)), m);
  });
}
