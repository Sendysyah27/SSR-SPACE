/// Simulasi pencapaian goal + status dana darurat. Dart murni.
///
/// [savePerMonth] = nabung per bulan N bulan terakhir (tanpa bulan
/// berjalan, urutan bebas). Rata-rata = jumlah / N; kosong = 0 (jujur
/// "belum bisa diproyeksi", bukan nebak).
class GoalForecast {
  final double avgPerMonth;
  final DateTime? projectedMonth;
  final double? needPerMonth;
  final double? extraPerMonth;
  final bool onTrack;
  final bool overdue;
  const GoalForecast({
    required this.avgPerMonth,
    required this.projectedMonth,
    required this.needPerMonth,
    required this.extraPerMonth,
    required this.onTrack,
    required this.overdue,
  });
}

DateTime _monthStart(DateTime d) => DateTime(d.year, d.month, 1);

DateTime _addMonths(DateTime d, int n) {
  final total = (d.month - 1) + n;
  return DateTime(d.year + total ~/ 12, total % 12 + 1, 1);
}

/// Selisih bulan kalender deadline - hari ini. Negatif = sudah lewat.
int _monthDiff(DateTime today, DateTime dl) =>
    (dl.year - today.year) * 12 + (dl.month - today.month);

GoalForecast? forecastGoal({
  required double saved,
  required double target,
  required List<double> savePerMonth,
  required DateTime today,
  DateTime? deadline,
}) {
  final remaining = target - saved;
  if (remaining <= 0) {
    return GoalForecast(
      avgPerMonth: savePerMonth.isEmpty
          ? 0
          : savePerMonth.fold<double>(0, (s, v) => s + v) /
              savePerMonth.length,
      projectedMonth: _monthStart(today),
      needPerMonth: 0,
      extraPerMonth: 0,
      onTrack: true,
      overdue: false,
    );
  }
  final avg = savePerMonth.isEmpty
      ? 0.0
      : savePerMonth.fold<double>(0, (s, v) => s + v) / savePerMonth.length;
  DateTime? projected;
  if (avg > 0) {
    final need = (remaining / avg).ceil();
    projected = _addMonths(_monthStart(today), need - 1);
  }
  if (deadline == null) {
    return GoalForecast(
      avgPerMonth: avg,
      projectedMonth: projected,
      needPerMonth: null,
      extraPerMonth: null,
      onTrack: projected != null,
      overdue: false,
    );
  }
  final dlStart = _monthStart(deadline);
  final nowStart = _monthStart(today);
  if (dlStart.isBefore(nowStart)) {
    return GoalForecast(
      avgPerMonth: avg,
      projectedMonth: projected,
      needPerMonth: remaining,
      extraPerMonth: remaining > avg ? remaining - avg : 0,
      onTrack: false,
      overdue: true,
    );
  }
  final monthsLeft = _monthDiff(today, deadline) + 1;
  final need = remaining / monthsLeft;
  final extra = need > avg ? need - avg : 0.0;
  final track = projected != null && !projected.isAfter(dlStart);
  return GoalForecast(
    avgPerMonth: avg,
    projectedMonth: projected,
    needPerMonth: need,
    extraPerMonth: extra > 0 ? extra : 0,
    onTrack: track,
    overdue: false,
  );
}

/// Status dana darurat: 0 belum aman (<3x), 1 progres (3-6x), 2 aman.
/// Null bila pengeluaran acuan tak ada (tak bisa hitung, bukan nol).
class EmergencyStatus {
  final int level;
  final double monthlyExpense;
  final double saved;
  final double target3;
  final double target6;
  const EmergencyStatus({
    required this.level,
    required this.monthlyExpense,
    required this.saved,
    required this.target3,
    required this.target6,
  });
}

EmergencyStatus? emergencyFund({
  required double monthlyExpense,
  required double saved,
}) {
  // Data real aneh (NaN/Infinity) → null (kartu sembunyi), bukan throw.
  if (!monthlyExpense.isFinite || !saved.isFinite) return null;
  if (monthlyExpense <= 0) return null;
  final t3 = monthlyExpense * 3;
  final t6 = monthlyExpense * 6;
  final level = saved >= t6 ? 2 : (saved >= t3 ? 1 : 0);
  return EmergencyStatus(
    level: level,
    monthlyExpense: monthlyExpense,
    saved: saved,
    target3: t3,
    target6: t6,
  );
}
