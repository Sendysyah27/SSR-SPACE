import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// Enkripsi artefak AI at-rest (audit P2-10): chat/memori/koreksi/alias
// AI disimpan di SharedPreferences sebagai teks polos. Helper ini
// membungkusnya dengan AES-256-GCM memakai kunci device 32-byte yang
// hidup di flutter_secure_storage (Keystore/Keychain), bukan di prefs.
//
// Format: [aiStoreMarker] + base64(nonce(12) || mac(16) || ciphertext).
// - Marker `SSR-AI1:` menandai ciphertext; tanpa marker = plaintext lama
//   (migrasi transparan: baca apa adanya, tulis terenkripsi berikutnya).
// - Nonce acak tiap tulis; GCM = confidentiality + integrity.
//
// FAIL-SAFE: helper ini TIDAK PERNAH throw.
//   * Secure storage tak tersedia (mis. VM/test/plugin mati) -> pakai
//     kunci sementara DI MEMORI sehingga enkripsi/round-trip tetap
//     jalan dalam satu proses (tanpa pernah menyentuh plaintext).
//   * Kegagalan kripto lain -> kembalikan plain apa adanya (encode) /
//     null (decode) agar tak ada data yang hilang.
const aiStoreMarker = 'SSR-AI1:';

/// Kunci master di secure storage (bukan prefs).
const _kAiPrefsKey = 'ssr_ai_prefs_key';

const _keyLen = 32;
const _nonceLen = 12;
const _macLen = 16;

const _storage = FlutterSecureStorage();

/// Kunci dalam memori (cache). Diisi sekali per proses.
List<int>? _cachedKey;

List<int> _randomBytes(int n) {
  final rnd = Random.secure();
  return List<int>.generate(n, (_) => rnd.nextInt(256));
}

/// Ambil (atau buat sekali) kunci device 32-byte. Tak pernah throw:
/// bila secure storage gagal, pakai kunci acak di memori.
Future<List<int>> _loadKey() async {
  final cached = _cachedKey;
  if (cached != null) return cached;
  try {
    final stored = await _storage.read(key: _kAiPrefsKey);
    if (stored != null && stored.isNotEmpty) {
      final k = base64Decode(stored);
      if (k.length == _keyLen) {
        _cachedKey = k;
        return k;
      }
    }
    final fresh = _randomBytes(_keyLen);
    await _storage.write(key: _kAiPrefsKey, value: base64Encode(fresh));
    _cachedKey = fresh;
    return fresh;
  } catch (_) {
    // best-effort: secure storage tak tersedia -> kunci sementara di
    // memori. Round-trip tetap jalan dalam proses ini; tak pernah plaintext.
    final fresh = _randomBytes(_keyLen);
    _cachedKey = fresh;
    return fresh;
  }
}

/// Enkripsi [plain] -> teks ber-marker [aiStoreMarker]. Bila enkripsi
/// gagal (mis. kripto tak tersedia), kembalikan [plain] apa adanya
/// (fail-safe: data tetap ada, hanya tak terenkripsi).
Future<String> encodeAiStore(String plain) async {
  try {
    final key = await _loadKey();
    final gcm = AesGcm.with256bits();
    final nonce = gcm.newNonce();
    final box = await gcm.encrypt(
      utf8.encode(plain),
      secretKey: SecretKey(key),
      nonce: nonce,
    );
    final packed = <int>[
      ...box.nonce,
      ...box.mac.bytes,
      ...box.cipherText,
    ];
    return aiStoreMarker + base64Encode(packed);
  } catch (_) {
    // best-effort: kripto gagal = simpan plain demi integritas data.
    return plain;
  }
}

/// Dekripsi nilai tersimpan. Aturan:
/// - null/kosong -> null;
/// - tanpa marker -> kembalikan apa adanya (plaintext lama, migrasi);
/// - ber-marker -> dekripsi; gagal (rusak/kunci beda) -> null.
Future<String?> decodeAiStore(String? stored) async {
  if (stored == null || stored.isEmpty) return null;
  if (!stored.startsWith(aiStoreMarker)) return stored;
  try {
    final key = await _loadKey();
    final packed = base64Decode(stored.substring(aiStoreMarker.length));
    if (packed.length < _nonceLen + _macLen) return null;
    final nonce = packed.sublist(0, _nonceLen);
    final mac = packed.sublist(_nonceLen, _nonceLen + _macLen);
    final ct = packed.sublist(_nonceLen + _macLen);
    final clear = await AesGcm.with256bits().decrypt(
      SecretBox(ct, nonce: nonce, mac: Mac(mac)),
      secretKey: SecretKey(key),
    );
    return utf8.decode(clear);
  } catch (_) {
    // best-effort: rusak/kunci beda -> anggap tak ada (pemanggil fallback).
    return null;
  }
}

/// True bila [stored] tampak sebagai ciphertext ber-marker. MURNI.
bool isEncodedAiStore(String? stored) =>
    stored != null && stored.startsWith(aiStoreMarker);
