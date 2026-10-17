/// Calm streak tanpa nuansa judi (P2), Dart murni.
///
/// 8 bool untuk 8 minggu terakhir (Senin-Minggu, Senin tetap awal minggu
/// sesuai spec), indeks 0 = 7 minggu lalu, indeks 7 = minggu berjalan.
/// Terisi bila ada minimal satu tanggal di minggu itu. Tanggal masa depan
/// (setelah hari [now]) diabaikan. List kosong = semua false (pemanggil
/// menampilkan ajakan catat, bukan deret dot kosong).
///
/// Streak harian (LOOP 1): hitung hari beruntun ada catatan, berakhir
/// hari ini. Grace 1 hari: bila hari ini belum catat tapi kemarin ada,
/// streak kemarin tetap tampil (pemanggil mengajak catat hari ini).
/// Satu hari bolong di tengah tetap memutus, dua hari kosong = 0.
List<bool> calmWeeks(List<DateTime> dates, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final mondayThisWeek =
      today.subtract(Duration(days: (today.weekday - 1) % 7));
  final filled = List<bool>.filled(8, false);
  for (final d in dates) {
    final day = DateTime(d.year, d.month, d.day);
    if (day.isAfter(today)) continue;
    final diff = today.difference(day).inDays;
    if (diff < 0 || diff >= 7 * 8) continue;
    final mondayOfDay =
        day.subtract(Duration(days: (day.weekday - 1) % 7));
    final weekIndex =
        7 - mondayThisWeek.difference(mondayOfDay).inDays ~/ 7;
    if (weekIndex >= 0 && weekIndex < 8) filled[weekIndex] = true;
  }
  return filled;
}

/// Streak catat harian. [days] = jumlah hari beruntun, [todayDone] =
/// hari ini sudah ada catatan, [graceUsed] = tampil berkat toleransi
/// kemarin (hari ini belum catat).
class DailyStreak {
  final int days;
  final bool todayDone;
  final bool graceUsed;
  const DailyStreak({
    required this.days,
    required this.todayDone,
    required this.graceUsed,
  });
}

/// Hitung streak dari tanggal-tanggal transaksi (jam diabaikan).
/// Masa depan diabaikan, duplikat sehari dihitung sekali.
DailyStreak dailyStreak(List<DateTime> dates, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final seen = <DateTime>{};
  for (final d in dates) {
    final day = DateTime(d.year, d.month, d.day);
    if (day.isAfter(today)) continue;
    seen.add(day);
  }
  final todayDone = seen.contains(today);
  final yesterday = today.subtract(const Duration(days: 1));
  final anchor = todayDone
      ? today
      : (seen.contains(yesterday) ? yesterday : null);
  if (anchor == null) {
    return const DailyStreak(days: 0, todayDone: false, graceUsed: false);
  }
  var count = 0;
  var cursor = anchor;
  while (seen.contains(cursor)) {
    count++;
    cursor = cursor.subtract(const Duration(days: 1));
  }
  return DailyStreak(
    days: count,
    todayDone: todayDone,
    graceUsed: !todayDone,
  );
}

/// Milestone streak: 3, 7, 14, 30, 100 hari. Dipakai [nextMilestone] dan
/// [isMilestone] sekaligus jadi sumber tunggal ambang perayaan.
const streakMilestones = [3, 7, 14, 30, 100];

/// Milestone berikutnya yang belum dilewati. Null bila sudah lewat semua.
int? nextMilestone(int days) {
  for (final m in streakMilestones) {
    if (days < m) return m;
  }
  return null;
}

/// True tepat saat streak menyentuh salah satu [streakMilestones].
bool isMilestone(int days) => streakMilestones.contains(days);
