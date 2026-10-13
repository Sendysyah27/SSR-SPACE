import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// Kunci API Gemini (AI Studio) di Keystore/Keychain, bukan prefs.
// Tanpa init; semua gagal = default aman (null = pakai Firebase).
// Kunci tak pernah ditampilkan mentah di UI (hanya status ***).
const _kGeminiKey = 'ssr_gemini_api_key';

const _storage = FlutterSecureStorage();

Future<String?> readGeminiKey() async {
  try {
    final v = await _storage.read(key: _kGeminiKey);
    if (v == null || v.trim().isEmpty) return null;
    return v.trim();
  } catch (_) {
    return null;
  }
}

Future<void> writeGeminiKey(String v) async {
  try {
    if (v.trim().isEmpty) {
      await _storage.delete(key: _kGeminiKey);
    } else {
      await _storage.write(key: _kGeminiKey, value: v.trim());
    }
  } catch (_) {}
}

Future<void> clearGeminiKey() async {
  try {
    await _storage.delete(key: _kGeminiKey);
  } catch (_) {}
}
