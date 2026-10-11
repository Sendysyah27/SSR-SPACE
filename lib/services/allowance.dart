// Jatah harian (daily allowance): sisa budget bulan ini dibagi sisa hari.
// Murni Dart (tanpa Flutter). Definisi sisa = Σ(limit-spent) non-tabungan,
// sama dengan pace/snapshot/widget (dihitung pemanggil dari data _load).

/// Sisa hari bulan berjalan, inklusif (hari ini dihitung).
/// Oktober tgl 17 -> 15 (17..31). Hari terakhir -> 1.
int daysLeftInMonth(DateTime today) {
  final lastDay = DateTime(today.year, today.month + 1, 0).day;
  final left = lastDay - today.day + 1;
  return left < 1 ? 1 : left;
}

/// Jatah belanja per hari. Sisa <= 0 atau hari <= 0 -> 0.
double dailyAllowance({required double remaining, required int daysLeft}) {
  if (remaining <= 0 || daysLeft <= 0) return 0;
  return remaining / daysLeft;
}

/// Lampu YNAB jatah harian: merah bila sisa habis, kuning bila proyeksi
/// boncos (rata-belanja x sisa-hari > sisa), hijau sisanya.
String allowanceLight({
  required double remaining,
  required double avgDailyOut,
  required int daysLeft,
}) {
  if (remaining <= 0) return 'red';
  if (avgDailyOut * daysLeft > remaining) return 'gold';
  return 'green';
}
