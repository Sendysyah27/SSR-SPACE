import 'package:flutter_test/flutter_test.dart';
import 'package:ssr_space/services/space_logic.dart';

void main() {
  test('parseSpaceMode hanya bendahara yang lolos', () {
    expect(parseSpaceMode('bendahara'), 'bendahara');
    expect(parseSpaceMode('bebas'), 'bebas');
    expect(parseSpaceMode(null), 'bebas');
    expect(parseSpaceMode('ADMIN'), 'bebas');
    expect(parseSpaceMode(7), 'bebas');
  });

  test('spaceSeenKey prefix per org', () {
    expect(spaceSeenKey('o1'), 'space_seen_o1');
  });

  test('unseenCount hitung log lebih baru dari seen', () {
    final t1 = DateTime(2026, 9, 28, 10, 0);
    final t2 = DateTime(2026, 9, 28, 11, 0);
    expect(unseenCount([t1, t2], null), 2);
    expect(unseenCount([t1, t2], DateTime(2026, 9, 28, 10, 30)), 1);
    expect(unseenCount([t1], t2), 0);
    expect(unseenCount([], t1), 0);
  });

  test('actorLabel potongan id + flag saya', () {
    expect(actorLabel('abc123', 'abc123').$1, '');
    expect(actorLabel('abc123', 'abc123').$2, true);
    expect(actorLabel('def456789', 'abc123').$1, 'def4');
    expect(actorLabel('def456789', 'abc123').$2, false);
    expect(actorLabel(null, 'abc123').$1, '????');
  });
}
