import 'package:flutter_test/flutter_test.dart';
import 'package:ssr_space/models/wallet.dart';
import 'package:ssr_space/services/wallet_service.dart';

Wallet _w(String id, String name) =>
    Wallet(id: id, orgId: 'o1', name: name, type: 'cash');

void main() {
  test('peek kosong sebelum store', () {
    WalletCache.invalidate();
    expect(WalletCache.peek('o1'), null);
  });

  test('store lalu peek kena', () {
    WalletCache.invalidate();
    WalletCache.store('o1', [_w('a', 'Kas')], {});
    final c = WalletCache.peek('o1');
    expect(c, isNotNull);
    expect(c!.wallets.map((w) => w.id), ['a']);
  });

  test('org beda tidak kena', () {
    WalletCache.invalidate();
    WalletCache.store('o1', [_w('a', 'Kas')], {});
    expect(WalletCache.peek('o2'), null);
  });

  test('invalidate menghapus', () {
    WalletCache.invalidate();
    WalletCache.store('o1', [_w('a', 'Kas')], {});
    WalletCache.invalidate();
    expect(WalletCache.peek('o1'), null);
  });
}
