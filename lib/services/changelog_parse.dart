// Parser murni `assets/changelog_id.md` -> kartu per-versi. Tanpa Flutter.
//
// Format blok: baris `## Yang baru di <version>` lalu item `- ...` atau
// `1. ...`. Baris lain (header dokumen, `Versi terpasang:`, baris aneh)
// diabaikan. Blok tanpa item tetap dimasukkan supaya versi tak hilang.
// Tak pernah throw; input kosong → daftar kosong.

/// Satu versi changelog dengan daftar poinnya.
class ChangelogVersion {
  final String version;
  final List<String> items;
  const ChangelogVersion({required this.version, required this.items});
}

final _headerRe = RegExp(r'^##\s+Yang baru di\s+(.+?)\s*$');
final _numberedRe = RegExp(r'^\d+\.\s+(.*)$');

List<ChangelogVersion> parseChangelog(String markdown) {
  final out = <ChangelogVersion>[];
  String? version;
  List<String>? items;
  void flush() {
    final v = version;
    final it = items;
    if (v != null && it != null) {
      out.add(ChangelogVersion(version: v, items: it));
    }
  }

  for (final raw in markdown.split('\n')) {
    final line = raw.trimRight();
    final m = _headerRe.firstMatch(line);
    if (m != null) {
      flush();
      version = m.group(1)!.trim();
      items = <String>[];
      continue;
    }
    if (version == null) continue;
    final item = _itemOf(line);
    if (item != null) items!.add(item);
  }
  flush();
  return out;
}

String? _itemOf(String line) {
  final t = line.trimLeft();
  if (t.startsWith('- ')) {
    final v = t.substring(2).trim();
    return v.isEmpty ? null : v;
  }
  final m = _numberedRe.firstMatch(t);
  if (m != null) {
    final v = m.group(1)!.trim();
    return v.isEmpty ? null : v;
  }
  return null;
}

/// Apakah [v] adalah versi yang terpasang di perangkat.
bool isInstalledVersion(ChangelogVersion v, String installed) =>
    v.version == installed;
