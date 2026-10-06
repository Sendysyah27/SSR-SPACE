// Budget alerts: label banner + filter bulan + badge seen.
//
// File SENGAJA tanpa import apa pun supaya bisa diverifikasi via `dart`
// murni di Termux (tanpa `flutter test`). Query Supabase ada di
// `budget_service.dart` (fetchBudgetAlerts); copy UI di `strings.dart`
// (kunci `ba_*`); file ini hanya logika murni.

// Key prefs penanda "sudah lihat" per workspace per bulan.
// Nilai = jumlah alert saat terakhir ditandai (int). Tanpa write server.
String baSeenKey(String orgId, String month) => 'ba_seen_${orgId}_$month';

// True bila [m] (format 'YYYY-MM') adalah bulan berjalan.
// Algoritme sama dengan currentMonth() di services/month.dart.
bool isCurrentMonth(String m) {
  final n = DateTime.now();
  final cur = '${n.year}-${n.month.toString().padLeft(2, '0')}';
  return m == cur;
}

num _rowNum(Map<String, dynamic> row, String key) {
  final v = row[key];
  if (v is num) return v;
  return num.tryParse('$v') ?? 0;
}

String _grp(num v) {
  final neg = v < 0;
  final digits = v.truncate().abs().toString();
  final buf = StringBuffer();
  var c = 0;
  for (var i = digits.length - 1; i >= 0; i--) {
    buf.write(digits[i]);
    c++;
    if (c % 3 == 0 && i > 0) buf.write('.');
  }
  final rev = buf.toString().split('').reversed.join();
  return neg ? '-$rev' : rev;
}

// Satu baris label banner dari row budget_alerts Task 1.
// Kolom: category, level ('warn'/'breach'), spent, limit_amount
// (BUKAN 'limit' — reserved keyword). Selalu non-kosong dan
// selalu memuat nama kategori.
String alertLabel(Map<String, dynamic> row) {
  final raw = (row['category']?.toString() ?? '').trim();
  final cat = raw.isEmpty ? 'Lainnya' : raw;
  final spent = _rowNum(row, 'spent');
  final limit = _rowNum(row, 'limit_amount');
  final pct = limit > 0 ? (spent / limit * 100).round() : 0;
  return '$cat · Rp${_grp(spent)} dari Rp${_grp(limit)} ($pct%)';
}

// Badge = count alerts bulan ini minus seen. Tak pernah negatif.
int unseenAlerts(int total, int seen) =>
    total - seen < 0 ? 0 : total - seen;
