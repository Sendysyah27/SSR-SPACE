import 'package:speech_to_text/speech_to_text.dart';

// Voice input: pembungkus tipis plugin speech_to_text untuk sheet catat.
// Semua gagal = false/null (pemanggil tampilkan pesan jujur, bukan crash).
// Izin mic diminta pemanggil saat tap (gesture), bukan di sini, supaya
// init SEKALI saat sheet dibuka tak memunculkan dialog tiba-tiba.
class VoiceInput {
  final SpeechToText _stt = SpeechToText();

  bool get isListening => _stt.isListening;

  /// Siapkan recognizer (panggil sekali). [onStatus] cth
  /// 'done'/'notListening'; [onError] terima kode error plugin.
  /// debugLogging nyala selama fase diagnosa bug mic (logcat saja).
  Future<bool> init({
    void Function(String status)? onStatus,
    void Function(String code)? onError,
  }) async {
    try {
      return await _stt.initialize(
        onStatus: onStatus == null ? null : (s) => onStatus(s),
        onError: onError == null ? null : (e) => onError(e.errorMsg),
        debugLogging: true,
      );
    } catch (_) {
      return false;
    }
  }

  /// Semua id locale layanan suara ([] = layanan mati/tak ada).
  /// Dipakai hitung diagnosa + pilih Indonesia.
  Future<List<String>> localeIds() async {
    try {
      final locales = await _stt.locales();
      return [for (final l in locales) l.localeId];
    } catch (_) {
      return [];
    }
  }

  /// Dengarkan; hasil parsial + final via [onResult].
  /// Jujur via [SpeechToText.isListening] (return listen() mentah
  /// berupa dynamic, tak bisa dipercaya langsung).
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
        listenOptions: options,
      );
      return _stt.isListening;
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
