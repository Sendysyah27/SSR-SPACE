import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ssr_space/screens/lainnya/ai_draft_screen.dart';
import 'package:ssr_space/services/ai_draft.dart';
import 'package:ssr_space/services/receipt_parse.dart';

// Batch 286 tahap C: review terstruktur menampilkan jam + diskon,
// tombol Simpan Draft meneruskan isi form, Pakai draft membawa
// jam/diskon/pajak/jenis bayar ke ReceiptData.
const _draft = AiDraft(
  merchant: 'SANCHA',
  date: '2026-09-08',
  time: '19:21',
  items: [
    AiDraftItem(name: 'Da Hong Pao Milk Tea (M)', qty: 1, price: 32000),
  ],
  subtotal: 32000,
  discount: 16000,
  total: 16000,
  payment: 'QRIS',
);

void main() {
  testWidgets('field jam & diskon tampil dari draft awal', (t) async {
    await t.pumpWidget(
      const MaterialApp(home: AiDraftScreen(initial: _draft)),
    );
    await t.pumpAndSettle();
    expect(find.text('19:21'), findsOneWidget);
    // 16000 muncul dua kali: field diskon + field total.
    expect(find.text('16000'), findsNWidgets(2));
    expect(find.text('SANCHA'), findsOneWidget);
  });

  testWidgets('Simpan draft meneruskan isi form ke callback', (t) async {
    AiDraft? saved;
    await t.pumpWidget(
      MaterialApp(
        home: AiDraftScreen(
          initial: _draft,
          onSaveDraft: (d) async => saved = d,
        ),
      ),
    );
    await t.pumpAndSettle();
    await t.tap(find.text('Simpan draft'));
    await t.pumpAndSettle();
    expect(saved, isNotNull);
    expect(saved!.merchant, 'SANCHA');
    expect(saved!.time, '19:21');
    expect(saved!.discount, 16000);
    expect(saved!.total, 16000);
    expect(saved!.items.length, 1);
  });

  testWidgets('tanpa callback, tombol Simpan draft tidak tampil',
      (t) async {
    await t.pumpWidget(
      const MaterialApp(home: AiDraftScreen(initial: _draft)),
    );
    await t.pumpAndSettle();
    expect(find.text('Simpan draft'), findsNothing);
  });

  testWidgets('Pakai draft: ReceiptData membawa jam + diskon', (t) async {
    ReceiptData? result;
    await t.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (ctx) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () async {
                  result = await Navigator.of(ctx).push<ReceiptData>(
                    MaterialPageRoute(
                      builder: (_) => const AiDraftScreen(initial: _draft),
                    ),
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    await t.tap(find.text('Pakai draft'));
    await t.pumpAndSettle();
    expect(result, isNotNull);
    expect(result!.amount, 16000);
    expect(result!.date, DateTime(2026, 9, 8, 19, 21));
    expect(result!.voucher, 16000);
    expect(result!.time, '19:21');
    expect(result!.payType, 'QRIS');
    expect(result!.lineItems.length, 1);
  });
}
