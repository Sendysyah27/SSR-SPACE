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
