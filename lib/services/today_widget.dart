import 'package:shared_preferences/shared_preferences.dart';
import 'package:ssr_space/services/app_settings.dart';
import 'package:ssr_space/services/widget_snapshot.dart';
import 'package:ssr_space/utils/mask.dart';
import 'package:ssr_space/utils/strings.dart';

/// Penulis snapshot widget hari ini (P2 widget-qs-tile).
///
/// Provider native + QS tile hanya membaca string prefs `widget_snapshot`
/// (tanpa token, tanpa query). Ditulis saat Beranda dimuat dari surplus
/// HARI INI (masuk kurang keluar tanggal hari ini), ikut mask bila aktif.
/// Toggle mati menghapus snapshot lokal.
///
/// SENGAJA tanpa MethodChannel refresh (2.13.1 menambahkan channel
/// 'ssr_space/widget' + broadcast APPWIDGET_UPDATE tiap Beranda dimuat dan
/// mulai FC di HP user). Snapshot prefs-only ini fail-open via try-catch;
/// trigger gambar-ulang native = follow-up setelah stabil.
const _kSnapshot = 'widget_snapshot';

Future<void> refreshTodayWidget({
  required String date,
  required double surplus,
}) async {
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
        text: '${tr('wg_today')} $date · ${amt(surplus)}',
        masked: maskAmounts.value,
      ),
    );
  } catch (_) {}
}

Future<void> clearTodaySnapshot() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kSnapshot);
  } catch (_) {}
}
