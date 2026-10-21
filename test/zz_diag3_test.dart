import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ssr_space/screens/lainnya/ai_draft_screen.dart';
import 'package:ssr_space/services/ai_draft.dart';

// DIAGNOSTIK 3 SEMENTARA batch 286 — inspeksi langsung widget.onSaveDraft.
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
  testWidgets('diag3: widget.onSaveDraft null?', (t) async {
    Future<void> cb(AiDraft d) async {}
    await t.pumpWidget(
      MaterialApp(
        home: AiDraftScreen(initial: _draft, onSaveDraft: cb),
      ),
    );
    await t.pumpAndSettle();
    final el = find.byType(AiDraftScreen).evaluate().single;
    final w = el.widget as AiDraftScreen;
    debugPrint('DIAG3-WIDGET-onSaveDraft-null: ${w.onSaveDraft == null}');
    debugPrint('DIAG3-WIDGET-onSaveDraft-identical: ${identical(w.onSaveDraft, cb)}');
    // Cek state.widget juga
    final state = t.state<AiDraftScreenState>(find.byType(AiDraftScreen));
    debugPrint(
        'DIAG3-STATE-widget-onSaveDraft-null: ${state.widget.onSaveDraft == null}');
  });
}
