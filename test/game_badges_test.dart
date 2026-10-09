import 'package:flutter_test/flutter_test.dart';
import 'package:ssr_space/services/game_badges.dart';

void main() {
  test('kosong = nol badge', () {
    expect(unlockedBadges(const GameStats()), isEmpty);
  });

  test('streak berjenjang', () {
    final u = unlockedBadges(const GameStats(streakDays: 30));
    expect(u, containsAll(['streak7', 'streak30']));
    expect(u, isNot(contains('streak100')));
  });

  test('hampir komplit kecuali tx', () {
    final u = unlockedBadges(const GameStats(
      streakDays: 100,
      totalSaved: 2000000,
      txCount: 50,
      cleanMonth: true,
      goalsReached: 2,
      emergencySafe: true,
      challengesDone: 1,
    ));
    expect(u.length, 7);
    expect(u, isNot(contains('tx100')));
  });

  test('baru vs sudah dilihat', () {
    expect(newBadges(const GameStats(streakDays: 7), {'streak7'}), isEmpty);
    expect(newBadges(const GameStats(streakDays: 7), {}), ['streak7']);
  });
}
