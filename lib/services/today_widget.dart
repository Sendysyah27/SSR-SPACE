import 'package:shared_preferences/shared_preferences.dart';
import 'package:ssr_space/services/app_settings.dart';
import 'package:ssr_space/services/budget_service.dart';
import 'package:ssr_space/services/category_meta.dart';
import 'package:ssr_space/services/month.dart';
import 'package:ssr_space/services/saving.dart';
import 'package:ssr_space/services/transaction_service.dart';
import 'package:ssr_space/services/wallet_service.dart';
import 'package:ssr_space/services/widget_snapshot.dart';
import 'package:ssr_space/utils/mask.dart';
import 'package:ssr_space/utils/strings.dart';
import 'package:ssr_space/utils/diag_log.dart';

// Snapshot widget home: sisa budget bulan ini + keluar hari ini (Batch 15).
//
// Provider native + QS tile hanya membaca string prefs `widget_snapshot`
// (tanpa token, tanpa query). Ditulis saat Beranda dimuat, tiap transaksi
// tersimpan (manual/auto/force), dan tiap budget berubah. Toggle mati
// menghapus snapshot lokal.
//
// Channel `ssr_space/widget` (minta gambar ulang SEKARANG) hanya dipanggil
// dari jalur simpan, TIDAK tiap load — riwayat 2.13.1: pola tiap-load
// ikut tersangka FC. Seluruh pemanggilan fail-silent (timeout 2 dtk).
const _kSnapshot = 'widget_snapshot';

/// Ketiga kunci snapshot (Hari-ini + 2 varian fase 2): toggle mati
/// menghapus semuanya agar widget kembali ke ajakan buka app.
const _allSnapshotKeys = <String>[
  _kSnapshot,
  widgetBudgetSnapshotKey,
  widgetBalanceSnapshotKey,
];

/// Tanggal hari ini 'YYYY-MM-DD' lokal (label jujur snapshot).
String _todayYmd() {
  final now = DateTime.now();
  return '${now.year.toString().padLeft(4, '0')}-'
      '${now.month.toString().padLeft(2, '0')}-'
      '${now.day.toString().padLeft(2, '0')}';
}

Future<void> refreshTodayWidget({
  required String date,
  required String text,
  String text2 = '',
}) async {
  DiagLog.write('DIAG refreshTodayWidget start');
  try {
    final prefs = await SharedPreferences.getInstance();
    if (!widgetToday.value) {
      for (final k in _allSnapshotKeys) {
        try {
          await prefs.remove(k);
        } catch (_) {}
      }
      return;
    }
    await prefs.setString(
      _kSnapshot,
      formatSnapshot(
        date: date,
        text: text,
        text2: text2,
        masked: maskAmounts.value,
      ),
    );
    DiagLog.write('DIAG refreshTodayWidget done');
  } catch (_) {
    DiagLog.write('DIAG refreshTodayWidget error');
  }
}

/// Minta provider native gambar ulang snapshot terbaru SEKARANG.
/// Fail-silent total: tak pernah throw, tak pernah menunggu >2 dtk.
Future<void> requestWidgetRefresh() async {
  // DIAG-FIX 2026-10-14: MethodChannel invokeMethod(refresh) tersangka
  // FC silent (native crash tak tertangkap Dart). Disable sementara —
  // widget tetap update via snapshot SharedPreferences yang dibaca
  // provider native secara periodik.
  DiagLog.write('DIAG requestWidgetRefresh SKIPPED (native disabled)');
  return;
}

/// Angka mentah snapshot budget: dihitung sekali, dipakai penulis
/// Hari-ini (existing) + varian budget (baru) agar jalur simpan tak
/// query ganda. Cerminan loop agregasi existing (topOf, tabungan
/// dikecualikan, limit <= 0 dilewati).
class _BudgetFigures {
  final String today;
  final double todayOut;
  final bool hasBudget;
  final double left;
  final bool anyOver;
  const _BudgetFigures({
    required this.today,
    required this.todayOut,
    required this.hasBudget,
    required this.left,
    required this.anyOver,
  });
}

/// Query server untuk angka budget (null bila gagal — pemanggil skip,
/// fail-open). Guard toggle/orgId ada di pemanggil, bukan di sini.
Future<_BudgetFigures?> _budgetFigures(String orgId) async {
  try {
    final month = currentMonth();
    final txs = await TransactionService().listMonth(orgId, month);
    final limits = await fetchBudgetLimits(orgId);
    final today = _todayYmd();
    var todayOut = 0.0;
    final spent = <String, double>{};
    for (final t in txs) {
      if (t.type != 'out') continue;
      if (t.date == today) todayOut += t.amount;
      if (!(t.date ?? '').startsWith(month)) continue;
      final top = topOf(t.category);
      if (isSavingCategory(t.category)) continue;
      final k = top.isEmpty ? tr('cat_other') : top;
      spent[k] = (spent[k] ?? 0) + t.amount;
    }
    var hasBudget = false;
    var left = 0.0;
    var anyOver = false;
    for (final b in limits) {
      if (isSavingCategory(b.category) || b.limit <= 0) continue;
      hasBudget = true;
      final s = spent[b.category] ?? 0;
      left += b.limit - s;
      if (s > b.limit) anyOver = true;
    }
    return _BudgetFigures(
      today: today,
      todayOut: todayOut,
      hasBudget: hasBudget,
      left: left,
      anyOver: anyOver,
    );
  } catch (_) {
    return null;
  }
}

/// Tulis kunci varian budget (try/catch PER KUNCI — gagal di sini tak
/// menggagalkan kunci lain). Tanpa budget → kunci dihapus agar provider
/// tampilkan ajakan, bukan angka basi.
Future<void> _writeBudgetVariant(_BudgetFigures f) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    if (!widgetToday.value || !f.hasBudget) {
      try {
        await prefs.remove(widgetBudgetSnapshotKey);
      } catch (_) {}
      return;
    }
    final lamp = widgetBudgetLamp(left: f.left, anyOver: f.anyOver);
    try {
      await prefs.setString(
        widgetBudgetSnapshotKey,
        formatSnapshot(
          date: f.today,
          text: tr('wg_budget_left').replaceFirst('{m}', amt(f.left)),
          text2: tr(lamp == 'danger' ? 'pace_danger' : 'pace_safe'),
          masked: maskAmounts.value,
        ),
      );
    } catch (_) {}
    DiagLog.write('DIAG refreshWidgetBudgetSnapshot done');
  } catch (_) {}
}

/// Tulis snapshot + minta gambar ulang, hitung dari server.
/// Dipakai jalur simpan yang tak memegang data (sheet manual, auto-track,
/// forceSave, budget). Fire-and-forget oleh pemanggil, fail-open total.
/// Isi kunci Hari-ini TAK BERUBAH; varian baru di-fan-out dari titik
/// pemicu yang sama (tanpa scheduler baru).
Future<void> refreshBudgetWidgetSnapshot(String orgId) async {
  _BudgetFigures? f;
  try {
    if (!widgetToday.value || orgId.isEmpty) return;
    f = await _budgetFigures(orgId);
    final fig = f;
    if (fig != null) {
      await refreshTodayWidget(
        date: fig.today,
        text: tr('wg_out_today').replaceFirst('{m}', amt(fig.todayOut)),
        text2: fig.hasBudget
            ? tr('wg_budget_left').replaceFirst('{m}', amt(fig.left))
            : '',
      );
      await requestWidgetRefresh();
    }
  } catch (_) {}
  // Fan-out varian: tiap penulis fail-open sendiri (budget-query gagal
  // tak menggagalkan varian saldo).
  final fig = f;
  if (fig != null) {
    try {
      await _writeBudgetVariant(fig);
    } catch (_) {}
  }
  try {
    await refreshWidgetBalanceSnapshot(orgId);
  } catch (_) {}
}

/// Varian budget (§ spec 4.1): text = sisa budget bulan (negatif/jebol
/// ditulis apa adanya), text2 = lampu pace. Berdiri sendiri untuk
/// pemanggil yang butuh hanya varian ini.
Future<void> refreshWidgetBudgetSnapshot(String orgId) async {
  DiagLog.write('DIAG refreshWidgetBudgetSnapshot start');
  try {
    if (!widgetToday.value || orgId.isEmpty) return;
    final f = await _budgetFigures(orgId);
    if (f == null) return;
    await _writeBudgetVariant(f);
  } catch (_) {
    DiagLog.write('DIAG refreshWidgetBudgetSnapshot error');
  }
}

/// Varian saldo (§ spec 4.1): text = total saldo semua dompet
/// (view wallet_balance via service existing, tanpa query mentah),
/// text2 = jumlah dompet + tanggal update. Mask dihormati via amt().
Future<void> refreshWidgetBalanceSnapshot(String orgId) async {
  DiagLog.write('DIAG refreshWidgetBalanceSnapshot start');
  try {
    if (!widgetToday.value || orgId.isEmpty) return;
    var total = 0.0;
    var count = 0;
    try {
      final rows = await WalletService().balances(orgId);
      for (final b in rows) {
        total += b.balance;
      }
      count = rows.length;
    } catch (_) {
      return;
    }
    final today = _todayYmd();
    final text = '${tr('w_total')} ${amt(total)}';
    // Template milik Task 5 (`wg_balance_meta`: ID '{n} dompet · {d}' /
    // EN '{n} wallets · {d}'). Sementara kunci belum ada, tr() kembalikan
    // kunci itu sendiri (tak crash — pola aman yang sama).
    final text2 = tr('wg_balance_meta')
        .replaceFirst('{n}', '$count')
        .replaceFirst('{d}', today);
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!widgetToday.value) {
        try {
          await prefs.remove(widgetBalanceSnapshotKey);
        } catch (_) {}
        return;
      }
      await prefs.setString(
        widgetBalanceSnapshotKey,
        formatSnapshot(
          date: today,
          text: text,
          text2: text2,
          masked: maskAmounts.value,
        ),
      );
    } catch (_) {}
    DiagLog.write('DIAG refreshWidgetBalanceSnapshot done');
  } catch (_) {
    DiagLog.write('DIAG refreshWidgetBalanceSnapshot error');
  }
}

Future<void> clearTodaySnapshot() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    for (final k in _allSnapshotKeys) {
      try {
        await prefs.remove(k);
      } catch (_) {}
    }
  } catch (_) {}
}
