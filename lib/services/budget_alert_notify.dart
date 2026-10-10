import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ssr_space/services/budget_alerts.dart';
import 'package:ssr_space/services/error_reporter.dart';
import 'package:ssr_space/services/month.dart';
import 'package:ssr_space/utils/strings.dart';

/// Kunci tampil per alert: bulan|kategori|level. Anti-spam 1x per
/// kategori per periode — server dedup baris, prefs dedup notif.
String alertNotifyKey(String month, String category, String level) =>
    '$month|${category.trim()}|$level';

String _baNotifiedKey(String orgId, String month) =>
    'ba_notified_${orgId}_$month';

/// Maks kunci tersimpan per org-bulan (cukup untuk puluhan kategori).
const maxNotifiedKeys = 60;

/// Saring baris yang belum pernah dinotif. Murni (testable).
List<Map<String, dynamic>> unseenAlertRows(
  List<Map<String, dynamic>> rows,
  Set<String> shown,
) {
  final out = <Map<String, dynamic>>[];
  for (final r in rows) {
    final k = alertNotifyKey(
      (r['month'] ?? '').toString(),
      (r['category'] ?? '').toString(),
      (r['level'] ?? '').toString(),
    );
    if (!shown.contains(k)) out.add(r);
  }
  return out;
}

/// Notifikasi heads-up tiap alert budget baru (Batch 10 Sprint).
/// Fail-silent total: izin ditolak/offline/error = diam (banner in-app
/// tetap jalan). Idempoten: panggil dari banyak titik sepuasnya.
class BudgetAlertNotify {
  static const String channelId = 'ssr_budget';
  static const String channelName = 'Peringatan budget';
  static const String channelDesc =
      'Pemberitahuan saat belanja menyentuh batas budget.';
  static const int singleId = 8002;
  static const int multiId = 8001;

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _inited = false;

  static Future<void> _init() async {
    if (_inited) return;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);
    await _plugin.initialize(settings: settings);
    const channel = AndroidNotificationChannel(
      channelId,
      channelName,
      description: channelDesc,
      importance: Importance.high,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);
    _inited = true;
  }

  /// Cek alert bulan berjalan dan bunyikan yang baru saja.
  static Future<void> check(String orgId) async {
    try {
      if (orgId.isEmpty) return;
      final month = currentMonth();
      final rows = await fetchAlerts(orgId, month);
      if (rows.isEmpty) return;
      final prefs = await SharedPreferences.getInstance();
      final key = _baNotifiedKey(orgId, month);
      final shown = Set<String>.of(prefs.getStringList(key) ?? []);
      final unseen = unseenAlertRows(rows, shown);
      if (unseen.isEmpty) return;
      await _init();
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      try {
        // Izin sunyi: ditolak = diam (tanpa dialog, tanpa error).
        if (await android?.areNotificationsEnabled() == false) return;
      } catch (_) {}
      if (unseen.length == 1) {
        await _showSingle(unseen.first);
      } else {
        await _showMulti(unseen.length);
      }
      shown.addAll([
        for (final r in unseen)
          alertNotifyKey(
            (r['month'] ?? '').toString(),
            (r['category'] ?? '').toString(),
            (r['level'] ?? '').toString(),
          ),
      ]);
      final trimmed = shown.toList();
      if (trimmed.length > maxNotifiedKeys) {
        trimmed.removeRange(0, trimmed.length - maxNotifiedKeys);
      }
      try {
        await prefs.setStringList(key, trimmed);
      } catch (_) {}
    } catch (err, st) {
      ErrorReporter.capture(err, st, context: 'budget_alert_notify');
    }
  }

  static Future<void> _showSingle(Map<String, dynamic> r) async {
    final breach = (r['level'] ?? '').toString() == 'breach';
    // Isi sama dengan label banner (satu sumber kebenaran UX).
    final body = alertLabel(r);
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDesc,
        importance: Importance.high,
        priority: Priority.high,
        styleInformation: BigTextStyleInformation(body),
      ),
    );
    await _plugin.show(
      id: singleId,
      title: tr(breach ? 'ba_n_breach_t' : 'ba_n_warn_t'),
      body: body,
      notificationDetails: details,
    );
  }

  static Future<void> _showMulti(int n) async {
    final body = tr('ba_n_multi_s').replaceFirst('{n}', '$n');
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDesc,
        importance: Importance.high,
        priority: Priority.high,
        styleInformation: BigTextStyleInformation(body),
      ),
    );
    await _plugin.show(
      id: multiId,
      title: tr('ba_n_multi_t'),
      body: body,
      notificationDetails: details,
    );
  }
}
