import 'package:shared_preferences/shared_preferences.dart';
import 'package:ssr_space/services/app_settings.dart';
import 'package:ssr_space/services/budget_service.dart';
import 'package:ssr_space/services/category_meta.dart';
import 'package:ssr_space/services/month.dart';
import 'package:ssr_space/services/saving.dart';
import 'package:ssr_space/services/transaction_service.dart';
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

Future<void> refreshTodayWidget({
  required String date,
  required String text,
  String text2 = '',
}) async {
  DiagLog.write('DIAG refreshTodayWidget start');
  try {
    final prefs = await SharedPreferences.getInstance();
    if (!widgetToday.value) {
      await prefs.remove(_kSnapshot);
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

/// Tulis snapshot + minta gambar ulang, hitung dari server.
/// Dipakai jalur simpan yang tak memegang data (sheet manual, auto-track,
/// forceSave, budget). Fire-and-forget oleh pemanggil, fail-open total.
Future<void> refreshBudgetWidgetSnapshot(String orgId) async {
  try {
    if (!widgetToday.value || orgId.isEmpty) return;
    final month = currentMonth();
    final txs = await TransactionService().listMonth(orgId, month);
    final limits = await fetchBudgetLimits(orgId);
    final now = DateTime.now();
    final today =
        '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
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
    for (final b in limits) {
      if (isSavingCategory(b.category) || b.limit <= 0) continue;
      hasBudget = true;
      left += b.limit - (spent[b.category] ?? 0);
    }
    await refreshTodayWidget(
      date: today,
      text: tr('wg_out_today').replaceFirst('{m}', amt(todayOut)),
      text2: hasBudget
          ? tr('wg_budget_left').replaceFirst('{m}', amt(left))
          : '',
    );
    await requestWidgetRefresh();
  } catch (_) {}
}

Future<void> clearTodaySnapshot() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kSnapshot);
  } catch (_) {}
}
