import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

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
    }
  }

  bool get isFirstRun => (_get<bool>('onboarding_done') ?? false) == false;
  bool get hasPin => _get<String>('pin_hash') != null;

  Future<void> completeOnboarding(String name) async {
    await _set('onboarding_done', true);
    await _set('profile_name', name);
    sessionId = const Uuid().v4();
  }

  Future<void> setPin(String pin) async {
    final salt = List.generate(16, (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0')).join();
    await _set('pin_hash', sha256.convert(utf8.encode('$salt::$pin')).toString());
    await _set('pin_salt', salt);
    await _set('pin_fail', 0);
  }

  Future<bool> verifyPin(String pin) async {
    final lockUntil = _get<int>('pin_lock_until') ?? 0;
    if (DateTime.now().millisecondsSinceEpoch < lockUntil) return false;
    final hash = _get<String>('pin_hash');
    final salt = _get<String>('pin_salt');
    if (hash == null || salt == null) return false;
    final ok = sha256.convert(utf8.encode('$salt::$pin')).toString() == hash;
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

  bool shouldRelock({Duration timeout = const Duration(minutes: 5)}) =>
      DateTime.now().difference(lastActiveAt) > timeout;

  void touch() => lastActiveAt = DateTime.now();
}
