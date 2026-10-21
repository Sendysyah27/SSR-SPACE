import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ssr_space/services/ai_correction.dart';

Map<String, dynamic> base() => {
      'type': 'out',
      'amount': 20000,
      'wallet': 'Kas',
      'category': 'Makanan',
      'note': 'kopi kopken',
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('buildCorrectionEvent', () {
    test('ubah kategori saja -> 1 event, changed [category]', () {
      final fin = base()..['category'] = 'Minuman';
      final ev = buildCorrectionEvent(
        ai: base(),
        fin: fin,
        sourceText: 'kopi kopken 20000',
        now: DateTime(2026, 10, 21, 12, 0),
      );
      expect(ev, isNotNull);
      expect(ev!.changed, ['category']);
      expect(ev.ai['category'], 'Makanan');
      expect(ev.fin['category'], 'Minuman');
      expect(ev.source, 'kopi kopken 20000');
      expect(ev.synced, isFalse);
    });

    test('tanpa ubah -> null (0 event)', () {
      expect(
        buildCorrectionEvent(ai: base(), fin: base(), sourceText: 'x'),
        isNull,
      );
    });

    test('ubah amount -> changed mengandung amount', () {
      final fin = base()..['amount'] = 25000;
      final ev = buildCorrectionEvent(ai: base(), fin: fin, sourceText: 'x');
      expect(ev, isNotNull);
      expect(ev!.changed, contains('amount'));
    });

    test('ubah wallet + note -> changed [wallet, note]', () {
      final fin = base()
        ..['wallet'] = 'DANA'
        ..['note'] = 'kopi susu kopken';
      final ev = buildCorrectionEvent(ai: base(), fin: fin, sourceText: 'x');
      expect(ev, isNotNull);
      expect(ev!.changed, ['wallet', 'note']);
    });

    test('normalisasi: spasi/kapital dan null vs kosong bukan perubahan', () {
      final ai = base()..['category'] = ' Kopi ';
      final fin = base()
        ..['category'] = 'kopi'
        ..['note'] = 'kopi kopken';
      expect(
        buildCorrectionEvent(ai: ai, fin: fin, sourceText: 'x'),
        isNull,
      );
      final ai2 = base()..['wallet'] = null;
      final fin2 = base()..['wallet'] = '';
      expect(
        buildCorrectionEvent(ai: ai2, fin: fin2, sourceText: 'x'),
        isNull,
      );
    });
  });

  group('store lokal', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('record 1 event -> load 1 event pending', () async {
      final ev = buildCorrectionEvent(
        ai: base(),
        fin: base()..['category'] = 'Minuman',
        sourceText: 'kopi kopken 20000',
      )!;
      await recordCorrectionEvent(ev);
      final all = await loadCorrectionEvents();
      expect(all.length, 1);
      expect(all.first.synced, isFalse);
      expect(all.first.changed, ['category']);
      final pending = await pendingCorrectionEvents();
      expect(pending.length, 1);
    });
  });
}
