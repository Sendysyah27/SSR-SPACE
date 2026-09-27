/// Rekap kategori Top-8 plus Others + urutan section (P2), Dart murni.
///
/// Tie-break abjad agar urutan stabil antar render. Total Others tidak
/// mengubah total keseluruhan (hanya pengelompokan tampil).
class CatTotal {
  final String name;
  final double total;

  const CatTotal(this.name, this.total);
}

class TopNResult {
  final List<CatTotal> top;
  final List<CatTotal> others;

  const TopNResult(this.top, this.others);

  double get othersTotal => others.fold<double>(0, (s, c) => s + c.total);
}

const defaultSectionOrder = <String>['summary', 'recap', 'list'];
const _knownSections = <String>{'summary', 'recap', 'list'};

/// Kelompokkan [totals] (nama kategori ke nominal) jadi Top-8 + Others.
/// Bila [enabled] false atau kategori <= 8, semua masuk [top].
TopNResult top8PlusOthers(Map<String, double> totals, {bool enabled = true}) {
  final sorted = totals.entries
      .map((e) => CatTotal(e.key, e.value))
      .toList()
    ..sort((a, b) {
      final byTotal = b.total.compareTo(a.total);
      if (byTotal != 0) return byTotal;
      return a.name.compareTo(b.name);
    });
  if (!enabled || sorted.length <= 8) {
    return TopNResult(List<CatTotal>.unmodifiable(sorted), const []);
  }
  return TopNResult(
    List<CatTotal>.unmodifiable(sorted.take(8)),
    List<CatTotal>.unmodifiable(sorted.skip(8)),
  );
}

/// Bersihkan prefs urutan section: buang id asing/duplikat, tambahkan
/// id baku yang hilang sesuai urutan baku. Rusak total -> urutan baku.
List<String> sanitizeSectionOrder(List<String>? raw) {
  if (raw == null || raw.isEmpty) return List<String>.of(defaultSectionOrder);
  final seen = <String>{};
  final out = <String>[];
  for (final id in raw) {
    if (_knownSections.contains(id) && seen.add(id)) out.add(id);
  }
  for (final id in defaultSectionOrder) {
    if (seen.add(id)) out.add(id);
  }
  return out.isEmpty ? List<String>.of(defaultSectionOrder) : out;
}
