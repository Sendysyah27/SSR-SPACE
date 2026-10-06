import 'package:shared_preferences/shared_preferences.dart';
import 'package:ssr_space/services/budget_alerts.dart';
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
  Budget({required this.category, required this.limit, required this.spent});
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
        ),
    ],
    totalIn: inOfMonth(txs, currentMonth()),
  );
}

Future<void> setBudget(String orgId, String category, double limit) async {
  await SupabaseConfig.client.from('budgets').upsert(
    {'org_id': orgId, 'category': category, 'month': currentMonth(), 'limit_amount': limit},
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

/// Alert bulan berjalan dari tabel `budget_alerts` Task 1
/// (kolom `limit_amount`, bukan `limit`). Urut kategori.
Future<List<Map<String, dynamic>>> fetchBudgetAlerts(
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

/// Jumlah alert saat terakhir ditandai seen (prefs saja, tanpa write
/// server). Key `ba_seen_<org>_<month>` (lihat [baSeenKey]).
Future<int> budgetAlertsSeen(String orgId, String month) async {
  final p = await SharedPreferences.getInstance();
  return p.getInt(baSeenKey(orgId, month)) ?? 0;
}

/// Tandai semua alert bulan ini sudah dilihat.
Future<void> markBudgetAlertsSeen(
  String orgId,
  String month,
  int count,
) async {
  final p = await SharedPreferences.getInstance();
  await p.setInt(baSeenKey(orgId, month), count);
}
