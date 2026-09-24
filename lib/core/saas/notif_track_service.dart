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
import 'package:ssr_space/core/saas/wallet_service.dart';

class CapturedNotif {
  final String package;
  final String? appLabel;
  final String title;
  final String content;
  final DateTime at;
  final double? amount;
  final String? type;
  String? status;
  CapturedNotif(this.package, this.appLabel, this.title, this.content, {DateTime? at})
      : at = at ?? DateTime.now(),
        amount = parseNotifAmount('$title $content'),
        type = classifyNotif('$title $content');
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

  static void _remember(CapturedNotif n) {
    recent.removeWhere((e) =>
        e.package == n.package && e.title == n.title && e.content == n.content);
    recent.insert(0, n);
    if (recent.length > 20) recent.removeLast();
  }

  /// Pref key: wallet yang menerima transaksi dari app ini.
  static String walletPrefKey(String label) => 'track_wallet_$label';

  /// Pref key: kategori belanja (opsional), bukan nama app.
  static String catPrefKey(String label) => 'track_cat_$label';

  static Future<String?> resolveWalletId(String orgId, String label, SharedPreferences prefs) async {
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
      if (e.hasRemoved ?? false) return;
      final pkg = (e.packageName ?? '').trim();
      if (pkg.isEmpty || pkg == ownPackage) return;
      final title = (e.title ?? '').trim();
      final content = (e.content ?? '').trim();
      if (title.isEmpty && content.isEmpty) return;
      final n = CapturedNotif(pkg, matchWatchedApp(pkg), title, content);
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
        n.status = err.code == '23505' ? 'Sudah pernah dicatat' : 'Gagal simpan: ${err.code}';
      }
      _remember(n);
    } catch (err) {
      debugPrint('track: $err');
    }
  }

  static Future<String> forceSave(CapturedNotif n) async {
    final prefs = await SharedPreferences.getInstance();
    final orgId = prefs.getString('active_org_id') ?? '';
    if (orgId.isEmpty) return 'Workspace belum dipilih';
    if (SupabaseConfig.client.auth.currentSession == null) return 'Belum masuk di aplikasi';
    if (n.amount == null || n.amount! <= 0 || n.type == null) {
      return 'Nominal atau jenis tidak terbaca';
    }
    final label = n.appLabel ?? n.package;
    final walletId = await resolveWalletId(orgId, label, prefs);
    final category = prefs.getString(catPrefKey(label))?.trim();
    try {
      await TransactionService().add(
        orgId: orgId,
        type: n.type!,
        amount: n.amount!,
        walletId: walletId,
        category: (category == null || category.isEmpty) ? null : category,
        note: 'Otomatis dari $label',
        date: ymd(n.at),
        sourcePackage: n.package,
        sourceHash: notifHash(n.package, n.title, n.content, at: n.at),
      );
      n.status = 'Tersimpan';
      return 'Tersimpan';
    } on PostgrestException catch (err) {
      final msg = err.code == '23505' ? 'Sudah pernah dicatat' : 'Gagal simpan: ${err.code}';
      n.status = msg;
      return msg;
    } catch (_) {
      return 'Gagal simpan. Coba lagi.';
    }
  }
}
