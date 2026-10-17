import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ssr_space/services/announcement_service.dart';
import 'package:ssr_space/services/error_reporter.dart';
import 'package:ssr_space/utils/strings.dart';

// Notifikasi pengumuman baru: satu notif per pengumuman aktif yang belum
// pernah dinotifikasi di device ini. Dedupe device-local lewat prefs
// `ann_seen_notif_ids` (cap). Pola AchievementNotify: channel + ID stabil +
// init sekali + fail-silent. TIDAK memanggil ackAnnouncements — badge tetap
// sampai user membuka layar Pengumuman.
class AnnouncementNotify {
  static const String channelId = 'ssr_announcement';
  static const String channelName = 'Pengumuman';
  static const String channelDesc = 'Pengumuman dan kabar terbaru aplikasi.';

  static const int _base = 7500;
  static const String _kSeen = 'ann_seen_notif_ids';
  static const int _capSeen = 200;

  /// Id notifikasi STABIL per slug (deterministik, pola DueNotify).
  static int _idFor(String id) => _base + (id.hashCode.abs() % 900);

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

  /// Tampilkan notif untuk pengumuman aktif yang belum pernah dinotifikasi.
  /// Fail-silent: error apa pun dicatat, tak pernah throw.
  static Future<void> checkAndNotify() async {
    try {
      final list = await fetchAnnouncements();
      if (list.isEmpty) return;
      final prefs = await SharedPreferences.getInstance();
      final seen = (prefs.getStringList(_kSeen) ?? const <String>[]).toSet();
      final fresh = [
        for (final a in list)
          if (!seen.contains(a.id)) a.id,
      ];
      if (fresh.isEmpty) return;
      await _init();
      const details = NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          channelDescription: channelDesc,
          importance: Importance.high,
          priority: Priority.high,
        ),
      );
      for (final id in fresh) {
        await _plugin.show(
          id: _idFor(id),
          title: tr('an_notif_title'),
          body: tr('an_notif_body'),
          notificationDetails: details,
        );
        seen.add(id);
      }
      final all = seen.toList();
      final capped = all.length > _capSeen
          ? all.sublist(all.length - _capSeen)
          : all;
      await prefs.setStringList(_kSeen, capped);
    } catch (err, st) {
      await ErrorReporter.capture(err, st, context: 'announcement_notify');
    }
  }
}
