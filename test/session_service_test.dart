import 'package:flutter_test/flutter_test.dart';
import 'package:ssr_space/core/session/session_service.dart';

void main() {
  test('PIN hash verify works', () async {
    final s = SessionService.inMemory();
    await s.setPin('123456');
    expect(await s.verifyPin('123456'), true);
    expect(await s.verifyPin('000000'), false);
  });

  test('lockout after 5 wrong', () async {
    final s = SessionService.inMemory();
    await s.setPin('123456');
    for (var i = 0; i < 5; i++) {
      await s.verifyPin('000000');
    }
    expect(s.isLockedOut, true);
  });

  test('first run flips after onboarding', () async {
    final s = SessionService.inMemory();
    expect(s.isFirstRun, true);
    await s.completeOnboarding('Bro');
    expect(s.isFirstRun, false);
  });
}
