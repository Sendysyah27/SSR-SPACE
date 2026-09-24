import 'package:flutter_test/flutter_test.dart';
import 'package:ssr_space/models/wallet_balance.dart';

void main() {
  test('fromMap int balance', () {
    final b = WalletBalance.fromMap({'wallet_id': 'w1', 'balance': 100000});
    expect(b.walletId, 'w1');
    expect(b.balance, 100000.0);
  });

  test('fromMap double balance', () {
    final b = WalletBalance.fromMap({'wallet_id': 'w2', 'balance': 10.5});
    expect(b.balance, 10.5);
  });

  test('fromMap string numeric balance', () {
    final b = WalletBalance.fromMap({'wallet_id': 'w3', 'balance': '2500'});
    expect(b.balance, 2500.0);
  });
}
