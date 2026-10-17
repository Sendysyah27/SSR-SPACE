import 'dart:io';

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

  test('aset nyata: blok 2.4.5 tepat 7 item, tanpa bocoran section luar', () {
    final md = File('assets/changelog_id.md').readAsStringSync();
    final vs = parseChangelog(md);

    final v245 = vs.where((v) => v.version == '2.4.5').toList();
    expect(v245.length, 1);
    expect(v245.single.items.length, 7);
    expect(
      v245.single.items.first,
      'Layar Bantuan: tutorial pemakaian per fitur plus tanya jawab umum.',
    );
    expect(
      v245.single.items.last,
      'Tema Otomatis dan Noir bisa diganti bolak-balik.',
    );

    // heading `## ` non-Yang-baru tak jadi versi & itemnya tak bocor
    expect(vs.any((v) => v.version.contains('Sebelumnya')), isFalse);
    expect(vs.any((v) => v.version.contains('Inti')), isFalse);
    expect(
      vs.any((v) => v.items.any((i) => i.contains('Target tabungan'))),
      isFalse,
    );
    expect(
      vs.any((v) => v.items.any((i) => i.contains('Workspace bersama'))),
      isFalse,
    );
    // semua versi berasal dari blok `## Yang baru di …`
    expect(vs.every((v) => RegExp(r'^\d').hasMatch(v.version)), isTrue);
  });
}
