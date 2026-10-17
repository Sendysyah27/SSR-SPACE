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

/// Ambil pengumuman aktif. RPC sukses = sumber kebenaran (array kosong
/// berarti memang kosong, BUKAN fallback). Exception apa pun → aset
/// bawaan + status baca dari prefs.
Future<List<Announcement>> fetchAnnouncements() async {
  try {
    final res = await SupabaseConfig.client.rpc('list_announcements');
    return parseAnnouncements(res);
  } catch (err, st) {
    await ErrorReporter.capture(err, st, context: 'list_announcements');
  }
  try {
    final raw = await rootBundle.loadString('assets/announcements_id.json');
    final parsed = parseFallbackAnnouncements(raw);
    final readIds = await _loadIdSet(_kReadIds);
    return [
      for (final a in parsed)
        Announcement(
          id: a.id,
          title: a.title,
          body: a.body,
          kind: a.kind,
          pinned: a.pinned,
          read: a.read || readIds.contains(a.id),
          publishedAt: a.publishedAt,
        ),
    ];
  } catch (_) {
    return const [];
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
