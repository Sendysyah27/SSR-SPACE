import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// PIN: hash+garam di secure storage (Keystore/Keychain), bukan prefs.
/// Yang tetap di prefs hanya penanda non-rahasia `pin_set` agar [hasPin]
/// tetap sinkron, plus counter lockout (tidak sensitif).
/// Migrasi: hash lama di prefs diverifikasi sekali saat PIN benar, lalu
/// dipindah ke secure storage + dihapus dari prefs.
const _kPinHash = 'pin_hash';
const _kPinSalt = 'pin_salt';
const _kPinSet = 'pin_set';
const _storage = FlutterSecureStorage();

class SessionService {
  final Map<String, Object> _mem;
  final SharedPreferences? _prefs;
  final bool _inMemory;

  String sessionId = const Uuid().v4();
  DateTime? unlockAt;
  DateTime lastActiveAt = DateTime.now();

  SessionService(SharedPreferences prefs)
      : _prefs = prefs,
        _mem = {},
        _inMemory = false;

  SessionService.inMemory()
      : _prefs = null,
        _mem = {},
        _inMemory = true;

  T? _get<T>(String k) => _inMemory ? _mem[k] as T? : _prefs!.get(k) as T?;
  Future<void> _set(String k, Object v) async {
    if (_inMemory) {
      _mem[k] = v;
    } else {
      if (v is bool) await _prefs!.setBool(k, v);
      if (v is String) await _prefs!.setString(k, v);
      if (v is int) await _prefs!.setInt(k, v);
      if (v is double) await _prefs!.setDouble(k, v);
      if (v is List<String>) await _prefs!.setStringList(k, v);
    }
  }

  Future<void> _remove(String k) async {
    if (_inMemory) {
      _mem.remove(k);
    } else {
      await _prefs!.remove(k);
    }
  }

  /// Baca rahasia: secure storage dulu; bila platform tak tersedia (test),
  /// fallback memori terpisah (`sec:`) agar tak bentrok kunci prefs.
  /// Gagal total = null (fail-closed).
  Future<String?> _secRead(String k) async {
    try {
      return await _storage.read(key: k);
    } catch (_) {
      return _mem['sec:$k'] as String?;
    }
  }

  Future<void> _secWrite(String k, String v) async {
    try {
      await _storage.write(key: k, value: v);
    } catch (_) {
      _mem['sec:$k'] = v;
    }
  }

  String _hashPin(String salt, String pin) =>
      sha256.convert(utf8.encode('$salt::$pin')).toString();

  String _newSalt() => List.generate(
          16,
          (_) =>
              Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'))
      .join();

  bool get isFirstRun => (_get<bool>('onboarding_done') ?? false) == false;

  /// Sinkron: penanda prefs + fallback hash lama (pra-migrasi).
  bool get hasPin =>
      (_get<bool>(_kPinSet) ?? false) || _get<String>(_kPinHash) != null;

  Future<void> completeOnboarding(String name) async {
    await _set('onboarding_done', true);
    await _set('profile_name', name);
    sessionId = const Uuid().v4();
    lastActiveAt = DateTime.now();
  }

  Future<void> setPin(String pin) async {
    final salt = _newSalt();
    await _secWrite(_kPinHash, _hashPin(salt, pin));
    await _secWrite(_kPinSalt, salt);
    await _set(_kPinSet, true);
    // Bersihkan format lama bila tersisa.
    await _remove(_kPinHash);
    await _remove(_kPinSalt);
    await _set('pin_fail', 0);
  }

  Future<bool> verifyPin(String pin) async {
    final lockUntil = _get<int>('pin_lock_until') ?? 0;
    if (DateTime.now().millisecondsSinceEpoch < lockUntil) return false;
    var hash = await _secRead(_kPinHash);
    var salt = await _secRead(_kPinSalt);
    if (hash == null || salt == null) {
      // Migrasi satu-kali dari prefs lama: PIN benar -> pindah.
      final legacyHash = _get<String>(_kPinHash);
      final legacySalt = _get<String>(_kPinSalt);
      if (legacyHash != null &&
          legacySalt != null &&
          _hashPin(legacySalt, pin) == legacyHash) {
        await _secWrite(_kPinHash, legacyHash);
        await _secWrite(_kPinSalt, legacySalt);
        await _remove(_kPinHash);
        await _remove(_kPinSalt);
        await _set(_kPinSet, true);
        hash = legacyHash;
        salt = legacySalt;
      }
    }
    final ok =
        hash != null && salt != null && _hashPin(salt, pin) == hash;
    if (ok) {
      await _set('pin_fail', 0);
      unlockAt = DateTime.now();
      lastActiveAt = DateTime.now();
      sessionId = const Uuid().v4();
    } else {
      final f = (_get<int>('pin_fail') ?? 0) + 1;
      await _set('pin_fail', f);
      if (f >= 5) {
        await _set('pin_lock_until',
            DateTime.now().add(const Duration(seconds: 60)).millisecondsSinceEpoch);
        await _set('pin_fail', 0);
      }
    }
    return ok;
  }

  bool get isLockedOut =>
      DateTime.now().millisecondsSinceEpoch < (_get<int>('pin_lock_until') ?? 0);

  /// Buka via biometrik (PIN tak diketik): efek sama dengan verifyPin
  /// sukses (tanpa menyentuh counter gagal/lockout).
  void markUnlocked() {
    unlockAt = DateTime.now();
    lastActiveAt = DateTime.now();
    sessionId = const Uuid().v4();
  }
  bool shouldRelock({Duration timeout = const Duration(minutes: 5)}) =>
      DateTime.now().difference(lastActiveAt) > timeout;

  void touch() => lastActiveAt = DateTime.now();
}
