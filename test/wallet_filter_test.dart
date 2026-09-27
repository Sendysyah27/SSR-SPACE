import 'package:flutter_test/flutter_test.dart';
import 'package:ssr_space/models/transaction.dart';
import 'package:ssr_space/services/wallet_filter.dart';

SaasTransaction tx(String id, String type, {String? w, String? to}) {
  return SaasTransaction(
    id: id, orgId: 'o', type: type, amount: 10000,
    walletId: w, toWalletId: to,
  );
}

void main() {
  test('null berarti semua dan salinan baru', () {
    final src = [tx('a', 'out', w: 'w1')];
    final out = filterByWallet(src, null);
    expect(out.length, 1);
    expect(identical(out, src), isFalse);
  });

  test('filter sisi asal dan sisi tujuan transfer', () {
    final items = [
      tx('a', 'out', w: 'w1'),
      tx('b', 'in', w: 'w2'),
      tx('c', 'transfer', w: 'w1', to: 'w2'),
      tx('d', 'transfer', w: 'w2', to: 'w1'),
    ];
    expect(filterByWallet(items, 'w1').map((t) => t.id), ['a', 'c', 'd']);
  });

  test('id asing menghasilkan kosong', () {
    final items = [tx('a', 'out', w: 'w1')];
    expect(filterByWallet(items, 'wx'), isEmpty);
  });

  test('string kosong sama dengan semua', () {
    final items = [tx('a', 'out', w: 'w1')];
    expect(filterByWallet(items, '').length, 1);
  });
}
