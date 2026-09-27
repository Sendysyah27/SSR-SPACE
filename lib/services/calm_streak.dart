/// Calm streak tanpa nuansa judi (P2), Dart murni.
///
/// 8 bool untuk 8 minggu terakhir (Senin-Minggu, Senin tetap awal minggu
/// sesuai spec), indeks 0 = 7 minggu lalu, indeks 7 = minggu berjalan.
/// Terisi bila ada minimal satu tanggal di minggu itu. Tanggal masa depan
/// (setelah hari [now]) diabaikan. List kosong = semua false (pemanggil
/// menampilkan ajakan catat, bukan deret dot kosong).
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
