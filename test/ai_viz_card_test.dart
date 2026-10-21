import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ssr_space/services/ai_assistant_context.dart';
import 'package:ssr_space/services/ai_chat_parse.dart';
import 'package:ssr_space/utils/strings.dart';
import 'package:ssr_space/widgets/ai_viz_card.dart';

const _snap = AssistantSnapshot(
  wallets: [(name: 'Tunai', balance: 75000)],
  totalBalance: 75000,
  monthIn: 100000,
  monthOut: 60000,
  prevMonthIn: 80000,
  prevMonthOut: 50000,
  topCategories: [(name: 'Makanan', total: 40000)],
  daily30: [
    (day: '2026-10-01', inAmt: 0, outAmt: 10000),
    (day: '2026-10-02', inAmt: 50000, outAmt: 20000),
  ],
  topMerchants: [(name: 'Indomaret', total: 25000)],
  goals: [(name: 'Dana darurat', saved: 500000, target: 1000000)],
);

Future<void> _pumpCard(WidgetTester t, Map<String, dynamic> viz) async {
  await t.pumpWidget(
    MaterialApp(home: Scaffold(body: AiVizCard(viz: viz, data: _snap))),
  );
  await t.pumpAndSettle();
}

void main() {
  group('vizDeltaPct', () {
    test('selisih bertanda & kasus tepi', () {
      expect(vizDeltaPct(125, 100), '+25%');
      expect(vizDeltaPct(90, 100), '-10%');
      expect(vizDeltaPct(0, 0), '—');
      expect(vizDeltaPct(50, 0), 'baru');
    });
  });

  group('parseChatViz tipe baru', () {
    test('empat tipe baru diterima', () {
      for (final type in [
        'banding_periode',
        'tren_30',
        'top_merchant',
        'progres_target'
      ]) {
        expect(parseChatViz({'type': type})?['type'], type);
      }
    });

    test('tipe asing tetap null', () {
      expect(parseChatViz({'type': 'grafik_mewah'}), isNull);
    });
  });

  group('AiVizCard render', () {
    testWidgets('banding_periode: dua kolom + delta', (t) async {
      await _pumpCard(t, {'type': 'banding_periode'});
      expect(find.text(tr('ai_viz_banding')), findsOneWidget);
      expect(find.text(tr('ai_viz_ini')), findsOneWidget);
      expect(find.text(tr('ai_viz_lalu')), findsOneWidget);
      expect(find.textContaining('+25%'), findsWidgets);
    });

    testWidgets('tren_30: batang 30 hari + total', (t) async {
      await _pumpCard(t, {'type': 'tren_30'});
      expect(find.text(tr('ai_viz_tren30')), findsOneWidget);
      expect(find.textContaining('30000'), findsOneWidget);
    });

    testWidgets('top_merchant: daftar merchant lokal', (t) async {
      await _pumpCard(t, {'type': 'top_merchant'});
      expect(find.text(tr('ai_viz_merchant')), findsOneWidget);
      expect(find.text('Indomaret'), findsOneWidget);
    });

    testWidgets('progres_target: bar + persen dari snapshot', (t) async {
      await _pumpCard(t, {'type': 'progres_target'});
      expect(find.text(tr('ai_viz_target')), findsOneWidget);
      expect(find.text('Dana darurat'), findsOneWidget);
      expect(find.text('50%'), findsOneWidget);
    });

    testWidgets('viz rusak -> widget kosong, tidak crash', (t) async {
      await _pumpCard(t, {'type': 'grafik_mewah'});
      expect(find.byType(AiVizCard), findsOneWidget);
      expect(find.byType(Text), findsNothing);
    });

    testWidgets('kartu lama tetap jalan (saldo)', (t) async {
      await _pumpCard(t, {'type': 'saldo'});
      expect(find.text(tr('ai_viz_saldo')), findsOneWidget);
    });
  });
}
