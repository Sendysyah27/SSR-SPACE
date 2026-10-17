import 'package:flutter_test/flutter_test.dart';
import 'package:ssr_space/services/calm_streak.dart';
import 'package:ssr_space/services/game_badges.dart';

void main() {
  test('server & lokal disjoint, union = allBadges', () {
    expect(serverBadgeIds.toSet().intersection(localBadgeIds.toSet()), isEmpty);
    expect({...serverBadgeIds, ...localBadgeIds}, allBadges.map((b) => b.id).toSet());
    expect(allBadges.where((b) => b.id == 'streak3' || b.id == 'streak14').length, 2);
  });

  test('unlockedServerBadges batas', () {
    expect(unlockedServerBadges(const GameStats(streakDays: 3)), contains('streak3'));
    expect(unlockedServerBadges(const GameStats(streakDays: 2)), isEmpty);
    expect(unlockedServerBadges(const GameStats(streakDays: 14)), contains('streak14'));
    expect(unlockedServerBadges(const GameStats(txCount: 100)), contains('tx100'));
    expect(unlockedServerBadges(const GameStats(totalSaved: 1000000)), contains('save1m'));
    expect(unlockedServerBadges(const GameStats(cleanMonth: true)), contains('clean30'));
    expect(localUnlockedBadges(const GameStats(goalsReached: 1)), contains('goal1'));
    expect(localUnlockedBadges(const GameStats(emergencySafe: true)), contains('emsafe'));
    expect(localUnlockedBadges(const GameStats(save30Done: 1)), contains('save30'));
  });

  test('milestone streak 3/7/14/30/100', () {
    expect(streakMilestones, [3, 7, 14, 30, 100]);
    expect(nextMilestone(2), 3);
    expect(nextMilestone(3), 7);
    expect(isMilestone(14), isTrue);
    expect(isMilestone(8), isFalse);
    expect(newBadgesIn({'streak3', 'tx100'}, {'tx100'}), ['streak3']);
  });
}
