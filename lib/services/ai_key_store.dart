import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// Kunci API Zen + sakelar AI Parser (Keystore/Keychain, bukan prefs).
// Tanpa init; semua gagal = default aman (null/false).
const _kAiKey = 'ssr_ai_zen_key';
const _kAiOn = 'ssr_ai_enabled';

const _storage = FlutterSecureStorage();

Future<String?> readAiKey() async {
  try {
    final v = await _storage.read(key: _kAiKey);
    if (v == null || v.trim().isEmpty) return null;
    return v.trim();
  } catch (_) {
    return null;
  }
}

Future<void> writeAiKey(String v) async {
  try {
    if (v.trim().isEmpty) {
      await _storage.delete(key: _kAiKey);
    } else {
      await _storage.write(key: _kAiKey, value: v.trim());
    }
  } catch (_) {}
}

Future<void> clearAiKey() async {
  try {
    await _storage.delete(key: _kAiKey);
  } catch (_) {}
}

Future<bool> readAiOn() async {
  try {
    return await _storage.read(key: _kAiOn) == '1';
  } catch (_) {
    return false;
  }
}

Future<void> writeAiOn(bool v) async {
  try {
    await _storage.write(key: _kAiOn, value: v ? '1' : '0');
  } catch (_) {}
}
