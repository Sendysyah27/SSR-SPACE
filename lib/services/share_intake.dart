import 'dart:async';
import 'dart:io';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ssr_space/services/app_categories.dart';
import 'package:ssr_space/services/quick_link.dart';
import 'package:ssr_space/services/receipt_kind.dart';
import 'package:ssr_space/services/receipt_parse.dart';
import 'package:ssr_space/services/receipt_scan_service.dart';
import 'package:ssr_space/services/supabase_config.dart';
import 'package:ssr_space/utils/org_prefs.dart';
import 'package:ssr_space/utils/strings.dart';
import 'package:ssr_space/widgets/tx_input_sheet.dart';

// Deep-link quick-entry + share-gambar intake (Fase 2 widget suite).
//
// Pembagian tugas dingin/hangat: splash hanya MENITIPKAN (stashCold:
// initial link + initial media -> antrean prefs); MainShell yang
// MENGONSUMSI (consumeAll: bingkai pertama + tiap resume) lalu membuka
// sheet. Alasan: context splash mati setelah pushReplacement, jadi sheet
// tak bisa dibuka dari sana. Satu-satunya titik consume->sheet = consumeAll.

/// Kunci antrean path gambar share (milik Task 3, bukan Task 1).
const _shareKey = 'pending_share_image';
const _shareMoreKey = 'pending_share_more';

/// Pilih gambar pertama dari daftar share (Dart murni, testable).
/// Kosong -> (null, false); 1 -> (itu, false); N -> (pertama, true).
({String? first, bool hadMore}) pickFirstImage(List<String> paths) {
  if (paths.isEmpty) return (first: null, hadMore: false);
  return (first: paths.first, hadMore: paths.length > 1);
}

/// Titip path gambar share ke prefs (mis. terkunci/belum siap).
/// Foto milik app pengirim: tak pernah dihapus/diutak-atik di sini.
Future<void> queueSharePath(String path, {bool hadMore = false}) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_shareKey, path);
  await prefs.setBool(_shareMoreKey, hadMore);
}

/// Ambil antrean share + hapus (single-take).
/// [wasQueued] true + [path] null = berkas hilang sesudah diantre ->
/// hanguskan (pemanggil snackbar jujur). Tak pernah melempar.
Future<({String? path, bool hadMore, bool wasQueued})> takeSharePath() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString(_shareKey);
    if (path == null || path.isEmpty) {
      return (path: null, hadMore: false, wasQueued: false);
    }
    final hadMore = prefs.getBool(_shareMoreKey) ?? false;
    await prefs.remove(_shareKey);
    await prefs.remove(_shareMoreKey);
    if (!await File(path).exists()) {
      return (path: null, hadMore: false, wasQueued: true);
    }
    return (path: path, hadMore: hadMore, wasQueued: true);
  } catch (_) {
    return (path: null, hadMore: false, wasQueued: false);
  }
}

/// OCR gratis (ML Kit on-device) dari path berkas yang sudah ada.
/// Tanpa picker, tanpa upload, TANPA hapus berkas. AI-fallback bukan di
/// sini: tombol scan di sheet tetap menyediakan jalur AI berkuota.
Future<ReceiptData> scanSharedFile(String path) async {
  final bytes = await File(path).readAsBytes();
  if (bytes.isEmpty) throw const ReceiptScanException('rcp_empty');
  final text = await ocrBytesToText(bytes);
  lastRawOcrText = text;
  if (text.trim().isEmpty) throw const ReceiptScanException('rcp_empty');
  return parseReceipt(text);
}

/// tr() dengan fallback Indonesia: kunci Task-5 yang belum didefinisikan
/// mengembalikan nama kunci apa adanya (lihat strings.dart tr) — fallback
/// menjaga copy tetap manusiawi sampai Task 5 tiba.
String _t(String key, String fallback) {
  final s = tr(key);
  return s == key ? fallback : s;
}

void _snack(BuildContext context, String msg) {
  try {
    if (!context.mounted || msg.trim().isEmpty) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  } catch (_) {}
}

/// Wiring deep-link + share-intake. Semua entry fail-silent ke pemanggil
/// (snackbar jujur hanya untuk kejadian yang perlu diketahui user).
class ShareIntake {
  static bool _busy = false;
  static StreamSubscription<Uri>? _linkSub;
  static StreamSubscription<List<SharedMediaFile>>? _mediaSub;

  /// Dingin (dipanggil splash _boot): initial link -> antre; initial
  /// media -> antre path pertama. Tanpa UI, tanpa sheet. Tak melempar.
  static Future<void> stashCold() async {
    try {
      final uri = await AppLinks().getInitialLink();
      if (uri != null) {
        final type = parseQuickLink(uri);
        if (type != null) {
          try {
            await queuePending(type);
          } catch (_) {}
        }
      }
    } catch (_) {}
    try {
      final files = await ReceiveSharingIntent.instance.getInitialMedia();
      final picked = pickFirstImage([for (final f in files) f.path]);
      if (picked.first != null && picked.first!.isNotEmpty) {
        try {
          await queueSharePath(picked.first!, hadMore: picked.hadMore);
        } catch (_) {}
      }
      try {
        await ReceiveSharingIntent.instance.reset();
      } catch (_) {}
    } catch (_) {}
  }

  /// Hangat: dengar deep-link + share selama MainShell hidup.
  /// [context] milik MainShell (stabil lintas resume; diganti saat ganti
  /// workspace karena MainShell baru attach ulang). Tak melempar.
  static void attachWarm(BuildContext context) {
    detachWarm();
    try {
      _linkSub = AppLinks().uriLinkStream.listen(
        (uri) {
          unawaited(handleLink(context, uri));
        },
        onError: (_) {},
      );
    } catch (_) {}
    try {
      _mediaSub = ReceiveSharingIntent.instance.getMediaStream().listen(
        (files) {
          unawaited(handleMedia(context, [for (final f in files) f.path]));
        },
        onError: (_) {},
      );
    } catch (_) {}
  }

  /// Lepas langganan hangat (MainShell dispose / sebelum attach ulang).
  static void detachWarm() {
    try {
      _linkSub?.cancel();
    } catch (_) {}
    _linkSub = null;
    try {
      _mediaSub?.cancel();
    } catch (_) {}
    _mediaSub = null;
  }

  /// Deep-link hangat: siap -> sheet langsung; belum siap (keluar/belum
  /// workspace/terkunci) -> antre + snackbar jujur. Asing -> diam.
  static Future<void> handleLink(BuildContext context, Uri uri) async {
    final type = parseQuickLink(uri);
    if (type == null) return;
    final ready = await _ready();
    // Sibuk (sheet lain terbuka) -> antre juga: single-slot, latest wins.
    // Pengecekan sinkron -> atomik menuju _openQuick (tanpa await di
    // antaranya), jadi false dari _openQuick = batal user, bukan balapan.
    if (ready && !_busy) {
      await _openQuick(context, type);
      return;
    }
    try {
      await queuePending(type);
    } catch (_) {}
    _snack(
      context,
      _t('wg_locked_queued', 'Belum siap — antrean dibuka setelah siap.'),
    );
  }

  /// Share hangat: gambar pertama -> scan -> prefill sheet (tanpa
  /// auto-save); belum siap -> antre path + snackbar jujur.
  static Future<void> handleMedia(
    BuildContext context,
    List<String> paths,
  ) async {
    final picked = pickFirstImage(paths);
    if (picked.first == null || picked.first!.isEmpty) return;
    try {
      await ReceiveSharingIntent.instance.reset();
    } catch (_) {}
    if (!await _ready()) {
      try {
        await queueSharePath(picked.first!, hadMore: picked.hadMore);
      } catch (_) {}
      _snack(
        context,
        _t('wg_locked_queued', 'Belum siap — antrean dibuka setelah siap.'),
      );
      return;
    }
    // Sama seperti handleLink: sibuk -> antre (bukan hilang).
    if (_busy) {
      try {
        await queueSharePath(picked.first!, hadMore: picked.hadMore);
      } catch (_) {}
      return;
    }
    await _openShare(context, picked.first!, hadMore: picked.hadMore);
  }

  /// Konsumsi antrean (bingkai pertama MainShell + tiap resume):
  /// quick-entry dulu, lalu share-gambar. True bila ada sheet tersimpan
  /// (pemanggil muat ulang). Tanpa sheet ganda ([_busy] guard).
  static Future<bool> consumeAll(BuildContext context) async {
    var saved = false;
    if (!await _ready()) return false;
    String? type;
    try {
      type = await takePending();
    } catch (_) {}
    if (type != null && type.isNotEmpty) {
      if (await _openQuick(context, type)) saved = true;
      if (!context.mounted) return saved;
    }
    final share = await takeSharePath();
    if (!share.wasQueued) return saved;
    if (!context.mounted) return saved;
    if (share.path == null) {
      _snack(context, tr('rcp_empty'));
      return saved;
    }
    if (await _openShare(context, share.path!, hadMore: share.hadMore)) {
      saved = true;
    }
    return saved;
  }

  /// Siap konsumsi: sesi login + workspace aktif ada. Terkunci tak dicek
  /// di sini: pemanggil (init/resume MainShell) berjalan sesudah unlock.
  static Future<bool> _ready() async {
    var loggedIn = false;
    try {
      loggedIn = SupabaseConfig.client.auth.currentSession != null;
    } catch (_) {}
    if (!loggedIn) return false;
    try {
      if ((await activeOrgId()).isEmpty) return false;
    } catch (_) {
      return false;
    }
    return quickLinkReady(loggedIn: true, hasOrg: true, locked: false);
  }

  static Future<bool> _openQuick(BuildContext context, String type) async {
    if (_busy || !context.mounted) return false;
    _busy = true;
    try {
      return await openTxInputSheet(context, initialType: type);
    } catch (_) {
      return false;
    } finally {
      _busy = false;
    }
  }

  static Future<bool> _openShare(
    BuildContext context,
    String path, {
    required bool hadMore,
  }) async {
    if (_busy || !context.mounted) return false;
    _busy = true;
    try {
      ReceiptData data;
      try {
        data = await scanSharedFile(path);
      } on ReceiptScanException catch (e) {
        _snack(context, tr(e.trKey));
        return false;
      } catch (_) {
        _snack(context, tr('rcp_fail'));
        return false;
      }
      if (!context.mounted) return false;
      if (hadMore) {
        _snack(
          context,
          _t(
            'wg_share_first',
            'Hanya gambar pertama yang diproses.',
          ),
        );
      }
      final hasAmount = data.amount != null && data.amount! > 0;
      final note = receiptNote(data);
      final ok = await openTxInputSheet(
        context,
        initialType: 'out',
        initialAmountIdr: hasAmount ? data.amount : null,
        initialCategory: suggestReceiptCategory(
          merchant: data.merchant,
          items: data.items,
          raw: lastRawOcrText,
          categories: appCategories.value,
        ),
        initialNote: note.trim().isEmpty ? null : note,
      );
      // Parsed tapi tanpa total: sheet tetap dibuka (catatan+kategori
      // terisi), beri tahu jujur sesudahnya.
      if (!context.mounted) return ok;
      if (!hasAmount) _snack(context, tr('rcp_partial'));
      return ok;
    } finally {
      _busy = false;
    }
  }
}
