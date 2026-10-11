import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart';

// Voice input: pembungkus tipis plugin speech_to_text untuk sheet catat.
// Semua gagal = false/null (pemanggil tampilkan pesan jujur, bukan crash).
// Locale Indonesia bila tersedia di device, selain itu default sistem.
class VoiceInput {
  final SpeechToText _stt = SpeechToText();

  bool get isListening => _stt.isListening;

  /// Siapkan recognizer. Izin mic diminta eksplisit di sini (jangan
  /// andalkan plugin saja): ditolak = false. [onStatus] cth
  /// 'done'/'notListening'; [onError] terima kode error plugin.
  Future<bool> init({
    void Function(String status)? onStatus,
    void Function(String code)? onError,
  }) async {
    try {
      final perm = await Permission.microphone.request();
      if (!perm.isGranted) return false;
      return await _stt.initialize(
        onStatus: onStatus == null ? null : (s) => onStatus(s),
        onError: onError == null ? null : (e) => onError(e.errorMsg),
      );
    } catch (_) {
      return false;
    }
  }

  /// True bila layanan suara punya locale apa pun (= tersedia).
  /// Dipakai diagnosa saat init gagal (bedakan izin vs layanan).
  Future<bool> serviceAvailable() async {
    try {
      final locales = await _stt.locales();
      return locales.isNotEmpty;
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

  /// Izin mic versi plugin (tanpa prompt). Silang-cek dengan
  /// permission_handler bila init gagal.
  Future<bool> hasPermission() async {
    try {
      return await _stt.hasPermission;
    } catch (_) {
      return false;
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
