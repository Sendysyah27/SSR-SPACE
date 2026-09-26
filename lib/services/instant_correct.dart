import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ssr_space/services/error_reporter.dart';
import 'package:ssr_space/services/foreground_track.dart';
import 'package:ssr_space/utils/mask.dart';
import 'package:ssr_space/utils/strings.dart';

const _kPopup = 'correct_popup';
const _kPending = 'pending_correct_tx';

const _noticeMins = 3;

/// Koreksi instan: overlay ±30 detik + sematan notif service 3 menit
/// setiap auto-catat sukses. Transaksi TETAP dicatat dulu (anti-hilang);
/// popup/notif hanya jalan pintas koreksi kategori + catatan.
class InstantCorrect {
  static Timer? _noticeTimer;

  static bool popupEnabled(SharedPreferences prefs) =>
      prefs.getBool(_kPopup) ?? true;

  static Future<void> setPopupEnabled(bool v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kPopup, v);
  }

  static Future<String?> pendingTxId() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getString(_kPending);
    return (v == null || v.isEmpty) ? null : v;
  }

  static Future<void> clearPending() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kPending);
  }

  /// Ringkasan satu baris: "Masuk Rp50.000 • DANA". Murni, bisa di-test.
  static String summary({
    required String type,
    required double amount,
    required String app,
  }) {
    final dir = type == 'in' ? tr('tx_in') : tr('tx_out');
    return '$dir ${amt(amount)} • $app';
  }

  /// Tawarkan koreksi setelah insert sukses. Tak pernah melempar.
  static Future<void> offer({
    required String txId,
    required String type,
    required double amount,
    required String app,
  }) async {
    try {
      if (!Platform.isAndroid) return;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kPending, txId);
      final s = summary(type: type, amount: amount, app: app);
      await ForegroundTrack.pinNotice(s);
      _noticeTimer?.cancel();
      _noticeTimer = Timer(const Duration(minutes: _noticeMins), () async {
        await ForegroundTrack.clearNotice();
        await clearPending();
        try {
          await FlutterOverlayWindow.closeOverlay();
        } catch (_) {}
      });
      if (!popupEnabled(prefs)) return;
      if (!await FlutterOverlayWindow.isPermissionGranted()) return;
      try {
        await FlutterOverlayWindow.closeOverlay();
      } catch (_) {}
      await FlutterOverlayWindow.showOverlay(
        overlayTitle: tr('ic_overlay_t'),
        overlayContent: s,
      );
      final payload = jsonEncode({
        'tx': txId,
        'title': tr('ic_overlay_t'),
        'body': s,
        'ok': tr('ic_lengkapi'),
        'no': tr('ic_tutup'),
      });
      await FlutterOverlayWindow.shareData(payload);
      await Future.delayed(const Duration(milliseconds: 600));
      await FlutterOverlayWindow.shareData(payload);
    } catch (err, st) {
      ErrorReporter.capture(err, st, context: 'instant_correct');
    }
  }
}
