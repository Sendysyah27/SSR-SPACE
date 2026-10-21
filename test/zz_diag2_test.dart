import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ssr_space/screens/lainnya/ai_draft_screen.dart';
import 'package:ssr_space/services/ai_draft.dart';
import 'package:ssr_space/widgets/primary_button.dart';

// DIAGNOSTIK 2 SEMENTARA batch 286 — cek offstage + dump.
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
  testWidgets('diag2: offstage check', (t) async {
    await t.pumpWidget(
      MaterialApp(
        home: AiDraftScreen(
          initial: _draft,
          onSaveDraft: (d) async {},
        ),
      ),
    );
    await t.pumpAndSettle();
    debugPrint(
        'DIAG2-OUTLINED: ${find.byType(OutlinedButton).evaluate().length}');
    debugPrint(
        'DIAG2-OUTLINED-ALLOFF: ${find.byType(OutlinedButton, skipOffstage: false).evaluate().length}');
    debugPrint(
        'DIAG2-ELEVATED-ALLOFF: ${find.byType(ElevatedButton, skipOffstage: false).evaluate().length}');
    debugPrint(
        'DIAG2-TEXTBUTTON-ALLOFF: ${find.byType(TextButton, skipOffstage: false).evaluate().length}');
    debugPrint(
        'DIAG2-PRIMARY: ${find.byType(PrimaryButton, skipOffstage: false).evaluate().length}');
  });
}
