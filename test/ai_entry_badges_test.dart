import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ssr_space/services/ai_entry_badges.dart';
import 'package:ssr_space/utils/strings.dart';
import 'package:ssr_space/widgets/scan_error_sheet.dart';

// Batch 284 tahap D: label badge entry AI (murni) + sheet error scan.

void main() {
  group('aiQuotaBadgeLabel', () {
    test('null -> null (fail-open)', () {
      expect(aiQuotaBadgeLabel(null), isNull);
    });

    test('pro -> PRO', () {
      expect(
        aiQuotaBadgeLabel({'plan': 'pro', 'used': 3, 'limit': 30}),
        'PRO',
      );
    });

    test('gratis -> sisa limit - used', () {
      expect(
        aiQuotaBadgeLabel({'plan': 'free', 'used': 5, 'limit': 30}),
        '25',
      );
    });

    test('used melebihi limit -> 0', () {
      expect(
        aiQuotaBadgeLabel({'plan': 'free', 'used': 31, 'limit': 30}),
        '0',
      );
    });

    test('field hilang / limit 0 -> null', () {
      expect(aiQuotaBadgeLabel({'plan': 'free'}), isNull);
      expect(aiQuotaBadgeLabel({'used': 1, 'limit': 0}), isNull);
    });
  });

  group('aiPromoBadgeLabel', () {
    test('kosong -> null', () {
      expect(aiPromoBadgeLabel(''), isNull);
      expect(aiPromoBadgeLabel('   '), isNull);
    });

    test('nilai tampil apa adanya (trim)', () {
      expect(aiPromoBadgeLabel(' FREE '), 'FREE');
    });

    test('nilai panjang dipangkas 16 char', () {
      expect(aiPromoBadgeLabel('PROMO MERDEKA 2026'), 'PROMO MERDEKA 20');
    });
  });

  testWidgets('sheet error scan: 3 aksi tampil, Coba Lagi -> retry',
      (t) async {
    ScanErrorAction? got;
    var opened = false;
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (ctx) => TextButton(
              onPressed: () async {
                opened = true;
                got = await showScanErrorSheet(ctx, message: 'gagal baca');
              },
              child: const Text('buka'),
            ),
          ),
        ),
      ),
    );
    await t.tap(find.text('buka'));
    await t.pumpAndSettle();
    expect(opened, isTrue);
    expect(find.text(tr('scan_err_retry')), findsOneWidget);
    expect(find.text(tr('scan_err_replace')), findsOneWidget);
    expect(find.text(tr('scan_err_manual')), findsOneWidget);
    expect(find.text('gagal baca'), findsOneWidget);
    await t.tap(find.text(tr('scan_err_retry')));
    await t.pumpAndSettle();
    expect(got, ScanErrorAction.retry);
  });
}
