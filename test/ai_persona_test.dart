import 'package:flutter_test/flutter_test.dart';
import 'package:ssr_space/services/ai_persona.dart';

void main() {
  test('aiPersonaBlock default hanya memuat gaya santai', () {
    final b = aiPersonaBlock(const AiPersonaPrefs());
    expect(b.contains('Gaya jawab pilihan user'), isTrue);
    expect(b.contains('santai seperti teman'), isTrue);
    expect(b.contains('Nama panggilan'), isFalse);
    expect(b.contains('Instruksi kustom'), isFalse);
  });

  test('aiPersonaBlock memuat panggilan + instruksi + gaya formal', () {
    final b = aiPersonaBlock(const AiPersonaPrefs(
      persona: 'formal',
      nickname: 'Sendy',
      customInstruction: 'Selalu beri saran hemat.',
    ));
    expect(b.contains('sopan dan formal'), isTrue);
    expect(b.contains('Sendy'), isTrue);
    expect(b.contains('Selalu beri saran hemat.'), isTrue);
  });

  test('copyWith hanya mengubah field yang diberikan', () {
    const p = AiPersonaPrefs(nickname: 'A');
    final q = p.copyWith(persona: 'detail');
    expect(q.persona, 'detail');
    expect(q.nickname, 'A');
    expect(q.customInstruction, '');
  });
}
