import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ssr_space/screens/lainnya/ai_draft_screen.dart';
import 'package:ssr_space/services/ai_draft.dart';

// DIAGNOSTIK 5 SEMENTARA batch 286 — walk manual element tree.
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

void _walk(Element e, int depth, List<String> out) {
  if (depth > 12) return;
  final w = e.widget;
  final t = w.runtimeType.toString();
  if (t.contains('Button') ||
      t.contains('ListView') ||
      t.contains('Scaffold') ||
      t.contains('AiDraft')) {
    out.add('${'  ' * depth}$t');
  }
  e.visitChildren((c) => _walk(c, depth + 1, out));
}

void main() {
  testWidgets('diag5: walk tree', (t) async {
    Future<void> cb(AiDraft d) async {}
    await t.pumpWidget(
      MaterialApp(
        home: AiDraftScreen(initial: _draft, onSaveDraft: cb),
      ),
    );
    await t.pumpAndSettle();
    final out = <String>[];
    _walk(
        find.byType(AiDraftScreen).evaluate().single as Element, 0, out);
    debugPrint('DIAG5-TREE:\n${out.join('\n')}');
  });
}
