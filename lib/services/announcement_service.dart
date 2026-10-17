import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ssr_space/services/announcement_parse.dart';
import 'package:ssr_space/services/error_reporter.dart';
import 'package:ssr_space/services/supabase_config.dart';

// Pengumuman + roadmap: server dulu, fallback aset bawaan. Semua fungsi
// tak melempar; kegagalan dicatat ke ErrorReporter dan jatuh ke aset.
//
// Prefs: `ann_read_ids` (id yang sudah dibaca, stringlist cap) dan
// `ann_unread_count` (badge hub). Status baca di prefs menjaga konsistensi
// saat offline / RPC belum ada (fallback aset).
const String _kReadIds = 'ann_read_ids';
const String _kUnreadCount = 'ann_unread_count';
const int _capIds = 200;

Future<Set<String>> _loadIdSet(String key) async {
  final prefs = await SharedPreferences.getInstance();
  return (prefs.getStringList(key) ?? const <String>[]).toSet();
}

Future<void> _saveIdSet(String key, Set<String> ids) async {
  final prefs = await SharedPreferences.getInstance();
  final list = ids.toList();
  final capped = list.length > _capIds
      ? list.sublist(list.length - _capIds)
      : list;
  await prefs.setStringList(key, capped);
}

/// Hasil ambil pengumuman + sumbernya. `fromFallback` true berarti layar
/// sedang menampilkan aset bawaan (offline / RPC belum tersedia).
class AnnouncementsResult {
  final List<Announcement> items;
  final bool fromFallback;
  const AnnouncementsResult({required this.items, required this.fromFallback});
}

/// Ambil pengumuman aktif. RPC sukses = sumber kebenaran (array kosong
/// berarti memang kosong, BUKAN fallback). Exception apa pun → aset
/// bawaan + status baca dari prefs.
Future<List<Announcement>> fetchAnnouncements() async {
  return (await fetchAnnouncementsDetailed()).items;
}

/// Seperti [fetchAnnouncements] tapi ikut melaporkan apakah data dari
/// aset bawaan. Di jalur RPC sukses, status baca prefs di-union (monoton)
/// lalu id yang belum tercatat di server di-flush best-effort.
Future<AnnouncementsResult> fetchAnnouncementsDetailed() async {
  try {
    final res = await SupabaseConfig.client.rpc('list_announcements');
    final items = parseAnnouncements(res);
    final readIds = await _loadIdSet(_kReadIds);
    final pending = pendingReadIds(items, readIds);
    if (pending.isNotEmpty) {
      unawaited(_flushReadIds(pending));
    }
    return AnnouncementsResult(
      items: unionReadIds(items, readIds),
      fromFallback: false,
    );
  } catch (err, st) {
    await ErrorReporter.capture(err, st, context: 'list_announcements');
  }
  try {
    final raw = await rootBundle.loadString('assets/announcements_id.json');
    final parsed = parseFallbackAnnouncements(raw);
    final readIds = await _loadIdSet(_kReadIds);
    return AnnouncementsResult(
      items: unionReadIds(parsed, readIds),
      fromFallback: true,
    );
  } catch (_) {
    return const AnnouncementsResult(items: [], fromFallback: true);
  }
}

/// Kirim id baca lokal ke server sekali (best-effort). Tak pernah throw;
/// gagal tetap simpan prefs — percobaan berikutnya menyusul.
Future<void> _flushReadIds(Set<String> ids) async {
  try {
    await SupabaseConfig.client.rpc(
      'ack_announcements',
      params: {'p_ids': ids.toList()},
    );
  } catch (err, st) {
    await ErrorReporter.capture(err, st, context: 'ack_announcements_flush');
  }
}

/// Ambil roadmap. RPC sukses = sumber kebenaran; exception → aset bawaan.
Future<List<RoadmapItem>> fetchRoadmap() async {
  try {
    final res = await SupabaseConfig.client.rpc('list_roadmap');
    return parseRoadmap(res);
  } catch (err, st) {
    await ErrorReporter.capture(err, st, context: 'list_roadmap');
  }
  try {
    final raw = await rootBundle.loadString('assets/roadmap_id.json');
    return parseRoadmap(jsonDecode(raw));
  } catch (_) {
    return const [];
  }
}

/// Tandai pengumuman sudah dibaca: RPC + prefs lokal (konsisten offline).
/// Gagal → ErrorReporter.capture, tak pernah throw.
Future<void> ackAnnouncements(List<String> ids) async {
  if (ids.isEmpty) return;
  try {
    await SupabaseConfig.client.rpc(
      'ack_announcements',
      params: {'p_ids': ids},
    );
  } catch (err, st) {
    await ErrorReporter.capture(err, st, context: 'ack_announcements');
  }
  try {
    final set = await _loadIdSet(_kReadIds);
    set.addAll(ids);
    await _saveIdSet(_kReadIds, set);
  } catch (_) {
    // prefs gagal: badge server tetap benar saat online.
  }
}

/// Hitung ulang jumlah belum dibaca, simpan ke prefs (badge hub tanpa
/// network), lalu kembalikan.
Future<int> refreshUnreadBadge() async {
  final n = unreadCount(await fetchAnnouncements());
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kUnreadCount, n);
  } catch (_) {}
  return n;
}
