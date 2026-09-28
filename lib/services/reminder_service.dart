import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:ssr_space/services/reminder_copy.dart';
import 'package:ssr_space/services/reminder_schedule.dart';
import 'package:ssr_space/utils/strings.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Pengingat harian, pembungkus tipis di atas flutter_local_notifications.
///
/// Seluruh hitungan jadwal milik reminder_schedule.dart; kelas ini hanya
/// init plugin, kanal, penjadwalan, dan pembatalan. Tanpa tulis Supabase.
class ReminderService {
  static const int notifId = 7001;
  static const int weeklyNotifId = 7002;
  static const String channelId = 'ssr_reminder';
  static const String channelName = 'Pengingat harian';
  static const String channelDesc =
      'Pengingat harian mencatat keuangan di SSR SPACE.';

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _inited = false;

  static Future<void> init() async {
    if (_inited) return;
    tzdata.initializeTimeZones();
    try {
      tz.setLocalLocation(
        tz.getLocation(
          zoneForOffsetHours(DateTime.now().timeZoneOffset.inHours),
        ),
      );
    } catch (e) {
      debugPrint('reminder zona gagal: $e');
    }
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);
    await _plugin.initialize(settings: settings);
    const channel = AndroidNotificationChannel(
      channelId,
      channelName,
      description: channelDesc,
      importance: Importance.defaultImportance,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);
    _inited = true;
  }

  static Future<void> scheduleDaily(int hour, int minute) async {
    await init();
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    try {
      await android?.requestNotificationsPermission();
    } catch (e) {
      debugPrint('reminder izin gagal: $e');
    }
    try {
      await android?.requestExactAlarmsPermission();
    } catch (e) {
      debugPrint('reminder alarm tepat gagal: $e');
    }
    final next = nextDaily(hour, minute, DateTime.now());
    final scheduled = tz.TZDateTime(
      tz.local,
      next.year,
      next.month,
      next.day,
      next.hour,
      next.minute,
    );
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDesc,
      ),
    );
    final body = tr(reminderKeyFor(next, hour));
    try {
      await _plugin.zonedSchedule(
        id: notifId,
        scheduledDate: scheduled,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        title: tr('st_reminder_on'),
        body: body,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (e) {
      debugPrint('reminder tepat gagal, coba longgar: $e');
      await _plugin.zonedSchedule(
        id: notifId,
        scheduledDate: scheduled,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        title: tr('st_reminder_on'),
        body: body,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    }
  }

  static Future<void> cancel() => _plugin.cancel(id: notifId);

  /// Pengingat mingguan: hari [weekday] (1 Senin .. 7 Minggu) pukul jam:menit.
  /// Id notifikasi terpisah (7002) agar tak saling menimpa harian.
  static Future<void> scheduleWeekly(int weekday, int hour, int minute) async {
    await init();
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    try {
      await android?.requestNotificationsPermission();
    } catch (e) {
      debugPrint('reminder izin gagal: $e');
    }
    try {
      await android?.requestExactAlarmsPermission();
    } catch (e) {
      debugPrint('reminder alarm tepat gagal: $e');
    }
    final wd = weekday.clamp(1, 7);
    final h = hour.clamp(0, 23);
    final m = minute.clamp(0, 59);
    final next = nextWeekly(wd, h, m, DateTime.now());
    final scheduled = tz.TZDateTime(
      tz.local,
      next.year,
      next.month,
      next.day,
      next.hour,
      next.minute,
    );
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDesc,
      ),
    );
    final body = tr(reminderKeyFor(next, h));
    try {
      await _plugin.zonedSchedule(
        id: weeklyNotifId,
        scheduledDate: scheduled,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        title: tr('st_weekly_on'),
        body: body,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      );
    } catch (e) {
      debugPrint('reminder tepat gagal, coba longgar: $e');
      await _plugin.zonedSchedule(
        id: weeklyNotifId,
        scheduledDate: scheduled,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        title: tr('st_weekly_on'),
        body: body,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      );
    }
  }

  static Future<void> cancelWeekly() => _plugin.cancel(id: weeklyNotifId);
}
