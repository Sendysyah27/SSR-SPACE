import 'package:flutter_test/flutter_test.dart';
import 'package:ssr_space/utils/lockout_logic.dart';

void main() {
  test('durasi lockout bertingkat 60s, 2x, cap 24 jam', () {
    expect(pinLockSeconds(0), 0);
    expect(pinLockSeconds(1), 60);
    expect(pinLockSeconds(2), 120);
    expect(pinLockSeconds(3), 240);
    expect(pinLockSeconds(4), 480);
    expect(pinLockSeconds(20), pinMaxLockSeconds);
    expect(pinLockSeconds(1000), pinMaxLockSeconds);
  });

  test('lima percobaan salah memicu lockout level 1', () {
    var state = const PinLockout();
    const now = 1000000;
    for (var i = 1; i <= 4; i++) {
      final result = pinRegisterFailure(state, now);
      expect(result.locked, isFalse, reason: 'percobaan $i belum terkunci');
      state = result.state;
      expect(state.failCount, i);
    }
    final fifth = pinRegisterFailure(state, now);
    expect(fifth.locked, isTrue);
    expect(fifth.lockSeconds, 60);
    expect(fifth.state.failCount, 0);
    expect(fifth.state.level, 1);
    expect(fifth.state.lockUntilMs, now + 60000);

    expect(pinIsLockedOut(fifth.state, now), isTrue);
    expect(pinIsLockedOut(fifth.state, now + 59999), isTrue);
    expect(pinIsLockedOut(fifth.state, now + 60000), isFalse);
  });

  test('jam dimundurkan tidak memperpendek lockout (high-water)', () {
    var state = const PinLockout();
    const now = 5000000;
    for (var i = 0; i < 5; i++) {
      state = pinRegisterFailure(state, now).state;
    }
    expect(state.lockUntilMs, now + 60000);
    expect(state.highWaterMs, now);

    // Jam perangkat dimundurkan 1 jam: waktu efektif tetap high-water.
    expect(pinIsLockedOut(state, now - 3600000), isTrue);
    // Jam maju melewati batas: baru boleh coba lagi.
    expect(pinIsLockedOut(state, now + 60000), isFalse);
  });

  test('lockout berikutnya naik level selama belum sukses', () {
    var state = const PinLockout();
    var now = 9000000;
    for (var i = 0; i < 5; i++) {
      state = pinRegisterFailure(state, now).state;
    }
    expect(state.level, 1);
    now = state.lockUntilMs; // tunggu lockout pertama habis
    PinFailureResult? result;
    for (var i = 0; i < 5; i++) {
      result = pinRegisterFailure(state, now);
      state = result.state;
    }
    expect(result!.lockSeconds, 120);
    expect(state.level, 2);
    expect(state.lockUntilMs, now + 120000);
  });

  test('PIN benar mereset level dan counter, high-water dipertahankan', () {
    var state = const PinLockout();
    const now = 7000000;
    for (var i = 0; i < 5; i++) {
      state = pinRegisterFailure(state, now).state;
    }
    final reset = pinRegisterSuccess(state, now + 61000);
    expect(reset.failCount, 0);
    expect(reset.level, 0);
    expect(reset.lockUntilMs, 0);
    expect(reset.highWaterMs, now + 61000);
    expect(pinIsLockedOut(reset, now + 61000), isFalse);
  });

  test('effectiveNowMs memakai nilai terbesar', () {
    expect(effectiveNowMs(10, 5), 10);
    expect(effectiveNowMs(5, 10), 10);
    expect(effectiveNowMs(10, 10), 10);
  });
}