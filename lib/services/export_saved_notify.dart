import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:share_plus/share_plus.dart';
import 'package:ssr_space/services/error_reporter.dart';
import 'package:ssr_space/utils/strings.dart';

/// Notifikasi "file tersimpan" tiap ekspor Laporan selesai.
///
/// Ketuk badan = buka app saja. Tombol aksi [Bagikan] = share sheet file
/// (butuh app foreground, jadi aksi dijalankan setelah ketuk membuka app;
/// tanpa foreground Android tak mengizinkan share sheet: batas jujur).
/// Tak melempar.
class ExportSavedNotify {
  static const String channelId = 'ssr_export_saved';
  static const String channelName = 'Ekspor tersimpan';
  static const String channelDesc =
      'Pemberitahuan tiap file laporan selesai disimpan.';
  static const String actionShare = 'share';

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _inited = false;

  static Future<void> _init() async {
    if (_inited) return;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);
    await _plugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: (resp) async {
        try {
          if (resp.actionId == actionShare) {
            final p = resp.payload ?? '';
            if (p.startsWith('share_file:')) {
              final path = p.substring('share_file:'.length);
              if (path.isNotEmpty) {
                await Share.shareXFiles([XFile(path)]);
              }
            }
          }
        } catch (err, st) {
          ErrorReporter.capture(err, st, context: 'export_saved_share');
        }
      },
    );
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

  static Future<void> showExportSaved({
    required String filePath,
    required String fileName,
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
          actions: [AndroidNotificationAction(actionShare, tr('exp_share'))],
        ),
      );
      await _plugin.show(
        id: filePath.hashCode & 0x7fffffff,
        title: tr('exp_saved_title'),
        body: tr('exp_saved_body').replaceFirst('{f}', fileName),
        notificationDetails: details,
        payload: 'share_file:$filePath',
      );
    } catch (err, st) {
      ErrorReporter.capture(err, st, context: 'export_saved_notify');
    }
  }
}
