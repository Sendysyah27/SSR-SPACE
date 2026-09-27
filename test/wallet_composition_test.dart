import 'package:flutter_test/flutter_test.dart';
import 'package:ssr_space/services/wallet_composition.dart';

void main() {
  test('pemetaan tipe ke bucket', () {
    expect(bucketOf('savings'), AssetBucket.savings);
    expect(bucketOf('Savings'), AssetBucket.savings);
    expect(bucketOf('investment'), AssetBucket.investments);
    expect(bucketOf('cash'), AssetBucket.liquid);
    expect(bucketOf('ewallet'), AssetBucket.liquid);
    expect(bucketOf('bank'), AssetBucket.liquid);
    expect(bucketOf('aneh'), AssetBucket.liquid);
    expect(bucketOf(null), AssetBucket.liquid);
  });

  test('penjumlahan dan persen benar', () {
    final c = composeComposition(
      {'a': 60000, 'b': 30000, 'c': 10000},
      {'a': 'cash', 'b': 'savings', 'c': 'investment'},
    );
    expect(c.liquid, 60000);
    expect(c.savings, 30000);
    expect(c.investments, 10000);
    expect(c.liquidPct, 0.6);
    expect(c.showStrip, isTrue);
  });

  test('satu bucket berisi berarti sembunyi', () {
    final c = composeComposition({'a': 50000}, {'a': 'cash'});
    expect(c.filledBuckets, 1);
    expect(c.showStrip, isFalse);
  });

  test('total nol persen nol tanpa crash', () {
    final c = composeComposition({'a': 0}, {'a': 'cash'});
    expect(c.liquidPct, 0);
    expect(c.showStrip, isFalse);
  });

  test('tipe hilang ikut liquid', () {
    final c = composeComposition({'a': 10000}, {});
    expect(c.liquid, 10000);
    expect(c.showStrip, isFalse);
  });
}
