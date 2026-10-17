import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:ssr_space/services/error_reporter.dart';
import 'package:ssr_space/utils/strings.dart';

// Notifikasi pencapaian (badge baru), satu notif per badge. Pola
// Save30Notify: channel + ID stabil + init sekali + fail-silent.
// Dedupe lintas-device diurus server lewat ack_achievements, bukan di sini.
class AchievementNotify {
  static const String channelId = 'ssr_achievement';
  static const String channelName = 'Pencapaian';
  static const String channelDesc = 'Pencapaian dan badge baru.';

  static const int _base = 7400;

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

  /// Tampilkan satu notifikasi per id badge baru. Fail-silent.
  static Future<void> showNew(List<String> badgeIds) async {
    if (badgeIds.isEmpty) return;
    try {
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
      for (var i = 0; i < badgeIds.length; i++) {
        final id = badgeIds[i];
        await _plugin.show(
          id: _base + i,
          title: tr('b_${id}_t'),
          body: tr('b_${id}_d'),
          notificationDetails: details,
        );
      }
    } catch (err, st) {
      ErrorReporter.capture(err, st, context: 'achievement_notify');
    }
  }
}
