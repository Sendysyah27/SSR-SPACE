import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ssr_space/screens/lainnya/ai_draft_screen.dart';
import 'package:ssr_space/services/ai_draft.dart';

// DIAGNOSTIK SEMENTARA batch 286 — cetak semua teks di tree.
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
  testWidgets('diag: daftar semua teks dengan onSaveDraft', (t) async {
    await t.pumpWidget(
      MaterialApp(
        home: AiDraftScreen(
          initial: _draft,
          onSaveDraft: (d) async {},
        ),
      ),
    );
    await t.pumpAndSettle();
    final texts = find
        .byType(Text)
        .evaluate()
        .map((e) => (e.widget as Text).data ?? '<rich>')
        .toList();
    debugPrint('DIAG-TEXTS: $texts');
    final btns = find.byType(OutlinedButton).evaluate().length;
    debugPrint('DIAG-OUTLINEDBUTTON-COUNT: $btns');
    final prim = find.byType(ElevatedButton).evaluate().length;
    debugPrint('DIAG-ELEVATEDBUTTON-COUNT: $prim');
  });
}
