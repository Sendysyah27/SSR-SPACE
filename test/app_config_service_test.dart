import 'package:flutter_test/flutter_test.dart';
import 'package:ssr_space/services/app_config_service.dart';

void main() {
  test('fail-closed: tanpa seed semua flag mati', () {
    final s = AppConfigService();
    expect(s.isEnabled('flag_baru'), false);
    expect(s.isEnabled('flag_baru', defaultValue: true), true);
    expect(s.getString('x'), '');
    expect(s.getString('x', defaultValue: 'd'), 'd');
  });

  test('nilai truthy dikenali (1/true/on/ya, case-insensitive)', () {
    final s = AppConfigService();
    s.debugSeed({
      'a': '1',
      'b': 'true',
      'c': 'ON',
      'd': 'Ya',
      'e': '0',
      'f': 'false',
      'g': 'mungkin',
    });
    for (final k in ['a', 'b', 'c', 'd']) {
      expect(s.isEnabled(k), true, reason: k);
    }
    for (final k in ['e', 'f', 'g']) {
      expect(s.isEnabled(k), false, reason: k);
    }
    expect(s.getString('a'), '1');
  });

  test('debugReset mengosongkan cache', () {
    final s = AppConfigService();
    s.debugSeed({'a': '1'});
    expect(s.isEnabled('a'), true);
    s.debugReset();
    expect(s.isEnabled('a'), false);
  });
}
