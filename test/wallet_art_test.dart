import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ssr_space/widgets/wallet_art.dart';

void main() {
  test('peta mencakup tiga tipe plus fallback asing', () {
    expect(walletSvgPath('cash'), 'assets/illustrations/wallet_cash.svg');
    expect(
      walletSvgPath('ewallet'),
      'assets/illustrations/wallet_ewallet.svg',
    );
    expect(walletSvgPath('bank'), 'assets/illustrations/wallet_bank.svg');
    expect(walletSvgPath('kripto'), walletSvgPath('cash'));
    expect(walletSvgPath(''), isNotEmpty);
  });

  test('file terdaftar di pubspec assets', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec.contains('assets/illustrations/'), true);
    for (final p in [
      walletSvgPath('cash'),
      walletSvgPath('ewallet'),
      walletSvgPath('bank'),
    ]) {
      expect(File(p).existsSync(), true, reason: p);
    }
  });
}
