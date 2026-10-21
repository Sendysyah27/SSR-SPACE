import 'package:shared_preferences/shared_preferences.dart';

// Personalisasi Mang AI (batch 281C tahap 3): persona (gaya jawab),
// instruksi kustom, nama panggilan user — meniru assistant_persona /
// assistant_custom_instruction / assistant_user_nickname-nya Ollo.
// Penyimpanan SharedPreferences (pola ai_memory.dart, fail-open),
// disuntikkan ke blok konteks kedua mode lewat aiPersonaBlock.
// Tanpa backend/tabel baru.

/// Pilihan persona -> arahan gaya untuk model.
const kAiPersonaStyles = <String, String>{
  'santai': 'Jawab santai seperti teman ngobrol, tetap jelas dan akurat.',
  'formal': 'Jawab sopan dan formal dengan kalimat yang rapi.',
  'ringkas': 'Jawab sangat ringkas: inti saja, tanpa basa-basi.',
  'detail': 'Jawab lebih detail; jelaskan alasan/langkah bila relevan.',
};

const kAiPersonaDefault = 'santai';

class AiPersonaPrefs {
  final String persona;
  final String customInstruction;
  final String nickname;
  const AiPersonaPrefs({
    this.persona = kAiPersonaDefault,
    this.customInstruction = '',
    this.nickname = '',
  });

  AiPersonaPrefs copyWith({
    String? persona,
    String? customInstruction,
    String? nickname,
  }) =>
      AiPersonaPrefs(
        persona: persona ?? this.persona,
        customInstruction: customInstruction ?? this.customInstruction,
        nickname: nickname ?? this.nickname,
      );
}

const _kPersona = 'ai_persona';
const _kCustom = 'ai_custom_instruction';
const _kNickname = 'ai_user_nickname';

Future<AiPersonaPrefs> loadAiPersona() async {
  try {
    final p = await SharedPreferences.getInstance();
    final persona = p.getString(_kPersona) ?? kAiPersonaDefault;
    return AiPersonaPrefs(
      persona:
          kAiPersonaStyles.containsKey(persona) ? persona : kAiPersonaDefault,
      customInstruction: p.getString(_kCustom) ?? '',
      nickname: p.getString(_kNickname) ?? '',
    );
  } catch (_) {
    return const AiPersonaPrefs();
  }
}

Future<void> saveAiPersona(AiPersonaPrefs v) async {
  try {
    final p = await SharedPreferences.getInstance();
    await p.setString(
        _kPersona,
        kAiPersonaStyles.containsKey(v.persona)
            ? v.persona
            : kAiPersonaDefault);
    await p.setString(_kCustom, v.customInstruction.trim());
    await p.setString(_kNickname, v.nickname.trim());
  } catch (_) {}
}

/// Blok personalisasi untuk disisipkan ke konteks prompt kedua mode.
/// Selalu memuat gaya persona terpilih; panggilan + instruksi kustom
/// hanya bila diisi user. Murni (tanpa I/O) agar testable.
String aiPersonaBlock(AiPersonaPrefs p) {
  final buf = StringBuffer();
  final style =
      kAiPersonaStyles[p.persona] ?? kAiPersonaStyles[kAiPersonaDefault]!;
  buf.write('\nGaya jawab pilihan user: $style');
  final nick = p.nickname.trim();
  if (nick.isNotEmpty) {
    buf.write('\nNama panggilan user: $nick. Sapa user dengan nama ini '
        'sesekali secara natural.');
  }
  final custom = p.customInstruction.trim();
  if (custom.isNotEmpty) {
    buf.write('\nInstruksi kustom dari user (ikuti selama tidak '
        'melanggar aturan format JSON dan kehati-hatian soal uang): '
        '$custom');
  }
  return buf.toString();
}
