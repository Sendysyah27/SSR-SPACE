/// Insight mingguan otomatis. Dart murni, offline-first.
///
/// Dibangun dari transaksi belanja (non-tabungan, pemanggil menyaring)
/// 5 minggu terakhir. Kartu muncul bila minggu lalu (Senin-Minggu
/// kemarin, lengkap) ada belanja. Saran = potong 20% kategori paling
/// naik, dibulatkan ke ribuan biar angkanya enak dibaca.
class WeeklyTx {
  final DateTime date;
  final double amount;
  final String category;
  const WeeklyTx({
    required this.date,
    required this.amount,
    required this.category,
  });
}

class WeeklyInsight {
  final double lastTotal;
  final double avgWeekly;
  final bool hasAvg;
  final double totalPct;
  final String topCategory;
  final double? topPct;
  final double topTotal;
  final double saveWeekly;
  final double saveMonthly;
  const WeeklyInsight({
    required this.lastTotal,
    required this.avgWeekly,
    required this.hasAvg,
    required this.totalPct,
    required this.topCategory,
    required this.topPct,
    required this.topTotal,
    required this.saveWeekly,
    required this.saveMonthly,
  });
}

/// Senin minggu berjalan (Senin tetap awal minggu, ikut calm_streak).
DateTime weekMonday(DateTime d) {
  final day = DateTime(d.year, d.month, d.day);
  return day.subtract(Duration(days: (day.weekday - 1) % 7));
}

/// Kunci minggu ISO sederhana `YYYY-Www` untuk prefs dismiss.
/// Kamis penentu tahun (aturan ISO).
String weekKey(DateTime d) {
  final day = DateTime(d.year, d.month, d.day);
  final thursday = day.add(Duration(days: 4 - day.weekday));
  final year = thursday.year;
  final jan4 = DateTime(year, 1, 4);
  final week1Mon = weekMonday(jan4);
  final n = thursday.difference(week1Mon).inDays ~/ 7 + 1;
  return '$year-W${n.toString().padLeft(2, '0')}';
}

double _roundK(double v) => (v / 1000).round() * 1000.0;

WeeklyInsight? buildWeeklyInsight({
  required List<WeeklyTx> txs,
  required DateTime now,
}) {
  final thisMon = weekMonday(now);
  final lastMon = thisMon.subtract(const Duration(days: 7));
  final lastSunEnd = thisMon;
  double lastTotal = 0;
  final lastByCat = <String, double>{};
  final prevTotals = List<double>.filled(4, 0);
  final prevByCat = <String, List<double>>{};
  var anyPrev = false;
  for (final t in txs) {
    final day = DateTime(t.date.year, t.date.month, t.date.day);
    if (!day.isBefore(lastSunEnd)) continue;
    if (!day.isBefore(lastMon)) {
      lastTotal += t.amount;
      lastByCat[t.category] = (lastByCat[t.category] ?? 0) + t.amount;
    } else {
      final weeksAgo = (lastMon.difference(day).inDays - 1) ~/ 7 + 1;
      if (weeksAgo >= 1 && weeksAgo <= 4) {
        prevTotals[weeksAgo - 1] += t.amount;
        anyPrev = true;
        final arr = prevByCat.putIfAbsent(t.category, () => List.filled(4, 0));
        arr[weeksAgo - 1] += t.amount;
      }
    }
  }
  if (lastTotal <= 0) return null;
  final avg = prevTotals.fold<double>(0, (s, v) => s + v) / 4;
  final hasAvg = anyPrev && avg > 0;
  final totalPct = hasAvg ? (lastTotal - avg) / avg * 100 : 0.0;
  // Kategori pemenang: kenaikan % terbesar vs rata-ratanya sendiri.
  // Tanpa riwayat = pendatang baru, dipilih yang nominal terbesar.
  String top = '';
  double topSum = 0;
  double? topPct;
  lastByCat.forEach((cat, sum) {
    final arr = prevByCat[cat];
    final catAvg =
        arr == null ? 0.0 : arr.fold<double>(0, (s, v) => s + v) / 4;
    if (catAvg > 0) {
      final pct = (sum - catAvg) / catAvg * 100;
      if (topPct == null || pct > topPct!) {
        top = cat;
        topSum = sum;
        topPct = pct;
      }
    } else if (topPct == null && sum > topSum) {
      top = cat;
      topSum = sum;
    }
  });
  if (top.isEmpty) return null;
  var save = _roundK(topSum * 0.2);
  if (save <= 0) save = 1000;
  return WeeklyInsight(
    lastTotal: lastTotal,
    avgWeekly: avg,
    hasAvg: hasAvg,
    totalPct: totalPct,
    topCategory: top,
    topPct: topPct,
    topTotal: topSum,
    saveWeekly: save,
    saveMonthly: save * 4,
  );
}
