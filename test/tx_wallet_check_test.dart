import 'package:flutter_test/flutter_test.dart';
import 'package:ssr_space/models/transaction.dart';
import 'package:ssr_space/services/tx_wallet_check.dart';

SaasTransaction _tx({
  required String type,
  required double amount,
  String? walletId,
  String? toWalletId,
}) =>
    SaasTransaction(
      id: 't1',
      orgId: 'o1',
      type: type,
      amount: amount,
      walletId: walletId,
      toWalletId: toWalletId,
    );

void main() {
  test('in/out berdompet bukan tanpa-dompet', () {
    expect(hasNoWallet(_tx(type: 'in', amount: 1000, walletId: 'w1')), isFalse);
    expect(hasNoWallet(_tx(type: 'out', amount: 1000, walletId: 'w1')), isFalse);
  });

  test('in/out tanpa dompet terdeteksi', () {
    expect(hasNoWallet(_tx(type: 'in', amount: 1000)), isTrue);
    expect(hasNoWallet(_tx(type: 'out', amount: 1000, walletId: null)), isTrue);
  });

  test('transfer butuh dua sisi dompet', () {
    expect(
      hasNoWallet(
        _tx(type: 'transfer', amount: 5000, walletId: 'w1', toWalletId: 'w2'),
      ),
      isFalse,
    );
    expect(
      hasNoWallet(_tx(type: 'transfer', amount: 5000, walletId: 'w1')),
      isTrue,
    );
    expect(
      hasNoWallet(_tx(type: 'transfer', amount: 5000, toWalletId: 'w2')),
      isTrue,
    );
    expect(hasNoWallet(_tx(type: 'transfer', amount: 5000)), isTrue);
  });

  test('noWalletTotal hanya jumlahkan yang tanpa dompet', () {
    final txs = [
      _tx(type: 'in', amount: 100000, walletId: 'w1'),
      _tx(type: 'out', amount: 25000),
      _tx(type: 'in', amount: 50000, walletId: 'w2'),
      _tx(type: 'out', amount: 10000, walletId: null),
    ];
    expect(noWalletTotal(txs), 35000);
  });

  test('noWalletTotal list kosong = 0', () {
    expect(noWalletTotal([]), 0);
  });
}
