import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

/// Kunci biometrik (sidik jari/face unlock) sebagai alternatif PIN.
/// Batal user = false diam-diam; error config/perangkat dicatat di
/// [lastError] supaya UI bisa bicara jujur (jangan telan diam-diam).
class BiometricAuth {
  BiometricAuth._();
  static final _auth = LocalAuthentication();

  /// Kode error terakhir ('code: message', dipotong) atau null bila
  /// percobaan terakhir batal/sukses. Di-reset tiap unlock().
  static String? lastError;

  /// True bila HP mampu + ada biometrik terdaftar. Tak pernah melempar.
  static Future<bool> isSupported() async {
    try {
      if (!await _auth.isDeviceSupported()) return false;
      return await _auth.canCheckBiometrics;
    } on PlatformException catch (_) {
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Minta kunci biometrik dengan alasan [reason] (ditampilkan sistem).
  /// True = sukses. False = batal (diam) atau error ([lastError] terisi).
  static Future<bool> unlock(String reason) async {
    lastError = null;
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
    } on PlatformException catch (e) {
      // Mis. no_fragment_activity (MainActivity salah tipe) — wajib
      // terlihat, bukan false sunyi.
      lastError = '${e.code}: ${e.message ?? ''}'.trim();
      if (lastError!.length > 120) lastError = lastError!.substring(0, 120);
      return false;
    } catch (e) {
      lastError = '$e';
      if (lastError!.length > 120) lastError = lastError!.substring(0, 120);
      return false;
    }
  }
}
