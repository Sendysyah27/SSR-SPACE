import 'package:flutter/services.dart';

// Voice input native: SpeechRecognizer Android langsung via channel
// `ssr_space/voice` (tanpa plugin speech_to_text). Implementasi native
// di-inject CI ke MainActivity. Semua gagal = false (tak pernah throw).
//
// Protokol channel:
//   Dart -> native: isAvailable, start{locale?}, stop.
//   Native -> Dart: onResult{words, final}, onError{code}, onStatus{status}.
// Kode error: no_match, speech_timeout, permission, busy, service.
class VoiceNative {
  static const channelName = 'ssr_space/voice';

  final MethodChannel _ch = const MethodChannel(channelName);
  bool _listening = false;

  bool get isListening => _listening;

  /// Recognizer tersedia di device (layanan suara + bukan emulator bisu).
  Future<bool> isAvailable() async {
    try {
      return await _ch.invokeMethod<bool>('isAvailable') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Mulai dengar. [localeId] null = default sistem.
  Future<bool> start({
    required void Function(String words, bool finalResult) onResult,
    required void Function(String code) onError,
    required void Function(String status) onStatus,
    String? localeId,
  }) async {
    try {
      _ch.setMethodCallHandler((call) async {
        final args =
            Map<String, dynamic>.from((call.arguments as Map?) ?? {});
        switch (call.method) {
          case 'onResult':
            onResult('${args['words'] ?? ''}', args['final'] == true);
          case 'onError':
            _listening = false;
            onError('${args['code'] ?? 'service'}');
          case 'onStatus':
            final s = '${args['status'] ?? ''}';
            if (s == 'done') _listening = false;
            onStatus(s);
        }
      });
      final ok = await _ch.invokeMethod<bool>(
        'start',
        {'locale': localeId},
      );
      _listening = ok ?? false;
      return _listening;
    } catch (_) {
      _listening = false;
      return false;
    }
  }

  Future<void> stop() async {
    try {
      await _ch.invokeMethod('stop');
    } catch (_) {}
    _listening = false;
  }
}
