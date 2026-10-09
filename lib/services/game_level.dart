/// Level + XP. Dart murni, deterministik dari state (tanpa event log).
///
/// XP = min(tx,200)*10 + streak*5 + tantangan*50 + goal*100.
/// Cap tx 200 (=2000 XP) supaya user lama tak langsung mentok.
int calcXp({
  required int txCount,
  required int streakDays,
  required int challengesDone,
  required int goalsReached,
}) {
  final tx = txCount < 0 ? 0 : (txCount > 200 ? 200 : txCount);
  final st = streakDays < 0 ? 0 : streakDays;
  return tx * 10 + st * 5 + challengesDone * 50 + goalsReached * 100;
}

/// Ambang bawah tiap level (indeks 0 = Lv 1). 7 level, mentok 5500+.
const levelFloors = [0, 200, 500, 1000, 2000, 3500, 5500];

/// Level 1..7 dari XP.
int levelFor(int xp) {
  var lv = 1;
  for (var i = 0; i < levelFloors.length; i++) {
    if (xp >= levelFloors[i]) lv = i + 1;
  }
  return lv;
}

/// Progres 0..1 ke level berikut (level mentok = 1).
double levelProgress(int xp) {
  final lv = levelFor(xp);
  if (lv >= levelFloors.length) return 1;
  final lo = levelFloors[lv - 1];
  final hi = levelFloors[lv];
  if (hi <= lo) return 1;
  final p = (xp - lo) / (hi - lo);
  return p < 0 ? 0 : (p > 1 ? 1 : p);
}

/// Sisa XP ke level berikut (0 bila mentok).
int xpToNext(int xp) {
  final lv = levelFor(xp);
  if (lv >= levelFloors.length) return 0;
  return levelFloors[lv] - xp;
}
