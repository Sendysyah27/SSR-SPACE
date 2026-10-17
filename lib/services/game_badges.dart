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

/// Id badge yang bisa dihitung ulang server (streak/tx/save/clean).
/// Urut tetap; tanda tangan lintas-modul memakai daftar ini.
const serverBadgeIds = [
  'streak3',
  'streak7',
  'streak14',
  'streak30',
  'streak100',
  'tx100',
  'save1m',
  'clean30',
];

/// Id badge sinyal-lokal yang tak bisa diturunkan server (goal/emsafe/save30).
const localBadgeIds = ['goal1', 'emsafe', 'save30'];

/// Urutan tampil di koleksi (11 badge): blok server dulu, lalu lokal.
/// Label/desc per id diambil UI dari kunci `b_<id>_t`/`b_<id>_d`.
const allBadges = [
  BadgeDef('streak3'),
  BadgeDef('streak7'),
  BadgeDef('streak14'),
  BadgeDef('streak30'),
  BadgeDef('streak100'),
  BadgeDef('tx100'),
  BadgeDef('save1m'),
  BadgeDef('clean30'),
  BadgeDef('goal1'),
  BadgeDef('emsafe'),
  BadgeDef('save30'),
];

bool _serverUnlocked(String id, GameStats s) {
  switch (id) {
    case 'streak3':
      return s.streakDays >= 3;
    case 'streak7':
      return s.streakDays >= 7;
    case 'streak14':
      return s.streakDays >= 14;
    case 'streak30':
      return s.streakDays >= 30;
    case 'streak100':
      return s.streakDays >= 100;
    case 'tx100':
      return s.txCount >= 100;
    case 'save1m':
      return s.totalSaved >= 1000000;
    case 'clean30':
      return s.cleanMonth;
    default:
      return false;
  }
}

bool _localUnlocked(String id, GameStats s) {
  switch (id) {
    case 'goal1':
      return s.goalsReached >= 1;
    case 'emsafe':
      return s.emergencySafe;
    case 'save30':
      return s.save30Done >= 1;
    default:
      return false;
  }
}

/// Id badge server-derivable yang kebuka dari [s] (fallback lokal / paritas).
List<String> unlockedServerBadges(GameStats s) =>
    [for (final id in serverBadgeIds) if (_serverUnlocked(id, s)) id];

/// Id badge sinyal-lokal yang kebuka dari [s].
List<String> localUnlockedBadges(GameStats s) =>
    [for (final id in localBadgeIds) if (_localUnlocked(id, s)) id];

/// Id badge yang kebuka (gabungan server+lokal, kompatibel pemanggil lama).
List<String> unlockedBadges(GameStats s) =>
    [...unlockedServerBadges(s), ...localUnlockedBadges(s)];

/// Id di [unlocked] yang belum ada di [seen] (untuk chip Baru).
List<String> newBadgesIn(Set<String> unlocked, Set<String> seen) =>
    unlocked.where((id) => !seen.contains(id)).toList();

/// Id yang baru kebuka sejak [seen] (kompatibel pemanggil lama).
List<String> newBadges(GameStats s, Set<String> seen) =>
    unlockedBadges(s).where((id) => !seen.contains(id)).toList();
