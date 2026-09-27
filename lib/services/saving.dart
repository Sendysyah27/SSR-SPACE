// Konvensi tabungan: transaksi OUT berkategori Tabungan/Savings.
// Murni (tanpa import Flutter) supaya bisa dicek via `dart` langsung.
// Dipakai layar Budget (kartu target), Laporan (iris donut), Dompet (rincian).
import '../models/transaction.dart';

/// True bila nama kategori berarti tabungan (ID/EN, case-insensitive).
/// 'Tabungan', 'tabungan darurat', 'Saving', 'Savings' -> true.
bool isSavingCategory(String? name) {
  final n = (name ?? '').trim().toLowerCase();
  if (n.isEmpty) return false;
  return n.contains('tabung') || n.contains('saving');
}

/// Total OUT tabungan. [month] 'YYYY-MM' opsional (null = semua waktu).
double savingOutOf(Iterable<SaasTransaction> txs, {String? month}) {
  var sum = 0.0;
  for (final t in txs) {
    if (t.type != 'out') continue;
    if (!isSavingCategory(t.category)) continue;
    if (month != null && !(t.date ?? '').startsWith(month)) continue;
    sum += t.amount;
  }
  return sum;
}

/// Total IN sebulan ('YYYY-MM'). Dasar banner alokasi vs pemasukan.
double inOfMonth(Iterable<SaasTransaction> txs, String month) {
  var sum = 0.0;
  for (final t in txs) {
    if (t.type == 'in' && (t.date ?? '').startsWith(month)) {
      sum += t.amount;
    }
  }
  return sum;
}

/// Kecepatan menabung vs target bulan berjalan (murni, tanpa Flutter).
///
/// [saved] = terkumpul sejauh ini, [target] = target bulan ini,
/// [today] = tanggal hari ini. Sisa dibagi hari tersisa (termasuk hari
/// ini); proyeksi = laju rata-rata sejauh ini dikali sisa hari.
/// Hari terakhir bulan dengan sisa > 0 berarti butuh sekaligus hari ini.
class SavingPace {
  final double needPerDay;
  final double actualPerDay;
  final bool onTrack;
  final double projected;

  const SavingPace({
    required this.needPerDay,
    required this.actualPerDay,
    required this.onTrack,
    required this.projected,
  });
}

SavingPace savingPace({
  required double saved,
  required double target,
  required DateTime today,
}) {
  final daysInMonth = DateTime(today.year, today.month + 1, 0).day;
  final elapsed = today.day.clamp(1, daysInMonth);
  final daysLeft = daysInMonth - today.day + 1;
  final remaining = target - saved;
  if (remaining <= 0) {
    return SavingPace(
      needPerDay: 0,
      actualPerDay: saved / elapsed,
      onTrack: true,
      projected: saved,
    );
  }
  final actual = saved / elapsed;
  final projected = saved + actual * (daysLeft - 1);
  return SavingPace(
    needPerDay: remaining / daysLeft,
    actualPerDay: actual,
    onTrack: projected >= target,
    projected: projected,
  );
}
