import 'package:flutter_test/flutter_test.dart';
import 'package:ssr_space/services/category_meta.dart';

void main() {
  test('urai dan format dua lapis', () {
    final p = parseCategory('Makanan > Jajan');
    expect(p.top, 'Makanan');
    expect(p.sub, 'Jajan');
    expect(parseCategory('Makanan').sub, isNull);
    expect(formatCategory('Makanan', 'Jajan'), 'Makanan > Jajan');
    expect(formatCategory('Makanan', ''), 'Makanan');
    expect(formatCategory('Makanan', null), 'Makanan');
  });

  test('tolak nama berisi pemisah', () {
    expect(isValidSubName('Jajan'), true);
    expect(isValidSubName('A > B'), false);
    expect(isValidSubName('  '), false);
  });

  test('meta hilang memakai default', () {
    expect(CatMeta.tryParse(null), CatMeta.def);
    expect(CatMeta.tryParse({'color': 99, 'icon': 'x'}), CatMeta.def);
    expect(CatMeta.tryParse({'color': 2, 'icon': 'food'}).color, 2);
  });

  test('grup laporan tak berubah oleh subkategori', () {
    expect(topOf('Makanan > Jajan'), 'Makanan');
    expect(topOf('Makanan'), 'Makanan');
    expect(topOf(''), '');
    expect(topOf(null), '');
    expect(topOf('Tabungan > Darurat'), 'Tabungan');
  });
}
