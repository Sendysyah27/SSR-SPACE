import 'package:ssr_space/services/category_meta.dart';
import 'package:ssr_space/services/month.dart';
import 'package:ssr_space/services/saving.dart';
import 'package:ssr_space/services/supabase_config.dart';
import 'package:ssr_space/services/transaction_service.dart';
import 'package:ssr_space/utils/strings.dart';

double budgetProgress(double spent, double limit) {
  if (limit <= 0) return 0;
  final p = spent / limit;
  return p > 1 ? 1 : p;
}

class Budget {
  final String category;
  final double limit;
  final double spent;
  final int warnPct;
  Budget({
    required this.category,
    required this.limit,
    required this.spent,
    this.warnPct = 80,
  });
}

/// Ambang peringatan budget (persen, 1–100). String kosong = default 80.
/// Di luar 1–100 atau bukan angka = null (caller tampilkan `b_err_warn`).
/// Validasi client ini cerminan CHECK server (`budgets_warn_pct_check`);
/// server tetap otoritas.
int? parseWarnPct(String raw, {int fallback = 80}) {
  final t = raw.trim();
  if (t.isEmpty) return fallback;
  final v = int.tryParse(t);
  if (v == null || v < 1 || v > 100) return null;
  return v;
}

/// Hasil budget sebulan: daftar + total pemasukan bulan itu.
/// `totalIn` dihitung dari data transaksi yang sama (nol query tambah) —
/// dasar banner "total limit melebihi pemasukan".
class BudgetMonth {
  final List<Budget> items;
  final double totalIn;
  BudgetMonth({required this.items, required this.totalIn});

  double get totalLimit {
    var sum = 0.0;
    for (final b in items) {
      sum += b.limit;
    }
    return sum;
  }
}

/// Baris limit budget sebulan (tanpa hitung spent). Dasar kartu pace di
/// Beranda yang sudah memegang transaksi bulan berjalan — hemat 1 query
/// dibanding [fetchBudgets] yang me-list transaksi sendiri.
Future<List<Budget>> fetchBudgetLimits(String orgId) async {
  final c = SupabaseConfig.client;
  final rows = await c
      .from('budgets')
      .select()
      .eq('org_id', orgId)
      .eq('month', currentMonth());
  return [
    for (final r in List<Map<String, dynamic>>.from(rows))
      Budget(
        category: (r['category'] ?? '').toString(),
        // Toleran data real: limit null/string → 0 (disaring pemanggil).
        limit: _safeLimit(r['limit_amount']),
        spent: 0,
        warnPct: (r['warn_pct'] as num?)?.toInt() ?? 80,
      ),
  ];
}

/// Parse limit toleran: tak pernah throw, non-finite → 0.
double _safeLimit(dynamic v) {
  if (v is num) {
    final d = v.toDouble();
    return d.isFinite ? d : 0;
  }
  if (v is String) {
    final d = double.tryParse(v.trim().replaceAll(',', ''));
    if (d != null && d.isFinite) return d;
  }
  return 0;
}

Future<BudgetMonth> fetchBudgets(String orgId) async {
  final c = SupabaseConfig.client;
  final rows = await c.from('budgets').select().eq('org_id', orgId).eq('month', currentMonth());
  final txs = await TransactionService().list(orgId);
  final spent = <String, double>{};
  for (final t in txs) {
    if (t.type == 'out' && (t.date ?? '').startsWith(currentMonth())) {
      // Grup di lapis kategori: 'Makan > Jajan' ikut budget 'Makan'.
      final top = topOf(t.category);
      final k = top.isEmpty ? tr('cat_other') : top;
      spent[k] = (spent[k] ?? 0) + t.amount;
    }
  }
  return BudgetMonth(
    items: [
      for (final r in List<Map<String, dynamic>>.from(rows))
        Budget(
          category: (r['category'] ?? '').toString(),
          limit: (r['limit_amount'] as num).toDouble(),
          spent: spent[(r['category'] ?? '').toString()] ?? 0,
          warnPct: (r['warn_pct'] as num?)?.toInt() ?? 80,
        ),
    ],
    totalIn: inOfMonth(txs, currentMonth()),
  );
}

Future<void> setBudget(
  String orgId,
  String category,
  double limit, {
  int warnPct = 80,
}) async {
  await SupabaseConfig.client.from('budgets').upsert(
    {
      'org_id': orgId,
      'category': category,
      'month': currentMonth(),
      'limit_amount': limit,
      'warn_pct': warnPct,
    },
    onConflict: 'org_id,category,month',
  );
}

/// Hapus budget kategori sebulan. Dipanggil setelah PIN terverifikasi.
Future<void> deleteBudget(String orgId, String category) async {
  await SupabaseConfig.client
      .from('budgets')
      .delete()
      .eq('org_id', orgId)
      .eq('category', category)
      .eq('month', currentMonth());
}
