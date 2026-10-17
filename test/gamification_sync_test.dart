import 'package:flutter_test/flutter_test.dart';
import 'package:ssr_space/services/gamification_service.dart';

void main() {
  test('parseBadgeSet terima map & string, buang id asing', () {
    expect(
      parseBadgeSet([
        {'id': 'streak3', 'unlocked_at': '2026-01-01'},
        'tx100',
        'bogus',
        42,
      ]),
      {'streak3', 'tx100'},
    );
    expect(parseBadgeSet('nope'), isEmpty);
    expect(parseBadgeSet(null), isEmpty);
  });

  test('parseNewBadgeList buang asing + duplikat', () {
    expect(
      parseNewBadgeList(['streak3', 'streak3', 'x', 'clean30', 7]),
      ['streak3', 'clean30'],
    );
    expect(parseNewBadgeList(null), isEmpty);
  });

  test('sync: tampil sekali, ack semua, seen dilewati', () async {
    final shown = <List<String>>[];
    final acked = <List<String>>[];
    final sync = AchievementSync(
      show: (ids) async => shown.add(List.of(ids)),
      ack: (ids) async => acked.add(List.of(ids)),
      loadSeen: () async => <String>{'streak7'},
    );
    await sync.sync(['streak3', 'streak7']);
    expect(shown, [
      ['streak3'],
    ]);
    expect(acked, [
      ['streak3', 'streak7'],
    ]);
    // Panggilan kedua id sama: tak tampil lagi, ack tetap (idempoten).
    await sync.sync(['streak3', 'streak7']);
    expect(shown.length, 1);
    expect(acked.length, 2);
    expect(acked.last, ['streak3', 'streak7']);
  });

  test('sync overlap diserialkan + sesi (tak dobel)', () async {
    var shown = 0;
    var acked = 0;
    final sync = AchievementSync(
      show: (ids) async {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        shown++;
      },
      ack: (ids) async => acked++,
      loadSeen: () async => <String>{},
    );
    final a = sync.sync(['clean30']);
    final b = sync.sync(['clean30']);
    await Future.wait([a, b]);
    expect(shown, 1);
    expect(acked, 2);
  });
}
