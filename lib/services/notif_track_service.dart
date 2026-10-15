import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:notification_listener_service/notification_listener_service.dart';
import 'package:notification_listener_service/notification_event.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ssr_space/services/error_reporter.dart';
import 'package:ssr_space/utils/diag_log.dart';
import 'package:ssr_space/services/auto_saved_notify.dart';
import 'package:ssr_space/services/budget_alert_notify.dart';
import 'package:ssr_space/services/notif_parse.dart';
import 'package:ssr_space/services/today_widget.dart';
import 'package:ssr_space/services/transfer_detect.dart';
import 'package:ssr_space/utils/strings.dart';
import 'package:ssr_space/services/plan_limits.dart';
import 'package:ssr_space/services/supabase_config.dart';
import 'package:ssr_space/services/transaction_service.dart';
import 'package:ssr_space/services/wallet_service.dart';

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
    return tr('svc_scan_unavail');
  }
  if (code == 'REBIND_ERROR' || code == 'RECONNECT_ERROR') {
    return tr('svc_rebind');
  }
  if (code == 'API_LEVEL') {
    return tr('svc_apilevel');
  }
  return tr('svc_scanfail').replaceFirst('{m}', message ?? code);
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
  if (!permissionGranted) return tr('svc_noperm');
  if (!serviceConnected) {
    return tr('svc_disconnected');
  }
  return tr('svc_connected');
}

/// Status baris recent saat insert transaksi ditolak server.
/// RATE_LIMITED = trigger rate limit auto-insert (migration_11).
/// QUOTA_EXCEEDED = trigger kuota paket (migration_17).
String saveErrorStatus(PostgrestException err) {
  if (err.message.contains('RATE_LIMITED')) {
    return tr('svc_rate');
  }
  if (err.message.contains('QUOTA_EXCEEDED')) {
    return tr('q_auto')
        .replaceFirst('{n}', '${PlanLimits.freeAutoPerMonth}');
  }
  // Mode bendahara: tulis member ditolak RLS — status jujur, tanpa retry.
  if (err.code == '42501') return tr('sp_only_treasurer');
  if (err.code == '23505') return tr('svc_dup');
  return tr('svc_savefail').replaceFirst('{c}', err.code ?? 'error');
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
    if (!Platform.isAndroid) return tr('svc_notandroid');
    if (!await permissionGranted()) return tr('svc_noperm');

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
      if (raw is! List) return tr('svc_scan_fail');
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
          ? tr('svc_scan_active_none')
          : tr('svc_scan_found').replaceFirst('{n}', '$seen');
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
      return tr('svc_scan_fail');
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

  /// Auto-gabung transfer: bila tx baru berpasangan out+in auto+auto
  /// (nominal sama, dompet beda, <=10 mnt), ubah kaki OUT jadi `transfer`
  /// dan hapus kaki IN. Fail-open: gagal/ragu -> null (dua baris + badge
  /// seperti biasa). Tak pernah melempar.
  static Future<TransferPair?> _tryAutoMerge(String orgId, String newId) async {
    try {
      final since =
          DateTime.now().toUtc().subtract(const Duration(minutes: 30));
      final txs = await TransactionService().listSince(orgId, since);
      final pair = pickAutoMerge(detectTransferPairs(txs), newId);
      if (pair == null) return null;
      final destId = pair.inTx.walletId ?? pair.inTx.toWalletId;
      if (destId == null || destId.isEmpty) return null;
      final base = (pair.outTx.note ?? '').trim();
      final mark = tr('nt_automerge');
      await TransactionService().update(
        id: pair.outTx.id,
        orgId: orgId,
        type: 'transfer',
        amount: pair.outTx.amount,
        walletId: pair.outTx.walletId,
        toWalletId: destId,
        category: pair.outTx.category,
        note: base.isEmpty ? mark : '$base • $mark',
        date: pair.outTx.date,
      );
      await TransactionService().delete(pair.inTx.id, orgId);
      return pair;
    } catch (err, st) {
      ErrorReporter.capture(err, st, context: 'auto_merge');
      return null;
    }
  }

  static Future<void> _onEvent(ServiceNotificationEvent e) async {
    DiagLog.write('DIAG notif event');
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
        n.status = tr('st_notwatched');
        _remember(n);
        return;
      }
      final prefs = await SharedPreferences.getInstance();
      if (!(prefs.getBool('track_master') ?? false)) {
        n.status = tr('st_masteroff');
        _remember(n);
        return;
      }
      if (!(prefs.getBool('track_${n.appLabel}') ?? true)) {
        n.status = tr('st_toggleoff').replaceFirst('{a}', n.appLabel ?? '');
        _remember(n);
        return;
      }
      if (SupabaseConfig.client.auth.currentSession == null) {
        n.status = tr('st_nologin');
        _remember(n);
        return;
      }
      final orgId = prefs.getString('active_org_id') ?? '';
      if (orgId.isEmpty) {
        n.status = tr('st_noorg');
        _remember(n);
        return;
      }
      if (n.amount == null || n.amount! <= 0 || n.type == null) {
        n.status = tr('st_unread');
        _remember(n);
        return;
      }
      if (isMerchantQrisPending(
        appLabel: n.appLabel!,
        title: title,
        content: content,
        type: n.type,
      )) {
        // QRIS merchant (GoPay): dana belum cair ke saldo saat notif
        // datang. Jangan insert (saldo jangan membengkak duluan);
        // user ketuk Simpan manual di recent saat dana benar masuk.
        n.status = tr('st_pending_settle');
        _remember(n);
        return;
      }
      try {
        // Gate kuota server (migration_17) + fallback lokal bila RPC
        // belum ada (user belum jalan migration_17) atau offline.
        if (!await canAutoTrackServer(orgId)) {
          n.status = tr('q_auto')
              .replaceFirst('{n}', '${PlanLimits.freeAutoPerMonth}');
          _remember(n);
          return;
        }
      } catch (_) {
        debugPrint('track: cek kuota gagal, lanjut');
      }
      final walletId = await resolveWalletId(orgId, n.appLabel!, prefs);
      if (walletId == null) {
        // Guard tanpa-dompet: jangan insert — transaksi null-wallet tidak
        // masuk saldo dompet dan bikin Home vs Dompet selisih diam-diam.
        // User petakan dompet di Pelacakan otomatis lalu Simpan manual
        // (forceSave tetap mengizinkan simpan sadar tanpa dompet).
        n.status = tr('st_need_wallet');
        _remember(n);
        return;
      }
      final category = prefs.getString(catPrefKey(n.appLabel!))?.trim();
      try {
        final txId = await TransactionService().add(
          orgId: orgId,
          type: n.type!,
          amount: n.amount!,
          walletId: walletId,
          category: (category == null || category.isEmpty) ? null : category,
          note: tr('nt_auto_from').replaceFirst('{a}', n.appLabel ?? ''),
          date: ymd(n.at),
          sourcePackage: pkg,
          sourceHash: notifHash(pkg, title, content, at: n.at),
        );
        n.status = tr('st_saved');
        // Alert budget baru (bila tembus): idempoten, fail-silent.
        unawaited(BudgetAlertNotify.check(orgId));
        // Snapshot + refresh widget home: fail-silent.
        unawaited(refreshBudgetWidgetSnapshot(orgId).catchError((_) {}));
        if (txId != null) {
          final pair = await _tryAutoMerge(orgId, txId);
          if (pair != null) {
            final outLabel =
                matchWatchedApp(pair.outTx.sourcePackage ?? '') ??
                    n.appLabel ??
                    pkg;
            await AutoSavedNotify.showSaved(
              txId: pair.outTx.id,
              type: 'transfer',
              amount: pair.amount,
              app: outLabel,
              appTo: matchWatchedApp(pair.inTx.sourcePackage ?? ''),
            );
          } else {
            await AutoSavedNotify.showSaved(
              txId: txId,
              type: n.type!,
              amount: n.amount!,
              app: n.appLabel ?? pkg,
            );
          }
        }
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
      DiagLog.error('DIAG notif_pipeline', err, st);
      debugPrint('track: $err');
    }
  }

  /// Simpan paksa. `forceType` dipakai bila classifier tidak yakin
  /// (type null), user pilih Masuk/Keluar di UI.
  static Future<String> forceSave(CapturedNotif n, {String? forceType}) async {
    final prefs = await SharedPreferences.getInstance();
    final orgId = prefs.getString('active_org_id') ?? '';
    if (orgId.isEmpty) return tr('st_noorg');
    if (SupabaseConfig.client.auth.currentSession == null) {
      return tr('st_nologin');
    }
    final type = forceType ?? n.type;
    if (n.amount == null || n.amount! <= 0 || type == null) {
      return tr('st_unread');
    }
    final label = n.appLabel ?? n.package;
    final walletId = await resolveWalletId(orgId, label, prefs);
    final category = prefs.getString(catPrefKey(label))?.trim();
    try {
      final txId = await TransactionService().add(
        orgId: orgId,
        type: type,
        amount: n.amount!,
        walletId: walletId,
        category: (category == null || category.isEmpty) ? null : category,
        note: tr('nt_auto_from').replaceFirst('{a}', label),
        date: ymd(n.at),
        sourcePackage: n.package,
        sourceHash: notifHash(n.package, n.title, n.content, at: n.at),
      );
      n.type = type;
      n.status = tr('st_saved');
      unawaited(BudgetAlertNotify.check(orgId));
      // Snapshot + refresh widget home: fail-silent.
      unawaited(refreshBudgetWidgetSnapshot(orgId).catchError((_) {}));
      if (txId != null) {
        await AutoSavedNotify.showSaved(
          txId: txId,
          type: type,
          amount: n.amount!,
          app: label,
        );
      }
      return tr('st_saved');
    } on PostgrestException catch (err) {
      ErrorReporter.capture(err, StackTrace.current, context: 'notif_force');
      final msg = saveErrorStatus(err);
      n.status = msg;
      return msg;
    } catch (err, st) {
      ErrorReporter.capture(err, st, context: 'notif_force');
      return tr('svc_savefail').replaceFirst('{c}', 'error');
    }
  }
}
