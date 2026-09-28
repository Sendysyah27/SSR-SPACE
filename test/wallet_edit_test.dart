import 'package:flutter_test/flutter_test.dart';
import 'package:ssr_space/services/wallet_edit_logic.dart';

void main() {
  test('nama valid bila tak kosong', () {
    expect(isValidWalletName('Kas'), isTrue);
    expect(isValidWalletName('  DANA  '), isTrue);
    expect(isValidWalletName(''), isFalse);
    expect(isValidWalletName('   '), isFalse);
  });

  test('tipe dikenal hanya 5', () {
    for (final t in ['cash', 'ewallet', 'bank', 'savings', 'investment']) {
      expect(isKnownWalletType(t), isTrue);
    }
    expect(isKnownWalletType('crypto'), isFalse);
    expect(isKnownWalletType(''), isFalse);
  });
}
