import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ssr_space/services/supabase_config.dart';
import 'package:ssr_space/utils/strings.dart';

String? foregroundGate({
  required bool isAndroid,
  required bool masterOn,
  required bool hasSession,
}) {
  if (!isAndroid) return tr('fg_notandroid');
  if (!masterOn) return tr('fg_off');
  if (!hasSession) return tr('fg_nologin');
  return null;
}

@pragma('vm:entry-point')
void foregroundStartCallback() {
  FlutterForegroundTask.setTaskHandler(_PassiveTaskHandler());
}

/// Service hanya menjaga proses hidup; event notif tetap di stream plugin.
class _PassiveTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {}
}

class ForegroundTrack {
  static bool _inited = false;
  static const _serviceId = 256;
  static const _title = 'SSR SPACE aktif';
  static const _text = 'Memantau transaksi masuk';

  static void initOnce() {
    if (_inited || !Platform.isAndroid) return;
    FlutterForegroundTask.initCommunicationPort();
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'ssr_track',
        channelName: 'Pelacakan transaksi',
        channelDescription:
            'Notifikasi saat SSR SPACE memantau transaksi masuk.',
        channelImportance: NotificationChannelImportance.LOW,
        onlyAlertOnce: true,
        showWhen: false,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
        autoRunOnBoot: false,
        autoRunOnMyPackageReplaced: true,
        allowWakeLock: true,
      ),
    );
    _inited = true;
  }

  static Future<void> syncFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final gate = foregroundGate(
      isAndroid: Platform.isAndroid,
      masterOn: prefs.getBool('track_master') ?? false,
      hasSession: SupabaseConfig.client.auth.currentSession != null,
    );
    if (gate == null) {
      await start();
    } else {
      debugPrint('foreground skip: $gate');
      await stop();
    }
  }

  static Future<void> start() async {
    if (!Platform.isAndroid) return;
    initOnce();
    if (await FlutterForegroundTask.isRunningService) return;
    final perm = await FlutterForegroundTask.checkNotificationPermission();
    if (perm != NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }
    final res = await FlutterForegroundTask.startService(
      serviceId: _serviceId,
      serviceTypes: const [ForegroundServiceTypes.specialUse],
      notificationTitle: _title,
      notificationText: _text,
      callback: foregroundStartCallback,
    );
    if (res is ServiceRequestFailure) {
      debugPrint('foreground start gagal: ${res.error}');
    }
  }

  static Future<void> stop() async {
    if (!Platform.isAndroid) return;
    try {
      if (await FlutterForegroundTask.isRunningService) {
        await FlutterForegroundTask.stopService();
      }
    } catch (e) {
      // Menenggelamkan error: stop wajib tetap selesai supaya logout /
      // syncFromPrefs tak pernah batal karena plugin bermasalah.
      debugPrint('foreground stop gagal: $e');
    }
  }

  static Future<bool> get isRunning async {
    if (!Platform.isAndroid) return false;
    return FlutterForegroundTask.isRunningService;
  }

  /// Sematkan ringkasan koreksi instan di notif service (ketuk → buka app).
  static Future<void> pinNotice(String body) async {
    if (!Platform.isAndroid) return;
    try {
      if (!await FlutterForegroundTask.isRunningService) return;
      await FlutterForegroundTask.updateService(
        notificationTitle: _title,
        notificationText: tr('fg_correct').replaceFirst('{s}', body),
      );
    } catch (e) {
      debugPrint('foreground pin gagal: $e');
    }
  }

  /// Kembalikan teks notif service ke semula.
  static Future<void> clearNotice() async {
    if (!Platform.isAndroid) return;
    try {
      if (!await FlutterForegroundTask.isRunningService) return;
      await FlutterForegroundTask.updateService(
        notificationTitle: _title,
        notificationText: _text,
      );
    } catch (e) {
      debugPrint('foreground clear gagal: $e');
    }
  }
}
