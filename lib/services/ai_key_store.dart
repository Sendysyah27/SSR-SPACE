import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Kunci API OpenCode Zen di Keystore/Keychain, bukan prefs.
// Tanpa init; semua gagal = default aman (null = mode anonim).
// Kunci tak pernah ditampilkan mentah di UI (hanya status ***).
const _kZenKey = 'ssr_zen_api_key';

const _storage = FlutterSecureStorage();

Future<String?> readZenKey() async {
  try {
    final v = await _storage.read(key: _kZenKey);
    if (v == null || v.trim().isEmpty) return null;
    return v.trim();
  } catch (_) {
    return null;
  }
}

Future<void> writeZenKey(String v) async {
  try {
    if (v.trim().isEmpty) {
      await _storage.delete(key: _kZenKey);
    } else {
      await _storage.write(key: _kZenKey, value: v.trim());
    }
  } catch (e) {
    // best-effort: gagal simpan kunci = tetap mode anonim (bukan crash).
    debugPrint('writeZenKey gagal: $e');
  }
}

Future<void> clearZenKey() async {
  try {
    await _storage.delete(key: _kZenKey);
  } catch (e) {
    // best-effort: hapus kunci gagal = sudah tak ada / tetap aman.
    debugPrint('clearZenKey gagal: $e');
  }
}

// Password opencode serve lokal (Keystore/Keychain, bukan prefs).
// Diisi dari layar Mang AI, dikirim per-call via MethodChannel,
// TIDAK PERNAH di-log di mana pun.
const _kLocalPass = 'ssr_local_ai_pass';

Future<String?> readLocalPass() async {
  try {
    final v = await _storage.read(key: _kLocalPass);
    if (v == null || v.trim().isEmpty) return null;
    return v.trim();
  } catch (_) {
    return null;
  }
}

Future<void> writeLocalPass(String v) async {
  try {
    if (v.trim().isEmpty) {
      await _storage.delete(key: _kLocalPass);
    } else {
      await _storage.write(key: _kLocalPass, value: v.trim());
    }
  } catch (e) {
    // best-effort: password lokal gagal disimpan (tak bocor ke log).
    debugPrint('writeLocalPass gagal: $e');
  }
}

Future<void> clearLocalPass() async {
  try {
    await _storage.delete(key: _kLocalPass);
  } catch (e) {
    // best-effort: hapus password gagal = tetap aman.
    debugPrint('clearLocalPass gagal: $e');
  }
}

// Pilihan provider AI (prefs biasa, bukan rahasia): 'server' | 'zen'.
// Default + fallback aman = 'server' (Mang AI server, sejak
// 2.82.13+280). Nilai lama 'local' (OpenCode lokal, sudah dihapus
// dari jalur eksekusi) bermigrasi ke 'server'.
const _kAiProvider = 'ai_provider';

Future<String> aiProviderId() async {
  try {
    final v =
        (await SharedPreferences.getInstance()).getString(_kAiProvider);
    return v == 'zen' ? 'zen' : 'server';
  } catch (_) {
    return 'server';
  }
}

Future<void> setAiProviderId(String v) async {
  try {
    await (await SharedPreferences.getInstance())
        .setString(_kAiProvider, v == 'zen' ? 'zen' : 'server');
  } catch (e) {
    // best-effort: gagal simpan preferensi provider = default 'server'.
    debugPrint('setAiProviderId gagal: $e');
  }
}

// Base URL opencode serve lokal (prefs biasa, bukan rahasia).
const _kAiBaseUrl = 'ai_base_url';
const defaultLocalBaseUrl = 'http://127.0.0.1:4096';

Future<String> aiBaseUrl() async {
  try {
    var v = ((await SharedPreferences.getInstance())
                .getString(_kAiBaseUrl) ??
            '')
        .trim();
    while (v.endsWith('/')) {
      v = v.substring(0, v.length - 1);
    }
    if (!v.startsWith('http://') && !v.startsWith('https://')) {
      return defaultLocalBaseUrl;
    }
    return v;
  } catch (_) {
    return defaultLocalBaseUrl;
  }
}

Future<void> setAiBaseUrl(String v) async {
  try {
    await (await SharedPreferences.getInstance())
        .setString(_kAiBaseUrl, v.trim());
  } catch (_) {}
}

// Sakelar AI (prefs biasa, default ON). Tanpa prefs (error) = ON.
const _kAiEnabled = 'ai_enabled';

Future<bool> aiEnabled() async {
  try {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_kAiEnabled) ?? true;
  } catch (_) {
    return true;
  }
}

Future<void> setAiEnabled(bool v) async {
  try {
    await (await SharedPreferences.getInstance()).setBool(_kAiEnabled, v);
  } catch (_) {}
}

// Cap waktu terakhir kuota habis (ISO, prefs biasa). Dibaca Settings
// untuk info jujur "terakhir kehabisan".
const _kQuotaHit = 'ai_quota_hit';

Future<void> noteQuotaHit() async {
  try {
    await (await SharedPreferences.getInstance())
        .setString(_kQuotaHit, DateTime.now().toIso8601String());
  } catch (_) {}
}

Future<DateTime?> lastQuotaHit() async {
  try {
    final v =
        (await SharedPreferences.getInstance()).getString(_kQuotaHit);
    if (v == null || v.isEmpty) return null;
    return DateTime.tryParse(v);
  } catch (_) {
    return null;
  }
}
