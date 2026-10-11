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
  final int topWeekday;
  final double topDayTotal;
  final List<TxAnomaly> anomalies;
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
    required this.topWeekday,
    required this.topDayTotal,
    required this.anomalies,
  });
}

/// Satu transaksi janggal: nominal jauh di atas rata-rata kategorinya.
class TxAnomaly {
  final String category;
  final double amount;
  final double avg;
  final DateTime date;
  const TxAnomaly({
    required this.category,
    required this.amount,
    required this.avg,
    required this.date,
  });
}

/// Ambang anomali: >= 3x rata-rata mingguan kategori + lantai Rp50rb
/// (tanpa riwayat kategori = bukan anomali, bukan pendatang baru).
const anomalyMultiple = 3.0;
const anomalyFloor = 50000.0;
const maxAnomalies = 3;

/// Awal minggu berjalan. [startWeekday] 1 = Senin (default, ikut
/// calm_streak), 7 = Minggu. Kunci ISO [weekKey] tetap basis Senin
/// (identitas internal, bukan jendela hitung).
DateTime weekMonday(DateTime d, [int startWeekday = 1]) {
  final day = DateTime(d.year, d.month, d.day);
  final start = (startWeekday == 7) ? 7 : 1;
  final offset = (day.weekday - start + 7) % 7;
  return day.subtract(Duration(days: offset));
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
  final lastByDay = List<double>.filled(8, 0);
  final prevTotals = List<double>.filled(4, 0);
  final prevByCat = <String, List<double>>{};
  final lastTxs = <WeeklyTx>[];
  var anyPrev = false;
  for (final t in txs) {
    final day = DateTime(t.date.year, t.date.month, t.date.day);
    if (!day.isBefore(lastSunEnd)) continue;
    if (!day.isBefore(lastMon)) {
      lastTotal += t.amount;
      lastByCat[t.category] = (lastByCat[t.category] ?? 0) + t.amount;
      lastByDay[day.weekday] += t.amount;
      lastTxs.add(t);
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
  // Hari paling boros (seri = paling awal).
  var topDay = 1;
  var topDaySum = 0.0;
  for (var wd = 1; wd <= 7; wd++) {
    if (lastByDay[wd] > topDaySum) {
      topDaySum = lastByDay[wd];
      topDay = wd;
    }
  }
  // Anomali: nominal >= 3x rata-rata kategorinya + lantai 50rb.
  final anoms = <TxAnomaly>[];
  for (final t in lastTxs) {
    final arr = prevByCat[t.category];
    final catAvg =
        arr == null ? 0.0 : arr.fold<double>(0, (s, v) => s + v) / 4;
    if (catAvg <= 0) continue;
    if (t.amount >= catAvg * anomalyMultiple && t.amount >= anomalyFloor) {
      anoms.add(
        TxAnomaly(
          category: t.category,
          amount: t.amount,
          avg: catAvg,
          date: t.date,
        ),
      );
    }
  }
  anoms.sort((a, b) => b.amount.compareTo(a.amount));
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
    topWeekday: topDay,
    topDayTotal: topDaySum,
    anomalies: anoms.take(maxAnomalies).toList(),
  );
}
