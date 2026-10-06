import 'package:shared_preferences/shared_preferences.dart';
import 'package:ssr_space/services/month.dart';
import 'package:ssr_space/services/supabase_config.dart';
import 'package:ssr_space/utils/mask.dart';
import 'package:ssr_space/utils/strings.dart';

// Budget alerts Task 2: poll + label banner + badge seen.
// Query tabel `budget_alerts` Task 1 via SupabaseConfig.client;
// copy via strings `ba_*`; nominal via amt() (mask-aware).

// Key prefs penanda "sudah lihat" per workspace per bulan.
// Nilai = jumlah alert saat terakhir ditandai (int). Tanpa write server.
String baSeenKey(String orgId, String month) => 'ba_seen_${orgId}_$month';

// True bila [m] (format 'YYYY-MM') adalah bulan berjalan.
bool isCurrentMonth(String m) => m == currentMonth();

num _rowNum(Map<String, dynamic> row, String key) {
  final v = row[key];
  if (v is num) return v;
  return num.tryParse('$v') ?? 0;
}

// Satu baris label banner dari row budget_alerts Task 1.
// Kolom: category, level ('warn'/'breach'), spent, limit_amount
// (BUKAN 'limit' — reserved keyword). Level + fallback kategori via
// strings `ba_*`, nominal via amt() (ikut privacy mode).
// Selalu non-kosong dan selalu memuat nama kategori.
String alertLabel(Map<String, dynamic> row) {
  final raw = (row['category']?.toString() ?? '').trim();
  final cat = raw.isEmpty ? tr('cat_other') : raw;
  final spent = _rowNum(row, 'spent');
  final limit = _rowNum(row, 'limit_amount');
  final pct = limit > 0 ? (spent / limit * 100).round() : 0;
  final level = tr(row['level'] == 'breach' ? 'ba_breach' : 'ba_warn');
  return '$level: $cat · ${amt(spent)} ${tr('sv_of')} ${amt(limit)} ($pct%)';
}

// Badge = count alerts bulan ini minus seen. Tak pernah negatif.
int unseenAlerts(int total, int seen) =>
    total - seen < 0 ? 0 : total - seen;

// Alert bulan berjalan (kolom `limit_amount`, bukan `limit`).
// Urut kategori supaya irisan seen berbasis count stabil.
Future<List<Map<String, dynamic>>> fetchAlerts(
  String orgId,
  String month,
) async {
  final rows = await SupabaseConfig.client
      .from('budget_alerts')
      .select()
      .eq('org_id', orgId)
      .eq('month', month)
      .order('category');
  return List<Map<String, dynamic>>.from(rows);
}

// Jumlah alert saat terakhir ditandai seen (prefs saja).
Future<int> budgetAlertsSeen(String orgId, String month) async {
  final p = await SharedPreferences.getInstance();
  return p.getInt(baSeenKey(orgId, month)) ?? 0;
}

// Tandai semua alert bulan ini sudah dilihat.
Future<void> markBudgetAlertsSeen(
  String orgId,
  String month,
  int count,
) async {
  final p = await SharedPreferences.getInstance();
  await p.setInt(baSeenKey(orgId, month), count);
}
