/// Tantangan hemat mingguan. Dart murni, opt-in.
///
/// Tiga template: no-spend 3 hari, jajan <50rb, catat 7 hari.
/// Progress dihitung dari transaksi minggu berjalan (Senin-sekarang).
/// Status dievaluasi live: gagal langsung saat syarat jebol (kecuali
/// catat-harian yang baru pasti di akhir), selesai saat terpenuhi.
class WeekTx {
  final DateTime date;
  final double amount;
  final String category;
  final bool isOut;
  const WeekTx({
    required this.date,
    required this.amount,
    required this.category,
    required this.isOut,
  });
}

/// Id template yang tersedia.
const challengeTemplates = ['nospend3', 'jajan50', 'log7'];

class ChallengeState {
  /// 0 jalan, 1 selesai, 2 gagal.
  final int status;
  final double progress;
  final double target;
  const ChallengeState({
    required this.status,
    required this.progress,
    required this.target,
  });
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Awal minggu (Senin) dari [now].
DateTime challengeWeekStart(DateTime now) {
  final day = DateTime(now.year, now.month, now.day);
  return day.subtract(Duration(days: (day.weekday - 1) % 7));
}

ChallengeState evalChallenge({
  required String templateId,
  required List<WeekTx> txs,
  required DateTime now,
}) {
  final today = DateTime(now.year, now.month, now.day);
  final mon = challengeWeekStart(now);
  final inWeek = <WeekTx>[];
  for (final t in txs) {
    final day = DateTime(t.date.year, t.date.month, t.date.day);
    if (day.isBefore(mon) || day.isAfter(today)) continue;
    inWeek.add(t);
  }
  switch (templateId) {
    case 'nospend3':
      final spentDays = <DateTime>{};
      for (final t in inWeek) {
        if (!t.isOut) continue;
        spentDays.add(DateTime(t.date.year, t.date.month, t.date.day));
      }
      var clean = 0;
      var cursor = mon;
      while (!cursor.isAfter(today)) {
        if (!spentDays.any((d) => _sameDay(d, cursor))) clean++;
        cursor = cursor.add(const Duration(days: 1));
      }
      return ChallengeState(
        status: clean >= 3 ? 1 : 0,
        progress: clean > 3 ? 3 : clean.toDouble(),
        target: 3,
      );
    case 'jajan50':
      var jajan = 0.0;
      for (final t in inWeek) {
        if (!t.isOut) continue;
        final c = t.category.toLowerCase();
        if (c.contains('jajan')) jajan += t.amount;
      }
      return ChallengeState(
        status: jajan >= 50000 ? 2 : 0,
        progress: jajan > 50000 ? 50000 : jajan,
        target: 50000,
      );
    case 'log7':
      final days = <DateTime>{};
      for (final t in inWeek) {
        days.add(DateTime(t.date.year, t.date.month, t.date.day));
      }
      final done = days.length >= 7;
      return ChallengeState(
        status: done ? 1 : 0,
        progress: days.length > 7 ? 7 : days.length.toDouble(),
        target: 7,
      );
    default:
      return const ChallengeState(status: 0, progress: 0, target: 1);
  }
}
