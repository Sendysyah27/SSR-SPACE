/// Badge achievement. Dart murni.
///
/// Syarat dibaca dari [GameStats] yang dihitung pemanggil dari data
/// lokal. Terkunci = tampil abu beserta syaratnya (jujur, tanpa ???).
/// Koleksi baru = id yang belum ada di seen prefs (diurus store).
class GameStats {
  final int streakDays;
  final double totalSaved;
  final int txCount;
  final bool txCapped;
  final bool cleanMonth;
  final int goalsReached;
  final bool emergencySafe;
  final int challengesDone;
  final int save30Done;
  const GameStats({
    this.streakDays = 0,
    this.totalSaved = 0,
    this.txCount = 0,
    this.txCapped = false,
    this.cleanMonth = false,
    this.goalsReached = 0,
    this.emergencySafe = false,
    this.challengesDone = 0,
    this.save30Done = 0,
  });
}

class BadgeDef {
  final String id;
  const BadgeDef(this.id);
}

/// Urutan tampil di koleksi (9 badge).
const allBadges = [
  BadgeDef('streak7'),
  BadgeDef('streak30'),
  BadgeDef('streak100'),
  BadgeDef('save1m'),
  BadgeDef('clean30'),
  BadgeDef('goal1'),
  BadgeDef('tx100'),
  BadgeDef('emsafe'),
  BadgeDef('save30'),
];

bool _unlocked(String id, GameStats s) {
  switch (id) {
    case 'streak7':
      return s.streakDays >= 7;
    case 'streak30':
      return s.streakDays >= 30;
    case 'streak100':
      return s.streakDays >= 100;
    case 'save1m':
      return s.totalSaved >= 1000000;
    case 'clean30':
      return s.cleanMonth;
    case 'goal1':
      return s.goalsReached >= 1;
    case 'tx100':
      return s.txCount >= 100;
    case 'emsafe':
      return s.emergencySafe;
    case 'save30':
      return s.save30Done >= 1;
    default:
      return false;
  }
}

/// Id badge yang kebuka. [cappedIds] = badge berbasis hitungan yang
/// sumbernya kepotong limit (tx100 bila list penuh): tetap diklaim
/// dengan label jujur 100+ di UI.
List<String> unlockedBadges(GameStats s) =>
    [for (final b in allBadges) if (_unlocked(b.id, s)) b.id];

/// Id yang baru kebuka sejak [seen] (untuk chip Baru).
List<String> newBadges(GameStats s, Set<String> seen) =>
    unlockedBadges(s).where((id) => !seen.contains(id)).toList();
