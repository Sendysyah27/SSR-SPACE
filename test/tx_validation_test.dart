import 'package:flutter_test/flutter_test.dart';
import 'package:ssr_space/core/saas/tx_validation.dart';

void main() {
  test('amount <= 0 ditolak', () {
    expect(
      validateTxInput(amount: 0, walletId: 'w1', type: 'out'),
      'Nominal harus lebih dari 0',
    );
    expect(
      validateTxInput(amount: -5, walletId: 'w1', type: 'in'),
      'Nominal harus lebih dari 0',
    );
  });

  test('wallet wajib', () {
    expect(
      validateTxInput(amount: 1000, walletId: null, type: 'out'),
      'Pilih dompet',
    );
  });

  test('transfer tujuan null', () {
    expect(
      validateTxInput(amount: 1000, walletId: 'w1', type: 'transfer', toWalletId: null),
      'Pilih dompet tujuan',
    );
  });

  test('transfer tujuan sama dengan asal', () {
    expect(
      validateTxInput(amount: 1000, walletId: 'w1', type: 'transfer', toWalletId: 'w1'),
      'Dompet tujuan sama dengan asal',
    );
  });

  test('input valid', () {
    expect(
      validateTxInput(amount: 1000, walletId: 'w1', type: 'out'),
      isNull,
    );
    expect(
      validateTxInput(amount: 1000, walletId: 'w1', type: 'transfer', toWalletId: 'w2'),
      isNull,
    );
  });
}
