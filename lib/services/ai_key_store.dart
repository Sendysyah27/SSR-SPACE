import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Kunci API OpenCode Zen di Keystore/Keychain, bukan prefs.
// Tanpa init; semua gagal = default aman (null = mode anonim).
// Kunci tak pernah ditampilkan mentah di UI (hanya status ***).
const _kZenKey = 'ssr_zen_api_key';

/// True bila [url] aman dikirim bersama kunci AI/password.
/// Hanya `https://` — atau `http://` ke LOOPBACK (`127.0.0.1`,
/// `localhost`, `::1`) yang tak keluar device. MURNI (dart:core).
/// Alasan (audit P3-9): base URL `http://` non-loopback akan mengirim
/// kunci/password dalam cleartext di jaringan.
bool isSafeAiBaseUrl(String url) {
  final t = url.trim();
  if (t.startsWith('https://')) return true;
  if (!t.startsWith('http://')) return false;
  final host = Uri.tryParse(t)?.host.toLowerCase() ?? '';
  return host == '127.0.0.1' || host == 'localhost' || host == '::1';
}

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

// Kunci API 9router lokal di Keystore/Keychain (OpenAI-compatible,
// http://127.0.0.1:20128). Sejak 2.83.0+296 provider default 'nine'.
const _kNineKey = 'ssr_nine_api_key';

Future<String?> readNineKey() async {
  try {
    final v = await _storage.read(key: _kNineKey);
    if (v == null || v.trim().isEmpty) return null;
    return v.trim();
  } catch (_) {
    return null;
  }
}

Future<void> writeNineKey(String v) async {
  try {
    if (v.trim().isEmpty) {
      await _storage.delete(key: _kNineKey);
    } else {
      await _storage.write(key: _kNineKey, value: v.trim());
    }
  } catch (e) {
    // best-effort: gagal simpan key = mode tanpa key (tak bocor ke log).
    debugPrint('writeNineKey gagal: $e');
  }
}

Future<void> clearNineKey() async {
  try {
    await _storage.delete(key: _kNineKey);
  } catch (e) {
    // best-effort: hapus key gagal = sudah tak ada / tetap aman.
    debugPrint('clearNineKey gagal: $e');
  }
}

// Base URL + model 9router (prefs biasa, bukan rahasia).
const _kNineBase = 'ai_nine_base';
const _kNineModel = 'ai_nine_model';
const defaultNineBaseUrl = 'http://127.0.0.1:20128';
const defaultNineModel = 'tokenharbor/deepseek-v4.1-flash:free';

Future<String> nineBaseUrl() async {
  try {
    var v = ((await SharedPreferences.getInstance()).getString(_kNineBase) ??
            '')
        .trim();
    while (v.endsWith('/')) {
      v = v.substring(0, v.length - 1);
    }
    if (!v.startsWith('http://') && !v.startsWith('https://')) {
      return defaultNineBaseUrl;
    }
    // Netralkan nilai lama tak aman (http non-loopback) -> default.
    if (!isSafeAiBaseUrl(v)) return defaultNineBaseUrl;
    return v;
  } catch (_) {
    return defaultNineBaseUrl;
  }
}

/// Simpan base URL 9router. Nilai `http://` non-loopback DITOLAK
/// (audit P3-9): tak disimpan sama sekali, pemanggil tetap pakai
/// default loopback aman (`http://127.0.0.1:20128`). Return true bila
/// tersimpan, false bila ditolak.
Future<bool> setNineBaseUrl(String v) async {
  final raw = v.trim();
  if (raw.isNotEmpty && !isSafeAiBaseUrl(raw)) {
    // tolak non-loopback http — kunci akan travel cleartext.
    debugPrint('setNineBaseUrl: tolak base URL tak aman (http non-loopback)');
    return false;
  }
  try {
    await (await SharedPreferences.getInstance()).setString(_kNineBase, raw);
    return true;
  } catch (e) {
    // best-effort: gagal simpan base = tetap pakai default 127.0.0.1.
    debugPrint('setNineBaseUrl gagal: $e');
    return false;
  }
}

Future<String> nineModel() async {
  try {
    final v =
        ((await SharedPreferences.getInstance()).getString(_kNineModel) ?? '')
            .trim();
    return v.isEmpty ? defaultNineModel : v;
  } catch (_) {
    return defaultNineModel;
  }
}

Future<void> setNineModel(String v) async {
  try {
    await (await SharedPreferences.getInstance())
        .setString(_kNineModel, v.trim());
  } catch (e) {
    // best-effort: gagal simpan model = tetap pakai model default.
    debugPrint('setNineModel gagal: $e');
  }
}

// Pilihan provider AI (prefs biasa, bukan rahasia):
// 'nine' (9router lokal — DEFAULT sejak 2.83.0+296) | 'zen' | 'server'.
// Nilai lama 'local' (OpenCode lokal, sudah dihapus dari jalur
// eksekusi) bermigrasi ke 'nine'.
const _kAiProvider = 'ai_provider';

Future<String> aiProviderId() async {
  try {
    final v =
        (await SharedPreferences.getInstance()).getString(_kAiProvider);
    if (v == 'nine') return 'nine';
    if (v == 'zen') return 'zen';
    if (v == 'server') return 'server';
    return 'nine';
  } catch (_) {
    return 'nine';
  }
}

Future<void> setAiProviderId(String v) async {
  final id = (v == 'zen' || v == 'server') ? v : 'nine';
  try {
    await (await SharedPreferences.getInstance()).setString(_kAiProvider, id);
  } catch (e) {
    // best-effort: gagal simpan preferensi provider = default 'nine'.
    debugPrint('setAiProviderId gagal: $e');
  }
}

/// True bila provider aktif = 9router lokal (panggilan AI tidak lewat
/// server, jadi kuota AI plan & guard server tidak berlaku).
Future<bool> aiIsLocalProvider() async => (await aiProviderId()) == 'nine';

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
    // Netralkan nilai lama tak aman (http non-loopback) -> default.
    if (!isSafeAiBaseUrl(v)) return defaultLocalBaseUrl;
    return v;
  } catch (_) {
    return defaultLocalBaseUrl;
  }
}

/// Simpan base URL opencode lokal. `http://` non-loopback DITOLAK
/// (audit P3-9): tak disimpan, pemanggil tetap pakai default loopback.
/// Return true bila tersimpan, false bila ditolak.
Future<bool> setAiBaseUrl(String v) async {
  final raw = v.trim();
  if (raw.isNotEmpty && !isSafeAiBaseUrl(raw)) {
    // tolak non-loopback http — password akan travel cleartext.
    debugPrint('setAiBaseUrl: tolak base URL tak aman (http non-loopback)');
    return false;
  }
  try {
    await (await SharedPreferences.getInstance()).setString(_kAiBaseUrl, raw);
    return true;
  } catch (e) {
    // best-effort: gagal simpan base = tetap pakai default 127.0.0.1.
    debugPrint('setAiBaseUrl gagal: $e');
    return false;
  }
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
