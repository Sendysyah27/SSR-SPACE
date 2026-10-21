import 'package:flutter_test/flutter_test.dart';
import 'package:ssr_space/services/ai_parse_rules.dart';

void main() {
  group('parseQuickRecordRules', () {
    test('fixture server valid -> nilai dari server', () {
      const fixture = '{"version":7,'
          '"category_hints":{"kopi":"Lainnya","toko xyz":"KategoriX"},'
          '"parse_hints":["Petunjuk khusus server."]}';
      final r = parseQuickRecordRules(fixture);
      expect(r.version, 7);
      expect(r.categoryHints['kopi'], 'Lainnya');
      expect(r.categoryHints['toko xyz'], 'KategoriX');
      expect(r.parseHints, ['Petunjuk khusus server.']);
    });

    test('null / rusak / bukan map -> bawaan app', () {
      expect(parseQuickRecordRules(null).categoryHints['kopi'], 'Minuman');
      expect(parseQuickRecordRules('bukan json').categoryHints['kopi'],
          'Minuman');
      expect(parseQuickRecordRules('[1,2]').version, 1);
      expect(parseQuickRecordRules('{}').categoryHints['pln'], 'Tagihan');
    });

    test('field sebagian valid -> timpa per-field saja', () {
      final r = parseQuickRecordRules('{"category_hints":{"a":"B"}}');
      expect(r.categoryHints, {'a': 'B'});
      expect(r.parseHints, AiParseRules.builtin().parseHints);
    });
  });

  group('parseRulesBlock', () {
    test('blok memuat kosakata + versi dari config', () {
      final r = parseQuickRecordRules(
          '{"version":3,"category_hints":{"toko xyz":"KategoriX"}}');
      final block = parseRulesBlock(r);
      expect(block, contains('"toko xyz" -> KategoriX'));
      expect(block, contains('v3'));
    });

    test('ubah aturan server -> blok berubah tanpa ubah app', () {
      final before = parseRulesBlock(parseQuickRecordRules(
          '{"category_hints":{"kopi":"Minuman"}}'));
      final after = parseRulesBlock(parseQuickRecordRules(
          '{"category_hints":{"kopi":"Lainnya"}}'));
      expect(before, contains('"kopi" -> Minuman'));
      expect(after, contains('"kopi" -> Lainnya'));
      expect(after, isNot(contains('"kopi" -> Minuman')));
    });
  });
}
