import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart' as cg;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:ssr_space/utils/lockout_logic.dart';

/// PIN: hash+garam di secure storage (Keystore/Keychain), bukan prefs.
/// Yang tetap di prefs hanya penanda non-rahasia `pin_set` agar [hasPin]
/// tetap sinkron, plus counter lockout (tidak sensitif).
///
/// KDF: PBKDF2-HMAC-SHA256 100k iterasi (memperlambat tebakan offline;
/// PIN ruangnya cuma 10^6, jadi SHA-256 sekali putar terlalu cepat).
/// Penanda `pin_kdf` membedakan format; hash lama (SHA-256) masih bisa
/// diverifikasi sekali lalu otomatis di-upgrade ke PBKDF2 saat PIN benar.
const _kPinHash = 'pin_hash';
const _kPinSalt = 'pin_salt';
const _kPinKdf = 'pin_kdf';
const _kPinSet = 'pin_set';
const _pinKdfPbkdf2 = 'pbkdf2-sha256:100000';
const _pinKdfIterations = 100000;
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

  /// KDF lama (pra-2026-11-25): SHA-256 sekali putar. Dipertahankan hanya
  /// untuk verifikasi + upgrade hash lama; PIN baru selalu PBKDF2.
  String _hashPin(String salt, String pin) =>
      sha256.convert(utf8.encode('$salt::$pin')).toString();

  /// KDF baru: PBKDF2-HMAC-SHA256. Salt = byte dari garam heksadesimal.
  Future<String> _derivePin(String salt, String pin) async {
    final key = await cg.Pbkdf2(
      macAlgorithm: cg.Hmac.sha256(),
      iterations: _pinKdfIterations,
      bits: 256,
    ).deriveKeyFromPassword(password: pin, nonce: utf8.encode(salt));
    final bytes = await key.extractBytes();
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

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
    await _secWrite(_kPinHash, await _derivePin(salt, pin));
    await _secWrite(_kPinSalt, salt);
    await _secWrite(_kPinKdf, _pinKdfPbkdf2);
    await _set(_kPinSet, true);
    // Bersihkan format lama bila tersisa.
    await _remove(_kPinHash);
    await _remove(_kPinSalt);
    await _saveLockout(const PinLockout());
  }

  PinLockout _lockoutState() => PinLockout(
        failCount: _get<int>('pin_fail') ?? 0,
        level: _get<int>('pin_lock_level') ?? 0,
        lockUntilMs: _get<int>('pin_lock_until') ?? 0,
        highWaterMs: _get<int>('pin_hw') ?? 0,
      );

  Future<void> _saveLockout(PinLockout state) async {
    await _set('pin_fail', state.failCount);
    await _set('pin_lock_level', state.level);
    await _set('pin_lock_until', state.lockUntilMs);
    await _set('pin_hw', state.highWaterMs);
  }

  Future<bool> verifyPin(String pin) async {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final lock = _lockoutState();
    if (pinIsLockedOut(lock, nowMs)) {
      // Tetap naikkan high-water agar jam mundur tak memperpendek lockout.
      await _saveLockout(PinLockout(
        failCount: lock.failCount,
        level: lock.level,
        lockUntilMs: lock.lockUntilMs,
        highWaterMs: effectiveNowMs(nowMs, lock.highWaterMs),
      ));
      return false;
    }
    var hash = await _secRead(_kPinHash);
    var salt = await _secRead(_kPinSalt);
    var kdf = await _secRead(_kPinKdf);
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
        kdf = null; // masih sha256 lama -> di-upgrade di bawah
      }
    }
    var ok = false;
    if (hash != null && salt != null) {
      if (kdf == null) {
        // Format lama (SHA-256). Bila benar, upgrade diam-diam ke PBKDF2.
        ok = _hashPin(salt, pin) == hash;
        if (ok) {
          await _secWrite(_kPinHash, await _derivePin(salt, pin));
          await _secWrite(_kPinKdf, _pinKdfPbkdf2);
        }
      } else {
        ok = await _derivePin(salt, pin) == hash;
      }
    }
    if (ok) {
      await _saveLockout(pinRegisterSuccess(lock, nowMs));
      unlockAt = DateTime.now();
      lastActiveAt = DateTime.now();
      sessionId = const Uuid().v4();
    } else {
      await _saveLockout(pinRegisterFailure(lock, nowMs).state);
    }
    return ok;
  }

  bool get isLockedOut => pinIsLockedOut(
        _lockoutState(),
        DateTime.now().millisecondsSinceEpoch,
      );

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
