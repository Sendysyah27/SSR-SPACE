import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ssr_space/services/ai_merchant_alias.dart';

MerchantAlias mk(String key, {String? category, String? wallet, int count = 1}) =>
    MerchantAlias(
      key: key,
      category: category,
      wallet: wallet,
      count: count,
      lastUsed: '2026-10-21T00:00:00.000',
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('normalizeMerchantKey', () {
    test('buang stopword + tanda baca', () {
      expect(normalizeMerchantKey('Beli Kopi di KopKen!'), 'kopi kopken');
    });
    test('kosong -> kosong', () {
      expect(normalizeMerchantKey(''), '');
      expect(normalizeMerchantKey('beli di'), '');
    });
    test('transfer via DANA', () {
      expect(normalizeMerchantKey('TRANSFER via DANA'), 'transfer dana');
    });
  });

  group('trigramSimilarity', () {
    test('string sama -> 1.0', () {
      expect(trigramSimilarity('kopken', 'kopken'), 1.0);
    });
    test('tak terkait -> di bawah ambang', () {
      expect(trigramSimilarity('kopken', 'starbucks'),
          lessThan(aliasTrigramThreshold));
    });
    test('awalan sama panjang -> di atas ambang', () {
      expect(trigramSimilarity('kopi kenangan', 'kopi kenangan jiwa'),
          greaterThanOrEqualTo(aliasTrigramThreshold));
    });
  });

  group('findAliasFor', () {
    test('teks mengandung kunci alias -> hit', () {
      final aliases = [mk('kopken', category: 'Minuman', count: 3)];
      final hit = findAliasFor('kopi di kopken tadi', aliases);
      expect(hit, isNotNull);
      expect(hit!.key, 'kopken');
    });
    test('teks tak terkait -> null', () {
      final aliases = [mk('kopken', category: 'Minuman', count: 3)];
      expect(findAliasFor('bayar listrik pln', aliases), isNull);
    });
    test('count tertinggi menang', () {
      final aliases = [
        mk('kopi', category: 'Makanan', count: 1),
        mk('kopi kenangan', category: 'Minuman', count: 5),
      ];
      final hit = findAliasFor('kopi kenangan', aliases);
      expect(hit!.category, 'Minuman');
    });
  });

  group('store + skenario belajar', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('upsert dua kali teks mirip -> 1 alias count 2', () async {
      await upsertMerchantAlias(
          sourceText: 'Kopi KopKen', category: 'Minuman', wallet: 'Kas');
      await upsertMerchantAlias(
          sourceText: 'kopi di kopken', category: 'Minuman', wallet: 'Kas');
      final all = await loadMerchantAliases();
      expect(all.length, 1);
      expect(all.first.count, 2);
      expect(all.first.category, 'Minuman');
    });

    test('koreksi kategori merchant X -> hint pencatatan berikutnya', () async {
      // Simulasi hasil koreksi: user mengubah kategori merchant kopken
      // menjadi Minuman (nilai final yang dipelajari).
      await upsertMerchantAlias(
          sourceText: 'kopken', category: 'Minuman', wallet: 'DANA');
      final aliases = await loadMerchantAliases();
      final hit = findAliasFor('kopken', aliases);
      expect(hit, isNotNull);
      final block = aliasHintBlock(hit!);
      expect(block, contains('Minuman'));
      expect(block, contains('DANA'));
    });
  });
}
