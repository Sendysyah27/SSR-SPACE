import 'package:speech_to_text/speech_to_text.dart';

// Voice input: pembungkus tipis plugin speech_to_text untuk sheet catat.
// Semua gagal = false/null (pemanggil tampilkan pesan jujur, bukan crash).
// Locale Indonesia bila tersedia di device, selain itu default sistem.
class VoiceInput {
  final SpeechToText _stt = SpeechToText();

  bool get isListening => _stt.isListening;

  /// Siapkan recognizer. [onStatus] cth 'done'/'notListening' (opsional).
  Future<bool> init({void Function(String status)? onStatus}) async {
    try {
      return await _stt.initialize(
        onStatus: onStatus == null ? null : (s) => onStatus(s),
      );
    } catch (_) {
      return false;
    }
  }

  /// Id locale Indonesia pertama bila ada, null = pakai default.
  Future<String?> pickIndonesianLocale() async {
    try {
      final locales = await _stt.locales();
      for (final l in locales) {
        if (l.localeId.toLowerCase().startsWith('id')) return l.localeId;
      }
    } catch (_) {}
    return null;
  }

  /// Dengarkan; hasil parsial + final via [onResult]. False bila gagal mulai.
  Future<bool> listen({
    required void Function(String words, bool finalResult) onResult,
    String? localeId,
  }) async {
    try {
      final options = localeId == null
          ? SpeechListenOptions(partialResults: true)
          : SpeechListenOptions(
              localeId: localeId,
              partialResults: true,
            );
      await _stt.listen(
        onResult: (r) => onResult(r.recognizedWords, r.finalResult),
        options: options,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> stop() async {
    try {
      await _stt.stop();
    } catch (_) {}
  }
}
