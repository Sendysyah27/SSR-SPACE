import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ssr_space/services/auto_saved_notify.dart';
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

  /// Hapus memori koreksi instan (pending + pref popup). Tak sentuh data.
  static Future<void> clearMemory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kPending);
    await prefs.remove(_kPopup);
  }

  /// Ringkasan satu baris: "Masuk Rp50.000 • DANA". Murni, bisa di-test.
  static String summary({
    required String type,
    required double amount,
    required String app,
  }) {
    final dir = type == 'in'
        ? tr('tx_in')
        : type == 'transfer'
            ? tr('tx_transfer')
            : tr('tx_out');
    return '$dir ${amt(amount)} • $app';
  }

  /// Popup tes tanpa menyentuh DB/pending: untuk memastikan overlay
  /// tampil di HP ini (sebagian OEM memblokir diam-diam meski izin aktif).
  /// True = perintah tampil terkirim; user tetap yang memastikan popup
  /// terlihat di layar (ia menutup sendiri 30 detik). Tak pernah melempar.
  static Future<bool> testOverlay() async {
    try {
      if (!Platform.isAndroid) return false;
      if (!await FlutterOverlayWindow.isPermissionGranted()) return false;
      try {
        await FlutterOverlayWindow.closeOverlay();
      } catch (_) {}
      await FlutterOverlayWindow.showOverlay(
        overlayTitle: tr('ic_overlay_t'),
        overlayContent: tr('ic_test_body'),
      );
      final payload = jsonEncode({
        'tx': '',
        'title': tr('ic_overlay_t'),
        'body': tr('ic_test_body'),
        'ok': tr('ic_lengkapi'),
        'no': tr('ic_tutup'),
      });
      await FlutterOverlayWindow.shareData(payload);
      await Future.delayed(const Duration(milliseconds: 600));
      await FlutterOverlayWindow.shareData(payload);
      return true;
    } catch (err, st) {
      ErrorReporter.capture(err, st, context: 'instant_correct_test');
      return false;
    }
  }

  /// Tawarkan koreksi setelah insert sukses. Tak pernah melempar.
  /// Overlay bubble prioritas; bila tak bisa tampil (popup mati, tanpa
  /// izin, diblokir OEM) jatuh ke notifikasi head-up sistem supaya tiap
  /// transaksi tersimpan tetap terlihat. Tak ada ganda: fallback hanya
  /// bila overlay tak tampil.
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
      var shown = false;
      try {
        if (await FlutterOverlayWindow.isPermissionGranted()) {
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
          shown = true;
        }
      } catch (err, st) {
        ErrorReporter.capture(err, st, context: 'instant_correct_overlay');
      }
      if (!shown) {
        await AutoSavedNotify.show(
          txId: txId,
          title: tr('ic_overlay_t'),
          body: s,
        );
      }
    } catch (err, st) {
      ErrorReporter.capture(err, st, context: 'instant_correct');
    }
  }
}
