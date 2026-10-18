import 'dart:async';

import 'package:ssr_space/services/category_meta.dart';
import 'package:ssr_space/services/month.dart';
import 'package:ssr_space/services/offline_cache.dart';
import 'package:ssr_space/services/saving.dart';
import 'package:ssr_space/services/supabase_config.dart';
import 'package:ssr_space/services/pg_trigger_codes.dart';
import 'package:ssr_space/services/transaction_service.dart';
import 'package:ssr_space/services/wallet_service.dart';
import 'package:ssr_space/utils/strings.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  /// Cache offline (round-trip dengan fromMap).
  Map<String, dynamic> toMap() => {
        'category': category,
        'limit_amount': limit,
        'spent': spent,
        'warn_pct': warnPct,
      };

  factory Budget.fromMap(Map<String, dynamic> m) => Budget(
        category: (m['category'] ?? '').toString(),
        limit: (m['limit_amount'] as num?)?.toDouble() ?? 0,
        spent: (m['spent'] as num?)?.toDouble() ?? 0,
        warnPct: (m['warn_pct'] as num?)?.toInt() ?? 80,
      );
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

  /// Cache offline (round-trip dengan fromMap).
  Map<String, dynamic> toMap() => {
        'items': [for (final b in items) b.toMap()],
        'totalIn': totalIn,
      };

  factory BudgetMonth.fromMap(Map<String, dynamic> m) => BudgetMonth(
        items: [
          for (final r in (m['items'] as List? ?? []))
            Budget.fromMap(Map<String, dynamic>.from(r as Map)),
        ],
        totalIn: (m['totalIn'] as num?)?.toDouble() ?? 0,
      );

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
  final month = currentMonth();
  try {
    final c = SupabaseConfig.client;
    final rows = await c
        .from('budgets')
        .select()
        .eq('org_id', orgId)
        .eq('month', month);
    markOnline();
    final out = [
      for (final r in List<Map<String, dynamic>>.from(rows))
        Budget(
          category: (r['category'] ?? '').toString(),
          limit: (r['limit_amount'] as num).toDouble(),
          spent: 0,
          warnPct: (r['warn_pct'] as num?)?.toInt() ?? 80,
        ),
    ];
    unawaited(writeBudgetCache(orgId, month,
        {'items': [for (final b in out) b.toMap()], 'totalIn': 0}));
    return out;
  } catch (e) {
    if (!isNetworkError(e)) rethrow;
    markOffline();
    final cached = await readBudgetCache(orgId, month);
    if (cached != null) {
      return BudgetMonth.fromMap(cached).items;
    }
    rethrow;
  }
}

Future<BudgetMonth> fetchBudgets(String orgId) async {
  final month = currentMonth();
  try {
    final c = SupabaseConfig.client;
    final rows = await c.from('budgets').select().eq('org_id', orgId).eq('month', month);
    // Ambil transaksi BULAN BERJALAN di server (bukan 100 terakhir lintas
    // bulan) agar total budget tidak undercount.
    final txs = await TransactionService().listMonth(orgId, month);
    final spent = <String, double>{};
    for (final t in txs) {
      if (t.type == 'out' && (t.date ?? '').startsWith(month)) {
        // Grup di lapis kategori: 'Makan > Jajan' ikut budget 'Makan'.
        final top = topOf(t.category);
        final k = top.isEmpty ? tr('cat_other') : top;
        spent[k] = (spent[k] ?? 0) + t.amount;
      }
    }
    final out = BudgetMonth(
      items: [
        for (final r in List<Map<String, dynamic>>.from(rows))
          Budget(
            category: (r['category'] ?? '').toString(),
            limit: (r['limit_amount'] as num).toDouble(),
            spent: spent[(r['category'] ?? '').toString()] ?? 0,
            warnPct: (r['warn_pct'] as num?)?.toInt() ?? 80,
          ),
      ],
      totalIn: inOfMonth(txs, month),
    );
    markOnline();
    unawaited(writeBudgetCache(orgId, month, out.toMap()));
    return out;
  } catch (e) {
    if (!isNetworkError(e)) rethrow;
    markOffline();
    final cached = await readBudgetCache(orgId, month);
    if (cached != null) return BudgetMonth.fromMap(cached);
    rethrow;
  }
}

Future<void> setBudget(
  String orgId,
  String category,
  double limit, {
  int warnPct = 80,
}) async {
  // Trigger kuota (migration_20) hanya menolak bucket BARU — edit baris
  // existing lolos di server. Tertolak → paywall, bukan error teknis.
  try {
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
  } on PostgrestException catch (e) {
    if (pgIsQuotaExceeded(e)) {
      throw QuotaExceededException(tr('q_budget_exceeded'));
    }
    rethrow;
  }
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
