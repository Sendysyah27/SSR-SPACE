import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ssr_space/services/ai_assistant_feedback.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('feedbackContext', () {
    test('memasking nomor panjang & memotong ke 200 char', () {
      final raw = 'Saldo kamu aman. Rekening 1234567890123 tercatat. '
          '${'Isi tambahan yang panjang. ' * 20}';
      final ctx = feedbackContext(raw);
      expect(ctx.contains('1234567890123'), isFalse);
      expect(ctx.length <= feedbackContextCap, isTrue);
    });

    test('teks pendek lolos utuh (newline jadi spasi)', () {
      expect(feedbackContext('Halo\n dunia'), 'Halo  dunia');
    });
  });

  group('AssistantFeedback json', () {
    test('roundtrip toJson/fromJson', () {
      const e = AssistantFeedback(
        id: 'fb-1',
        rating: -1,
        context: 'ctx',
        createdAt: '2026-10-21T10:00:00',
        synced: true,
      );
      final back = AssistantFeedback.fromJson(e.toJson());
      expect(back, isNotNull);
      expect(back!.rating, -1);
      expect(back.context, 'ctx');
      expect(back.synced, isTrue);
    });

    test('rating asing ditolak', () {
      expect(
        AssistantFeedback.fromJson(
            {'id': 'x', 'rating': 5, 'context': '', 'created_at': ''}),
        isNull,
      );
    });

    test('toRow memuat org/user/rating/context', () {
      const e = AssistantFeedback(
          id: 'fb-2', rating: 1, context: 'ok', createdAt: 't');
      final row = e.toRow('org1', 'user1');
      expect(row['org_id'], 'org1');
      expect(row['user_id'], 'user1');
      expect(row['rating'], 1);
      expect(row['context'], 'ok');
    });
  });

  group('antrean lokal', () {
    test('save + load; rating tidak sah diabaikan', () async {
      SharedPreferences.setMockInitialValues({});
      await saveAssistantFeedback(rating: 1, replyText: 'Jawaban A');
      await saveAssistantFeedback(rating: -1, replyText: 'Jawaban B');
      await saveAssistantFeedback(rating: 0, replyText: 'Abaikan');
      final all = await loadAssistantFeedback();
      expect(all.length, 2);
      expect(all[0].rating, 1);
      expect(all[1].rating, -1);
      expect(all.every((e) => !e.synced), isTrue);
    });

    test('cap membuang tersinkron dulu, lalu tertua', () {
      final items = [
        for (var i = 0; i < feedbackQueueCap + 3; i++)
          AssistantFeedback(
            id: 'fb-$i',
            rating: 1,
            context: '',
            createdAt: 't$i',
            synced: i < 2,
          ),
      ];
      final capped = capFeedbackQueue(items);
      expect(capped.length, feedbackQueueCap);
      expect(capped.any((e) => e.id == 'fb-0'), isFalse);
      expect(capped.any((e) => e.id == 'fb-1'), isFalse);
      expect(capped.any((e) => e.id == 'fb-2'), isFalse);
    });
  });
}
