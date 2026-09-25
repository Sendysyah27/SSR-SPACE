import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:notification_listener_service/notification_listener_service.dart';
import 'package:notification_listener_service/notification_event.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ssr_space/core/saas/error_reporter.dart';
import 'package:ssr_space/core/saas/notif_parse.dart';
import 'package:ssr_space/core/saas/supabase_config.dart';
import 'package:ssr_space/core/saas/transaction_service.dart';
import 'package:ssr_space/core/saas/wallet_service.dart';

/// Channel mentah plugin: API `isServiceConnected` / `reconnectService` /
/// `forceRequestRebind` / `getActiveNotifications` TIDAK diekspose ke Dart API
/// pub.dev, hanya ke MethodChannel.
const MethodChannel nlsChannel = MethodChannel(
  'x-slayer/notifications_channel',
);

/// Status scan dari kode error MethodChannel: jangan palsu jadi
/// “tidak ada notif” bila service memang mati.
String scanErrorStatus(String code, {String? message}) {
  if (code == 'ServiceUnavailable') {
    return 'Service listener tidak nyambung. Izin aktif tapi service mati.';
  }
  if (code == 'REBIND_ERROR' || code == 'RECONNECT_ERROR') {
    return 'Gagal sambung ulang service listener';
  }
  if (code == 'API_LEVEL') {
    return 'Perangkat terlalu lama untuk sambung ulang otomatis';
  }
  return 'Gagal memindai: ${message ?? code}';
}

/// Pilih waktu notif: `postTime` plugin bila valid, selain itu `fallback`.
DateTime eventTime(int timestampMs, {DateTime? fallback}) {
  if (timestampMs > 0) {
    return DateTime.fromMillisecondsSinceEpoch(timestampMs);
  }
  return fallback ?? DateTime.now();
}

/// Label baris status di UI Pelacakan otomatis.
String connectionLabel({
  required bool permissionGranted,
  required bool serviceConnected,
}) {
  if (!permissionGranted) return 'Izin baca notifikasi belum aktif';
  if (!serviceConnected) {
    return 'Izin aktif, service terputus. Pindai untuk sambung ulang.';
  }
  return 'Service terhubung';
}

/// Status baris recent saat insert transaksi ditolak server.
/// RATE_LIMITED = trigger rate limit auto-insert (migration_11).
String saveErrorStatus(PostgrestException err) {
  if (err.message.contains('RATE_LIMITED')) {
    return 'Dibatasi, terlalu banyak. Coba lagi.';
  }
  if (err.code == '23505') return 'Sudah pernah dicatat';
  return 'Gagal simpan: ${err.code}';
}

class CapturedNotif {
  final String package;
  final String? appLabel;
  final String title;
  final String content;
  final DateTime at;
  final double? amount;
  String? type;
  String? status;
  CapturedNotif(
    this.package,
    this.appLabel,
    this.title,
    this.content, {
    DateTime? at,
  }) : at = at ?? DateTime.now(),
       amount = parseNotifAmount('$title $content'),
       type = classifyNotif('$title $content');
}

class NotifTrack {
  static bool _started = false;
  static StreamSubscription<ServiceNotificationEvent>? _sub;
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

  /// Service NotificationListener benar-benar bound? (bukan sekadar izin OS)
  static Future<bool> isServiceConnected() async {
    if (!Platform.isAndroid) return false;
    try {
      final ok = await nlsChannel.invokeMethod('isServiceConnected');
      return ok == true;
    } catch (_) {
      return false;
    }
  }

  /// Paksa rebind + toggle component agar system bind ulang listener.
  static Future<void> reconnectService() async {
    if (!Platform.isAndroid) return;
    try {
      await nlsChannel.invokeMethod('forceRequestRebind');
    } catch (err) {
      debugPrint('rebind: $err');
    }
    try {
      await nlsChannel.invokeMethod('reconnectService');
    } catch (err) {
      debugPrint('reconnect: $err');
    }
  }

  static Future<void> requestPermission() async {
    try {
      await NotificationListenerService.requestPermission();
    } catch (_) {}
    await ensureListening(force: true);
  }

  /// (Re)subscribe stream. Aman dipanggil ulang, subscription lama dibatalkan
  /// bila handle sudah basi (mis. setelah grant izin / resume).
  static Future<void> ensureListening({bool force = false}) async {
    if (!Platform.isAndroid) return;
    if (_started && !force) return;
    try {
      await _sub?.cancel();
    } catch (_) {}
    _sub = null;
    _started = false;
    try {
      _sub = NotificationListenerService.notificationsStream.listen(
        _onEvent,
        onError: (Object err) {
          debugPrint('track stream error: $err');
          _started = false;
        },
        onDone: () {
          _started = false;
        },
      );
      _started = true;
      unawaited(_ensureNativeConnected());
    } catch (err) {
      debugPrint('track listen gagal: $err');
      _started = false;
    }
  }

  /// Izin boleh aktif tapi service unbound (OEM kill) → stream + scan mati.
  static Future<void> _ensureNativeConnected() async {
    try {
      if (!await permissionGranted()) return;
      if (await isServiceConnected()) return;
      await reconnectService();
    } catch (err) {
      debugPrint('ensure native: $err');
    }
  }

  static bool get isListening => _started;

  /// Scan notifikasi yang masih aktif di shade. Return status singkat
  /// untuk UI, bedakan “service mati” vs “shade kosong”.
  static Future<String> refreshActive() async {
    if (!Platform.isAndroid) return 'Bukan Android';
    if (!await permissionGranted()) return 'Izin baca notifikasi belum aktif';

    if (!await isServiceConnected()) {
      await reconnectService();
      for (var i = 0; i < 3; i++) {
        await Future.delayed(const Duration(milliseconds: 700));
        if (await isServiceConnected()) break;
      }
      if (!await isServiceConnected()) {
        return scanErrorStatus('ServiceUnavailable');
      }
    }

    try {
      final dynamic raw = await nlsChannel.invokeMethod(
        'getActiveNotifications',
      );
      if (raw is! List) return 'Gagal memindai notifikasi aktif';
      var seen = 0;
      for (final item in raw) {
        if (item is! Map) continue;
        seen++;
        await _onEvent(_eventFromActiveMap(item));
      }
      if (seen == 0 && !await isServiceConnected()) {
        return scanErrorStatus('ServiceUnavailable');
      }
      return seen == 0
          ? 'Tidak ada notifikasi aktif di shade'
          : 'Memindai $seen notifikasi aktif';
    } on PlatformException catch (err) {
      if (!await isServiceConnected()) {
        return scanErrorStatus('ServiceUnavailable');
      }
      return scanErrorStatus(err.code, message: err.message);
    } catch (err) {
      debugPrint('refreshActive: $err');
      if (!await isServiceConnected()) {
        return scanErrorStatus('ServiceUnavailable');
      }
      return 'Gagal memindai notifikasi aktif';
    }
  }

  /// Map hasil `getActiveNotificationData` (Java) → event Dart.
  /// Jangan pakai `ServiceNotificationEvent.fromMap` plugin: field
  /// `haveExtraPicture` tidak diisi native → TypeError non-nullable bool.
  static ServiceNotificationEvent _eventFromActiveMap(
    Map<dynamic, dynamic> raw,
  ) {
    String s(Object? v) => v?.toString() ?? '';
    return ServiceNotificationEvent(
      id: (raw['id'] as num?)?.toInt() ?? -1,
      title: s(raw['title']),
      canReply: false,
      haveExtraPicture: false,
      hasRemoved: false,
      packageName: s(raw['packageName']),
      content: s(raw['content']),
      onGoing: raw['onGoing'] == true,
      timestamp: (raw['postTime'] as num?)?.toInt() ?? 0,
      appIcon: null,
      extrasPicture: null,
      largeIcon: null,
    );
  }

  static void _remember(CapturedNotif n) {
    recent.removeWhere(
      (e) =>
          e.package == n.package &&
          e.title == n.title &&
          e.content == n.content,
    );
    recent.insert(0, n);
    if (recent.length > 20) recent.removeLast();
  }

  /// Pref key: wallet yang menerima transaksi dari app ini.
  static String walletPrefKey(String label) => 'track_wallet_$label';

  /// Pref key: kategori belanja (opsional), bukan nama app.
  static String catPrefKey(String label) => 'track_cat_$label';

  static Future<String?> resolveWalletId(
    String orgId,
    String label,
    SharedPreferences prefs,
  ) async {
    final mapped = prefs.getString(walletPrefKey(label));
    if (mapped != null && mapped.isNotEmpty) return mapped;
    try {
      final wallets = await WalletService().list(orgId);
      final target = label.toLowerCase();
      for (final w in wallets) {
        final n = w.name.toLowerCase();
        if (n == target || n.contains(target)) return w.id;
      }
      final aliases = <String, List<String>>{
        'mybca': ['bca'],
        'livin mandiri': ['mandiri'],
        'blu': ['blu', 'bca digital'],
        'gopay': ['gopay', 'gojek'],
        'shopeepay': ['shopee'],
      };
      for (final keys in aliases[label.toLowerCase()] ?? const <String>[]) {
        for (final w in wallets) {
          if (w.name.toLowerCase().contains(keys)) return w.id;
        }
      }
    } catch (_) {}
    return null;
  }

  static Future<void> _onEvent(ServiceNotificationEvent e) async {
    try {
      if (e.hasRemoved) return;
      final pkg = e.packageName.trim();
      if (pkg.isEmpty || pkg == ownPackage) return;
      final title = e.title.trim();
      final content = e.content.trim();
      if (title.isEmpty && content.isEmpty) return;
      final n = CapturedNotif(
        pkg,
        matchWatchedApp(pkg),
        title,
        content,
        at: eventTime(e.timestamp),
      );
      if (n.appLabel == null) {
        n.status = 'Bukan app terpantau';
        _remember(n);
        return;
      }
      final prefs = await SharedPreferences.getInstance();
      if (!(prefs.getBool('track_master') ?? false)) {
        n.status = 'Master pelacakan mati';
        _remember(n);
        return;
      }
      if (!(prefs.getBool('track_${n.appLabel}') ?? true)) {
        n.status = 'Toggle ${n.appLabel} mati';
        _remember(n);
        return;
      }
      if (SupabaseConfig.client.auth.currentSession == null) {
        n.status = 'Belum masuk di aplikasi';
        _remember(n);
        return;
      }
      final orgId = prefs.getString('active_org_id') ?? '';
      if (orgId.isEmpty) {
        n.status = 'Workspace belum dipilih';
        _remember(n);
        return;
      }
      if (n.amount == null || n.amount! <= 0 || n.type == null) {
        n.status = 'Nominal atau jenis tidak terbaca';
        _remember(n);
        return;
      }
      final walletId = await resolveWalletId(orgId, n.appLabel!, prefs);
      final category = prefs.getString(catPrefKey(n.appLabel!))?.trim();
      try {
        await TransactionService().add(
          orgId: orgId,
          type: n.type!,
          amount: n.amount!,
          walletId: walletId,
          category: (category == null || category.isEmpty) ? null : category,
          note: 'Otomatis dari ${n.appLabel}',
          date: ymd(n.at),
          sourcePackage: pkg,
          sourceHash: notifHash(pkg, title, content, at: n.at),
        );
        n.status = walletId == null
            ? 'Tersimpan (dompet belum cocok)'
            : 'Tersimpan';
      } on PostgrestException catch (err) {
        ErrorReporter.capture(
          err,
          StackTrace.current,
          context: 'notif_pipeline',
        );
        n.status = saveErrorStatus(err);
      }
      _remember(n);
    } catch (err, st) {
      ErrorReporter.capture(err, st, context: 'notif_pipeline');
      debugPrint('track: $err');
    }
  }

  /// Simpan paksa. `forceType` dipakai bila classifier tidak yakin
  /// (type null), user pilih Masuk/Keluar di UI.
  static Future<String> forceSave(CapturedNotif n, {String? forceType}) async {
    final prefs = await SharedPreferences.getInstance();
    final orgId = prefs.getString('active_org_id') ?? '';
    if (orgId.isEmpty) return 'Workspace belum dipilih';
    if (SupabaseConfig.client.auth.currentSession == null) {
      return 'Belum masuk di aplikasi';
    }
    final type = forceType ?? n.type;
    if (n.amount == null || n.amount! <= 0 || type == null) {
      return 'Nominal atau jenis tidak terbaca';
    }
    final label = n.appLabel ?? n.package;
    final walletId = await resolveWalletId(orgId, label, prefs);
    final category = prefs.getString(catPrefKey(label))?.trim();
    try {
      await TransactionService().add(
        orgId: orgId,
        type: type,
        amount: n.amount!,
        walletId: walletId,
        category: (category == null || category.isEmpty) ? null : category,
        note: 'Otomatis dari $label',
        date: ymd(n.at),
        sourcePackage: n.package,
        sourceHash: notifHash(n.package, n.title, n.content, at: n.at),
      );
      n.type = type;
      n.status = 'Tersimpan';
      return 'Tersimpan';
    } on PostgrestException catch (err) {
      ErrorReporter.capture(err, StackTrace.current, context: 'notif_force');
      final msg = saveErrorStatus(err);
      n.status = msg;
      return msg;
    } catch (err, st) {
      ErrorReporter.capture(err, st, context: 'notif_force');
      return 'Gagal simpan. Coba lagi.';
    }
  }
}
