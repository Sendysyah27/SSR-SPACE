import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ssr_space/services/error_reporter.dart';
import 'package:ssr_space/utils/mask.dart';
import 'package:ssr_space/utils/strings.dart';

/// Notifikasi sistem murni tiap transaksi tersimpan (auto + manual).
///
/// Tanpa popup, tanpa koreksi dari notif: ketuk hanya membuka app ke
/// detail read-only (via prefs `last_detail_tx` yang dibaca MainShell).
/// Koreksi tetap lewat jalur normal (ketuk baris Transaksi). Tak melempar.
class AutoSavedNotify {
  static const String channelId = 'ssr_auto_saved';
  static const String channelName = 'Transaksi tersimpan';
  static const String channelDesc =
      'Pemberitahuan tiap transaksi otomatis/manual tersimpan.';
  static const String lastDetailKey = 'last_detail_tx';

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
        final p = resp.payload ?? '';
        if (p.startsWith('open_detail:')) {
          try {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString(
              lastDetailKey,
              p.substring('open_detail:'.length),
            );
          } catch (_) {}
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

  static Future<void> showSaved({
    required String txId,
    required String type,
    required double amount,
    required String app,
    String? appTo,
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
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(lastDetailKey, txId);
      } catch (_) {}
      final body = savedBody(
        type: type,
        amount: amount,
        app: app,
        appTo: appTo,
      );
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
        title: tr('nt_saved_title'),
        body: body,
        notificationDetails: details,
        payload: 'open_detail:$txId',
      );
    } catch (err, st) {
      ErrorReporter.capture(err, st, context: 'auto_saved_notify');
    }
  }
}

/// Baris isi notif tersimpan, murni, bisa di-test.
/// Transfer menyebut asal ke tujuan; tanpa tujuan = satu baris biasa.
String savedBody({
  required String type,
  required double amount,
  required String app,
  String? appTo,
}) {
  final dir = type == 'in'
      ? tr('tx_in')
      : type == 'transfer'
          ? tr('tx_transfer')
          : tr('tx_out');
  if (type == 'transfer' && appTo != null && appTo.isNotEmpty && appTo != app) {
    return '$dir ${amt(amount)} • $app → $appTo';
  }
  return '$dir ${amt(amount)} • $app';
}

/// Id notifikasi stabil per transaksi (0..2^31-1), murni bisa di-test.
int autoSavedId(String txId) => txId.hashCode & 0x7fffffff;
