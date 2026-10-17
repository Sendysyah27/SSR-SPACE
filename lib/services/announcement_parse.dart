// Parser murni untuk pengumuman + roadmap. Tanpa Flutter.
//
// Mengubah jsonb RPC (`list_announcements`/`list_roadmap`) atau aset
// fallback menjadi model. Sengaja toleran: entri cacat dilewati, nilai
// aneh jatuh ke default, dan fungsi tak pernah throw. Hanya memakai
// `dart:convert` untuk fallback aset, jadi bisa diuji `dart` murni.

import 'dart:convert';

/// Satu pengumuman yang sudah dinormalisasi.
class Announcement {
  final String id;
  final String title;
  final String body;
  final String kind;
  final bool pinned;
  final bool read;
  final DateTime? publishedAt;
  const Announcement({
    required this.id,
    required this.title,
    required this.body,
    required this.kind,
    required this.pinned,
    required this.read,
    this.publishedAt,
  });
}

/// Satu baris roadmap produk.
class RoadmapItem {
  final String id;
  final String title;
  final String description;
  final String status;
  final int sortOrder;
  const RoadmapItem({
    required this.id,
    required this.title,
    required this.description,
    required this.status,
    required this.sortOrder,
  });
}

const _kinds = {'info', 'promo', 'update'};
const _statuses = {'planned', 'in_progress', 'done'};

String _text(Map<dynamic, dynamic> m, String key) {
  final v = m[key];
  return v is String ? v : '';
}

/// Urai daftar pengumuman dari jsonb server / aset. List/Iterable saja;
/// elemen non-Map atau id kosong dilewati. Tak pernah throw.
List<Announcement> parseAnnouncements(Object? raw) {
  if (raw is! Iterable) return const [];
  final out = <Announcement>[];
  for (final e in raw) {
    if (e is! Map) continue;
    final id = e['id'];
    if (id is! String || id.isEmpty) continue;
    final kindRaw = e['kind'];
    final kind =
        kindRaw is String && _kinds.contains(kindRaw) ? kindRaw : 'info';
    final pubRaw = e['published_at'];
    out.add(Announcement(
      id: id,
      title: _text(e, 'title'),
      body: _text(e, 'body'),
      kind: kind,
      pinned: e['pinned'] == true,
      read: e['read'] == true,
      publishedAt: pubRaw is String ? DateTime.tryParse(pubRaw) : null,
    ));
  }
  return out;
}

/// Urai daftar roadmap. Toleransi sama dengan [parseAnnouncements];
/// status tak dikenal → `planned`, `sort_order` non-int → 0.
List<RoadmapItem> parseRoadmap(Object? raw) {
  if (raw is! Iterable) return const [];
  final out = <RoadmapItem>[];
  for (final e in raw) {
    if (e is! Map) continue;
    final id = e['id'];
    if (id is! String || id.isEmpty) continue;
    final statusRaw = e['status'];
    final status =
        statusRaw is String && _statuses.contains(statusRaw)
            ? statusRaw
            : 'planned';
    final order = e['sort_order'];
    out.add(RoadmapItem(
      id: id,
      title: _text(e, 'title'),
      description: _text(e, 'description'),
      status: status,
      sortOrder: order is int ? order : 0,
    ));
  }
  return out;
}

/// Urai aset fallback JSON (`assets/announcements_id.json`). Decode
/// gagal → daftar kosong.
List<Announcement> parseFallbackAnnouncements(String json) {
  try {
    return parseAnnouncements(jsonDecode(json));
  } catch (_) {
    return const [];
  }
}

/// Jumlah pengumuman yang belum dibaca.
int unreadCount(List<Announcement> list) =>
    list.where((a) => !a.read).length;
