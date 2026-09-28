/// Jadwal pengingat harian, Dart murni tanpa import flutter.
///
/// Dipakai ReminderService untuk menghitung kapan notifikasi berikutnya
/// berbunyi. Sengaja tanpa import flutter agar bisa diverifikasi lokal
/// via `dart` polos.
///
/// Aturan: hari ini pukul jam:menit bila masih di masa depan (strictly
/// after [now]), kalau tidak besok jam yang sama. Di luar rentang
/// dijepit (jam 0-23, menit 0-59), tidak pernah throw.
DateTime nextDaily(int hour, int minute, DateTime now) {
  final h = hour.clamp(0, 23);
  final m = minute.clamp(0, 59);
  final candidate = DateTime(now.year, now.month, now.day, h, m);
  if (candidate.isAfter(now)) return candidate;
  return candidate.add(const Duration(days: 1));
}

/// Jadwal mingguan berikutnya untuk hari [weekday] (1 Senin .. 7 Minggu)
/// pukul jam:menit. Hari ini bila jam masih di depan, kalau tidak minggu
/// depan hari yang sama. Jepit aman, tak pernah throw.
DateTime nextWeekly(int weekday, int hour, int minute, DateTime now) {
  final wd = weekday.clamp(1, 7);
  final h = hour.clamp(0, 23);
  final m = minute.clamp(0, 59);
  var candidate = DateTime(now.year, now.month, now.day, h, m);
  final delta = (wd - candidate.weekday) % 7;
  candidate = candidate.add(Duration(days: delta));
  if (!candidate.isAfter(now)) {
    candidate = candidate.add(const Duration(days: 7));
  }
  return candidate;
}

/// Petakan offset jam lokal ke zona IANA Indonesia.
///
/// Tanpa plugin tambahan app tak bisa membaca nama zona IANA device,
/// padahal paket timezone butuh Location agar alarm berbunyi di jam
/// lokal yang benar. Offset Indonesia tetap (tanpa DST) sehingga
/// pemetaan ini aman; di luar +7/+8/+9 kembalikan UTC (fail-open,
/// follow-up: pasang flutter_timezone untuk pengguna di luar Indonesia).
String zoneForOffsetHours(int hours) {
  if (hours == 7) return 'Asia/Jakarta';
  if (hours == 8) return 'Asia/Makassar';
  if (hours == 9) return 'Asia/Jayapura';
  return 'UTC';
}
