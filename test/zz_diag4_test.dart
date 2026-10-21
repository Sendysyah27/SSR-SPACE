import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ssr_space/screens/lainnya/ai_draft_screen.dart';
import 'package:ssr_space/services/ai_draft.dart';
import 'package:ssr_space/services/receipt_parse.dart';

// DIAGNOSTIK 4 SEMENTARA batch 286 — cek navigasi push.
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
  testWidgets('diag4: navigasi push', (t) async {
    await t.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (ctx) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () {
                  debugPrint('DIAG4-onPressed-called');
                  Navigator.of(ctx).push<ReceiptData>(
                    MaterialPageRoute(
                      builder: (_) => const AiDraftScreen(initial: _draft),
                    ),
                  );
                  debugPrint('DIAG4-push-called');
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
    debugPrint('DIAG4-after-settle');
    final screens =
        find.byType(AiDraftScreen, skipOffstage: false).evaluate().length;
    debugPrint('DIAG4-AiDraftScreen-count: $screens');
    final texts = find
        .byType(Text, skipOffstage: false)
        .evaluate()
        .map((e) => (e.widget as Text).data ?? '<rich>')
        .toList();
    debugPrint('DIAG4-TEXTS: $texts');
  });
}
