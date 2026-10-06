import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ssr_space/services/category_icons.dart';
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

  test('svg kustomisasi: kunci dikenal + asing fallback', () {
    expect(svgForMetaIcon('food'), 'assets/icons/coolicons/Coffee.svg');
    expect(svgForMetaIcon('transfer'), 'assets/icons/coolicons/Arrow_Left_Right.svg');
    expect(svgForMetaIcon('wallet'), 'assets/icons/coolicons/Credit_Card_01.svg');
    expect(
      svgForMetaIcon('kunci_asing'),
      'assets/icons/coolicons/Tag.svg',
    );
  });

  test('simpan meta umumkan ke notifier + muat ulang', () async {
    SharedPreferences.setMockInitialValues({});
    await refreshCategoryMeta();
    expect(categoryMeta.value, isEmpty);
    await saveCategoryMeta({
      'Makan': const CatMeta(color: 0, icon: 'food'),
    });
    expect(categoryMeta.value['Makan']?.icon, 'food');
    expect(categoryMeta.value['Makan']?.color, 0);
    await refreshCategoryMeta();
    expect(categoryMeta.value['Makan']?.icon, 'food');
  });
}
