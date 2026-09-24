import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:notification_listener_service/notification_listener_service.dart';
import 'package:notification_listener_service/notification_event.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ssr_space/core/saas/notif_parse.dart';
import 'package:ssr_space/core/saas/supabase_config.dart';
import 'package:ssr_space/core/saas/transaction_service.dart';

class CapturedNotif {
  final String package;
  final String? appLabel;
  final String title;
  final String content;
  final DateTime at;
  CapturedNotif(this.package, this.appLabel, this.title, this.content) : at = DateTime.now();
}

class NotifTrack {
  static bool _started = false;
  static final List<CapturedNotif> recent = [];
  static const ownPackage = 'com.ssr.space.ssr_space';

  static Future<bool> permissionGranted() async {
    if (!Platform.isAndroid) return false;
    try {
      return await NotificationListenerService.isPermissionGranted();
    } catch (_) {
      return false;
    }
  }

  static Future<void> requestPermission() async {
    try {
      await NotificationListenerService.requestPermission();
    } catch (_) {}
  }

  static Future<void> ensureListening() async {
    if (_started || !Platform.isAndroid) return;
    _started = true;
    try {
      NotificationListenerService.notificationsStream.listen(_onEvent, onError: (_) {});
    } catch (_) {
      _started = false;
    }
  }

  static Future<void> refreshActive() async {
    if (!Platform.isAndroid) return;
    try {
      final active = await NotificationListenerService.getActiveNotifications();
      for (final e in active) {
        await _onEvent(e);
      }
    } catch (_) {}
  }

  static Future<void> _onEvent(ServiceNotificationEvent e) async {
    try {
      if (e.hasRemoved ?? false) return;
      final pkg = (e.packageName ?? '').trim();
      if (pkg.isEmpty || pkg == ownPackage) return;
      final title = (e.title ?? '').trim();
      final content = (e.content ?? '').trim();
      if (title.isEmpty && content.isEmpty) return;
      final label = matchWatchedApp(pkg);
      recent.insert(0, CapturedNotif(pkg, label, title, content));
      if (recent.length > 20) recent.removeLast();
      if (label == null) return;
      final prefs = await SharedPreferences.getInstance();
      if (!(prefs.getBool('track_master') ?? false)) return;
      if (!(prefs.getBool('track_$label') ?? true)) return;
      if (SupabaseConfig.client.auth.currentSession == null) return;
      final orgId = prefs.getString('active_org_id') ?? '';
      if (orgId.isEmpty) return;
      final text = '$title $content';
      final amount = parseNotifAmount(text);
      final type = classifyNotif(text);
      if (amount == null || amount <= 0 || type == null) return;
      final hash = notifHash(pkg, title, content);
      final code = await TransactionService().mintCode(orgId);
      await TransactionService().add(
        orgId: orgId,
        type: type,
        amount: amount,
        category: label,
        note: 'Otomatis dari $label',
        code: code,
        sourcePackage: pkg,
        sourceHash: hash,
      );
    } on PostgrestException catch (err) {
      if (err.code != '23505') debugPrint('track: $err');
    } catch (err) {
      debugPrint('track: $err');
    }
  }
}
