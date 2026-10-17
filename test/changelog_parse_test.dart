import 'package:flutter_test/flutter_test.dart';
import 'package:ssr_space/services/changelog_parse.dart';

void main() {
  test('parseChangelog blok per-versi + isInstalledVersion', () {
    const md = '''
# Catatan Perubahan SSR SPACE
Versi terpasang: 2.76.0+255.
## Yang baru di 2.76.0+255
- Pengumuman
- Roadmap
## Yang baru di 2.75.0+254
1. Perbaikan notifikasi
''';
    final vs = parseChangelog(md);
    expect(vs.length, 2);
    expect(vs[0].version, '2.76.0+255');
    expect(vs[0].items, ['Pengumuman', 'Roadmap']);
    expect(vs[1].items, ['Perbaikan notifikasi']);
    expect(isInstalledVersion(vs[0], '2.76.0+255'), isTrue);
    expect(isInstalledVersion(vs[1], '2.76.0+255'), isFalse);
    expect(parseChangelog(''), isEmpty);
  });

  test('blok tanpa item tetap ada + baris aneh diabaikan', () {
    const md = '''
## Yang baru di 1.0.0

Versi terpasang: 1.0.0.
''';
    final vs = parseChangelog(md);
    expect(vs.length, 1);
    expect(vs[0].version, '1.0.0');
    expect(vs[0].items, isEmpty);
  });

  test('marker campuran dash + nomor, marker telanjang dilewati', () {
    const md = '''
## Yang baru di 2.0.0
- Satu
2. Dua
3. Tiga
-
''';
    final vs = parseChangelog(md);
    expect(vs.single.items, ['Satu', 'Dua', 'Tiga']);
  });
}
