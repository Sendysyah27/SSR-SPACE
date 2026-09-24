import 'package:flutter_test/flutter_test.dart';
import 'package:ssr_space/core/saas/foreground_track.dart';

void main() {
  test('foregroundGate: start hanya Android + master ON + session aktif', () {
    expect(
      foregroundGate(isAndroid: true, masterOn: true, hasSession: true),
      isNull,
    );
    expect(
      foregroundGate(isAndroid: false, masterOn: true, hasSession: true),
      'Bukan Android',
    );
    expect(
      foregroundGate(isAndroid: true, masterOn: false, hasSession: true),
      'Pelacakan mati',
    );
    expect(
      foregroundGate(isAndroid: true, masterOn: true, hasSession: false),
      'Belum masuk',
    );
  });
}
