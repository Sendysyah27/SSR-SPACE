import 'package:flutter_test/flutter_test.dart';
import 'package:ssr_space/models/transaction.dart';
import 'package:ssr_space/services/report_export.dart';
import 'package:ssr_space/theme/cool_icons.dart';

SaasTransaction _tx(
  String id,
  String type, {
  String? walletId,
  String? toWalletId,
}) {
  return SaasTransaction(
    id: id,
    orgId: 'org',
    type: type,
    amount: 1000,
    walletId: walletId,
    toWalletId: toWalletId,
  );
}

void main() {
  group('applyReportFilters', () {
    final items = [
      _tx('a', 'in', walletId: 'w1'),
      _tx('b', 'out', walletId: 'w1'),
      _tx('c', 'out', walletId: 'w2'),
      _tx('d', 'transfer', walletId: 'w1', toWalletId: 'w2'),
    ];

    test('all/all kembalikan semua', () {
      expect(applyReportFilters(items, null, 'all'), hasLength(4));
    });

    test('filter dompet ikut kaki transfer', () {
      final got = applyReportFilters(items, 'w2', 'all').map((t) => t.id);
      expect(got, containsAll(['c', 'd']));
      expect(got, hasLength(2));
    });

    test('filter jenis saja', () {
      expect(
        applyReportFilters(items, null, 'in').map((t) => t.id),
        ['a'],
      );
      expect(
        applyReportFilters(items, null, 'transfer').map((t) => t.id),
        ['d'],
      );
    });

    test('dompet + jenis digabung', () {
      expect(
        applyReportFilters(items, 'w1', 'out').map((t) => t.id),
        ['b'],
      );
    });

    test('jenis tak dikenal = all (fail-open)', () {
      expect(applyReportFilters(items, null, 'rusak'), hasLength(4));
    });
  });

  group('exportBaseName', () {
    test('polos', () {
      expect(exportBaseName('2026-09'), 'laporan-2026-09');
    });

    test('dompet + jenis', () {
      expect(
        exportBaseName('2026-09', walletLabel: 'DANA', flow: 'out'),
        'laporan-2026-09-dana-out',
      );
    });

    test('label disanitasi', () {
      expect(
        exportBaseName('2026-09', walletLabel: 'Bank BCA #1!'),
        'laporan-2026-09-bank-bca-1',
      );
    });
  });

  group('coolForNewCategory', () {
    test('enam kategori baru', () {
      expect(coolForNewCategory('Investasi saham'), CoolSvg.invest);
      expect(coolForNewCategory('Sedekah'), CoolSvg.donate);
      expect(coolForNewCategory('Belanja anak'), CoolSvg.family);
      expect(coolForNewCategory('Futsal'), CoolSvg.sport);
      expect(coolForNewCategory('Pakan kucing'), CoolSvg.pet);
      expect(coolForNewCategory('Dana darurat'), CoolSvg.sos);
    });

    test('lama dan kosong = null', () {
      expect(coolForNewCategory('Makan siang'), isNull);
      expect(coolForNewCategory(null), isNull);
      expect(coolForNewCategory(''), isNull);
    });
  });

  group('CoolSvg.pathForCodePoint', () {
    test('nav utama terpetakan', () {
      expect(CoolSvg.pathForCodePoint(0xe2c3), CoolSvg.home);
      expect(CoolSvg.pathForCodePoint(0xe3f1), CoolSvg.transactions);
      expect(CoolSvg.pathForCodePoint(0xea05), CoolSvg.budget);
      expect(CoolSvg.pathForCodePoint(0xe151), CoolSvg.reports);
    });

    test('tak dikenal = null (fallback legacy)', () {
      expect(CoolSvg.pathForCodePoint(0xffff), isNull);
    });
  });
}
