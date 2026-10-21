import 'package:flutter_test/flutter_test.dart';
import 'package:ssr_space/services/ai_assistant_state.dart';
import 'package:ssr_space/services/firebase_ai_parser.dart';

void main() {
  group('assistantErrorState', () {
    test('kuota habis dari EF 403', () {
      const e = AiFailure(
          'server', '[AI] Kuota AI bulan ini habis. Upgrade Pro.');
      expect(assistantErrorState(e), 'kuota_habis');
    });

    test('kuota dari code quota provider', () {
      expect(assistantErrorState(const AiFailure('quota', 'x')),
          'kuota_habis');
    });

    test('rate limit', () {
      expect(
          assistantErrorState(
              const AiFailure('server', '[AI] limit terlampaui (429)')),
          'rate_limited');
    });

    test('timeout -> jaringan', () {
      expect(assistantErrorState(const AiFailure('timeout', '[AI] Timeout.')),
          'jaringan');
    });

    test('connection refused -> jaringan', () {
      expect(
          assistantErrorState(const AiFailure('server',
              '[AI] Connection refused to 127.0.0.1')),
          'jaringan');
    });

    test('error server lain -> server_tidak_tersedia', () {
      expect(
          assistantErrorState(
              const AiFailure('server', '[AI] server error (500)')),
          'server_tidak_tersedia');
    });
  });
}
