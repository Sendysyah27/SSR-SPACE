import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ssr_space/services/error_reporter.dart';
import 'package:ssr_space/utils/strings.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

// Pengingat tantangan hemat 30 hari: 1x sehari jam 20:00 selama 30 hari
// + perayaan milestone langsung (show-now dari layar, bukan terjadwal).
// Pola DueNotify: ID stabil, prefs lacak jadwal, fail-silent.
// Isi harian generik (angka kemarin tak diketahui saat jadwal dibuat).
class Save30Notify {
  static const String channelId = 'ssr_save30';
  static const String channelName = 'Tantangan hemat';
  static const String channelDesc =
      'Pengingat harian dan perayaan tantangan hemat 30 hari.';

  static const int _dailyBase = 7300;
  static const int _hour = 20;
  static const String _kIds = 'save30_notif_ids';

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _inited = false;

  static Future<void> _init() async {
    if (_inited) return;
    tzdata.initializeTimeZones();
    try {
      tz.setLocalLocation(
        tz.getLocation(
          zoneForOffsetHours(DateTime.now().timeZoneOffset.inHours),
        ),
      );
    } catch (e) {
      debugPrint('save30 zona gagal: $e');
    }
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

  static tz.TZDateTime _at20(DateTime day) =>
      tz.TZDateTime(tz.local, day.year, day.month, day.day, _hour);

  /// Jadwalkan ulang 30 hari dari [startYmd]. [active]=false = batalkan
  /// semua. Panggil saat start/stop + tiap app-start (silent).
  static Future<void> reschedule({
    required bool active,
    String startYmd = '',
  }) async {
    try {
      await _init();
      final prefs = await SharedPreferences.getInstance();
      final oldIds = prefs.getStringList(_kIds) ?? [];
      final wanted = <int, int>{};
      DateTime? start;
      if (active && startYmd.length >= 10) {
        start = DateTime.tryParse(startYmd.substring(0, 10));
      }
      if (start != null) {
        final s = start;
        for (var i = 0; i < 30; i++) {
          final at = _at20(DateTime(s.year, s.month, s.day + i));
          if (at.isBefore(tz.TZDateTime.now(tz.local))) continue;
          wanted[_dailyBase + 1 + i] = i + 1;
        }
      }
      for (final raw in oldIds) {
        final id = int.tryParse(raw);
        if (id == null || !wanted.containsKey(id)) {
          try {
            if (id != null) await _plugin.cancel(id: id);
          } catch (_) {}
        }
      }
      const details = NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          channelDescription: channelDesc,
          importance: Importance.high,
          priority: Priority.high,
        ),
      );
      for (final e in wanted.entries) {
        final s = start!;
        try {
          await _plugin.zonedSchedule(
            id: e.key,
            title: tr('sv30_remind_t').replaceFirst('{n}', '${e.value}'),
            body: tr('sv30_remind_b').replaceFirst('{n}', '${e.value}'),
            scheduledDate: _at20(
              DateTime(s.year, s.month, s.day + e.value - 1),
            ),
            notificationDetails: details,
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          );
        } catch (_) {}
      }
      await prefs.setStringList(
        _kIds,
        [for (final id in wanted.keys) '$id'],
      );
    } catch (err, st) {
      ErrorReporter.capture(err, st, context: 'save30_reschedule');
    }
  }

  /// Rayakan milestone sekarang (dari layar, fail-silent).
  static Future<void> celebrate(int milestone) async {
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
      await _plugin.show(
        _dailyBase + 90 + milestone,
        tr('sv30_mile_t'),
        tr('sv30_mile').replaceFirst('{n}', '$milestone'),
        details,
      );
    } catch (err, st) {
      ErrorReporter.capture(err, st, context: 'save30_celebrate');
    }
  }
}
