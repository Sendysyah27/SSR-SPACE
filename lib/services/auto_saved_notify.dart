import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:ssr_space/services/error_reporter.dart';

/// Notifikasi head-up cadangan tiap transaksi tersimpan (auto + manual).
///
/// Dipakai bila overlay bubble tak bisa tampil (popup dimatikan, tanpa
/// izin overlay, atau diblokir OEM diam-diam). Ketuk notifikasi membuka
/// app; sheet koreksi muncul sendiri via pending yang sudah dicatat
/// caller sebelum memanggil [show]. Tak pernah melempar.
class AutoSavedNotify {
  static const String channelId = 'ssr_auto_saved';
  static const String channelName = 'Transaksi tersimpan';
  static const String channelDesc =
      'Pemberitahuan tiap transaksi otomatis/manual tersimpan.';
  static const String payloadOpen = 'open_correct';

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

  static Future<void> show({
    required String txId,
    required String title,
    required String body,
  }) async {
    try {
      await _init();
      try {
        await _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.requestNotificationsPermission();
      } catch (_) {}
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
        id: autoSavedId(txId),
        title: title,
        body: body,
        notificationDetails: details,
        payload: payloadOpen,
      );
    } catch (err, st) {
      ErrorReporter.capture(err, st, context: 'auto_saved_notify');
    }
  }
}

/// Id notifikasi stabil per transaksi (0..2^31-1), murni bisa di-test.
int autoSavedId(String txId) => txId.hashCode & 0x7fffffff;
