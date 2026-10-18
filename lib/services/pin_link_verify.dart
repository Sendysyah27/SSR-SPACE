import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ssr_space/services/auth_link_parse.dart';
import 'package:ssr_space/services/error_reporter.dart';
import 'package:ssr_space/services/supabase_config.dart';

/// Skema + host callback magic-link ganti PIN.
/// Wajib didaftarkan juga di:
/// - Supabase Dashboard -> Auth -> URL Configuration -> Additional Redirect URLs
/// - intent-filter Android (diinject CI di apk.yml, `android/` tak di-commit)
const pinLinkScheme = 'com.ssr.space.ssrspace';
const pinLinkHost = 'login-callback';
String get pinLinkCallback => '$pinLinkScheme://$pinLinkHost';

/// True setelah link verifikasi berhasil ditukar sesi. Di-reset tiap kirim
/// link baru dan setelah PIN tersimpan.
final pinLinkVerified = ValueNotifier<bool>(false);

/// True setelah link lupa-password (type=recovery) berhasil ditukar sesi.
/// Splash/MainShell mengarahkannya ke layar password baru. Di-reset setelah
/// password tersimpan (jangan tertinggal true → loop layar password).
final passwordRecovery = ValueNotifier<bool>(false);

/// Tangkap deep-link callback auth -> tukar token_hash jadi sesi.
/// Fail-closed: hanya type=magiclink (PIN) dan type=recovery (password)
/// yang diterima. Tak pernah melempar.
class PinLinkVerify {
  static bool _started = false;

  static void initOnce() {
    if (_started) return;
    _started = true;
    try {
      final links = AppLinks();
      links.uriLinkStream.listen(
        (uri) {
          unawaited(consume(uri));
        },
        onError: (_) {},
      );
    } catch (err, st) {
      ErrorReporter.capture(err, st, context: 'pin_link_init');
    }
  }

  static Future<bool> consume(Uri uri) async {
    try {
      if (uri.scheme != pinLinkScheme || uri.host != pinLinkHost) {
        return false;
      }
      final t = parseAuthLinkToken(uri);
      if (t == null) return false;
      if (t.type == 'magiclink') {
        final res = await SupabaseConfig.client.auth.verifyOTP(
          tokenHash: t.tokenHash,
          type: OtpType.magiclink,
        );
        final ok = res.session != null;
        if (ok) pinLinkVerified.value = true;
        return ok;
      }
      if (t.type == 'recovery') {
        final res = await SupabaseConfig.client.auth.verifyOTP(
          tokenHash: t.tokenHash,
          type: OtpType.recovery,
        );
        final ok = res.session != null;
        if (ok) passwordRecovery.value = true;
        return ok;
      }
      return false;
    } catch (err, st) {
      ErrorReporter.capture(err, st, context: 'pin_link_consume');
      return false;
    }
  }

  static void reset() {
    pinLinkVerified.value = false;
    passwordRecovery.value = false;
  }
}
