import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

/// Kunci biometrik (sidik jari/face unlock) sebagai alternatif PIN.
/// Seluruh API fail-closed: batal/gagal/tak didukung = false, PIN tetap jalan.
class BiometricAuth {
  BiometricAuth._();
  static final _auth = LocalAuthentication();

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
  static Future<bool> unlock(String reason) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
    } on PlatformException catch (_) {
      return false;
    } catch (_) {
      return false;
    }
  }
}
