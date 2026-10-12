// Tantangan hemat 30 hari. Dart murni.
//
// Aturan eksplisit (jujur, tanpa toleransi tersembunyi):
// - 30 hari kalender sejak startYmd. Hari tanpa data = Rp0 = hemat.
// - Hari hemat = belanja hari itu <= target harian.
// - Milestone dari total hari-hemat kumulatif: 7/14/21/30.
// - Sukses = total belanja 30 hari <= target*30 (1 hari jebol masih
//   bisa ketutup hari lain; 29 hemat + 1 jumbo = gagal).
// - Streak = hari-hemat beruntun hingga hari terakhir yang dinilai.
class SaveDay {
  final String ymd;
  final double spent;
  const SaveDay(this.ymd, this.spent);
}

class Save30Progress {
  final int dayN;
  final int goodDays;
  final int streak;
  final double totalSpent;
  final double targetTotal;
  final List<int> milestonesHit;
  final bool finished;
  final bool success;
  const Save30Progress({
    required this.dayN,
    required this.goodDays,
    required this.streak,
    required this.totalSpent,
    required this.targetTotal,
    required this.milestonesHit,
    required this.finished,
    required this.success,
  });
}

// Milestone konsistensi (hari-hemat kumulatif).
const save30Milestones = [7, 14, 21, 30];

String _ymd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

Save30Progress evalSave30({
  required String startYmd,
  required double dailyTarget,
  required List<SaveDay> days,
  required DateTime today,
}) {
  final start = DateTime.tryParse(startYmd) ?? today;
  final day0 = DateTime(start.year, start.month, start.day);
  final now0 = DateTime(today.year, today.month, today.day);
  final elapsed = now0.difference(day0).inDays;
  final lastIdx = elapsed < 0 ? 0 : (elapsed > 29 ? 29 : elapsed);
  final spentBy = <String, double>{};
  for (final d in days) {
    spentBy[d.ymd] = (spentBy[d.ymd] ?? 0) + d.spent;
  }
  var good = 0;
  var streak = 0;
  var total = 0.0;
  for (var i = 0; i <= lastIdx; i++) {
    final key = _ymd(day0.add(Duration(days: i)));
    final spent = spentBy[key] ?? 0;
    total += spent;
    if (spent <= dailyTarget) {
      good++;
      streak++;
    } else {
      streak = 0;
    }
  }
  final hits = [
    for (final m in save30Milestones)
      if (good >= m) m,
  ];
  final finished = elapsed >= 30;
  final targetTotal = dailyTarget * 30;
  return Save30Progress(
    dayN: elapsed < 0 ? 0 : elapsed + 1,
    goodDays: good,
    streak: streak,
    totalSpent: total,
    targetTotal: targetTotal,
    milestonesHit: hits,
    finished: finished,
    success: finished && total <= targetTotal,
  );
}

// Milestone yang baru dicapai sejak [celebrated].
List<int> newMilestones(List<int> celebrated, List<int> hits) =>
    [for (final m in hits) if (!celebrated.contains(m)) m];

// Sukses berhenti-awal: total muat dalam target pro-rata hari berjalan.
bool save30ProRata(double totalSpent, double dailyTarget, int dayN) =>
    dayN > 0 && totalSpent <= dailyTarget * dayN;
List<String> suggestCuts(Map<String, double> spentByCat) {
  final rows = [
    for (final e in spentByCat.entries)
      if (e.value > 0 &&
          e.key.toLowerCase() != 'tabungan' &&
          e.key.toLowerCase() != 'savings')
        e,
  ]..sort((a, b) => b.value.compareTo(a.value));
  return [for (final r in rows.take(3)) r.key];
}
