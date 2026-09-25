import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ssr_space/core/app_info.dart';
import 'package:ssr_space/core/saas/supabase_config.dart';

/// Monitoring error in-house (Fase 2). Hanya kirim message/stack/context
/// + versi: nominal, note, dan isi notifikasi TIDAK PERNAH ikut (tanpa PII).
/// Gagal upload = drop senyap; monitoring tidak boleh memicu error baru.
class ErrorReporter {
  static const int maxPerHour = 20;
  static const Duration dedupeWindow = Duration(minutes: 60);
  static const int maxMessage = 500;
  static const int maxStack = 4000;

  static final Map<String, DateTime> _seen = {};
  static int _sentThisHour = 0;
  static DateTime _hourStart = DateTime.now();

  /// Pasang global handler. Dipanggil sekali di main().
  static void init() {
    FlutterError.onError = (details) {
      capture(
        details.exception,
        details.stack ?? StackTrace.empty,
        context: 'flutter_framework',
      );
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      capture(error, stack, context: 'uncaught');
      return true; // sudah ditangani, jangan rethrow ke platform
    };
  }

  /// Catat satu event. Aman dipanggil dari mana pun; semua kegagalan ditelan.
  static Future<void> capture(
    Object error,
    StackTrace stack, {
    String? context,
  }) async {
    try {
      final now = DateTime.now();
      final message = error.toString();
      if (!admit('${context ?? '-'}|$message', now)) return;
      final prefs = await SharedPreferences.getInstance();
      final client = SupabaseConfig.client;
      await client.from('client_errors').insert({
        ...payload(
          message: message,
          stack: stack.toString(),
          context: context,
        ),
        'user_id': client.auth.currentUser?.id,
        'org_id': prefs.getString('active_org_id'),
      });
    } catch (_) {
      // drop senyap
    }
  }

  /// Gerbang anti-flood: dedupe per signature/jam + cap per jam.
  @visibleForTesting
  static bool admit(String signature, DateTime now) {
    final last = _seen[signature];
    if (last != null && now.difference(last) < dedupeWindow) return false;
    if (now.difference(_hourStart) >= const Duration(hours: 1)) {
      _hourStart = now;
      _sentThisHour = 0;
    }
    if (_sentThisHour >= maxPerHour) return false;
    _seen[signature] = now;
    _sentThisHour++;
    return true;
  }

  /// Body insert `client_errors` (tanpa user/org, diisi capture).
  @visibleForTesting
  static Map<String, dynamic> payload({
    required String message,
    String? stack,
    String? context,
  }) {
    return {
      'message': _clip(message, maxMessage),
      'stack': stack == null ? null : _clip(stack, maxStack),
      'context': context,
      'app_version': AppInfo.version,
    };
  }

  static String _clip(String s, int max) =>
      s.length <= max ? s : s.substring(0, max);

  @visibleForTesting
  static void reset() {
    _seen.clear();
    _sentThisHour = 0;
    _hourStart = DateTime.now();
  }
}
