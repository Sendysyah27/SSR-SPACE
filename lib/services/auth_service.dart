import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart'
    hide User, OAuthProvider;
import 'package:ssr_space/services/firebase_ai_factory.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ssr_space/services/supabase_config.dart';
import 'package:ssr_space/services/pin_link_verify.dart';

/// User membatalkan pilih akun Google (bukan error config).
class GoogleSignInCancelled implements Exception {
  const GoogleSignInCancelled();
  @override
  String toString() => 'GoogleSignInCancelled';
}

/// Web client ID Google Cloud (dart-define GOOGLE_WEB_CLIENT_ID, dari
/// secret CI). Wajib untuk native: tanpa ini idToken beraudien klien
/// Android dan ditolak Supabase → jatuh ke browser. Kosong = perilaku lama.
const googleWebClientId = String.fromEnvironment(
  'GOOGLE_WEB_CLIENT_ID',
  defaultValue: '',
);

class AuthService {
  SupabaseClient get _c => SupabaseConfig.client;

  Session? get session => _c.auth.currentSession;
  User? get user => _c.auth.currentUser;
  bool get isLoggedIn => session != null;

  Stream<AuthState> authChanges() => _c.auth.onAuthStateChange;

  Future<AuthResponse> signUp(String email, String password) async {
    final res = await _c.auth.signUp(email: email, password: password);
    // Top-up sesi Firebase (anonim) agar AI parser ikut hidup untuk
    // user email — fail-open, sesi Supabase tetap sumber kebenaran.
    await ensureFirebaseSession();
    return res;
  }

  Future<AuthResponse> signIn(String email, String password) async {
    final res = await _c.auth.signInWithPassword(
      email: email,
      password: password,
    );
    await ensureFirebaseSession();
    return res;
  }

  Future<void> signOut() async {
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {}
    await _c.auth.signOut();
  }

  Future<void> resendVerification(String email) =>
      _c.auth.resend(type: OtpType.signup, email: email);

  /// Kirim email lupa-password. Link kembali via deep-link app yang sama
  /// dengan magic-link PIN (nol config Dashboard baru).
  Future<void> resetPassword(String email) =>
      _c.auth.resetPasswordForEmail(email, redirectTo: pinLinkCallback);

  /// Simpan password baru (dipakai setelah sesi recovery terbentuk).
  Future<void> updatePassword(String password) =>
      _c.auth.updateUser(UserAttributes(password: password));

  /// Login Google: native dulu (pilih akun, tanpa browser) → idToken
  /// ditukar sesi Supabase. True = sesi langsung jadi.
  /// Gagal config (tanpa google-services.json/SHA-1) → fallback browser
  /// OAuth (redirectTo deep-link, sesi via onAuthStateChange) → false.
  /// User batal pilih akun → lempar [GoogleSignInCancelled] (UI diam).
  Future<bool> signInWithGoogle() async {
    try {
      final acct = await GoogleSignIn(
        scopes: const ['email'],
        serverClientId:
            googleWebClientId.isEmpty ? null : googleWebClientId,
      ).signIn();
      if (acct == null) throw const GoogleSignInCancelled();
      final gauth = await acct.authentication;
      final idToken = gauth.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw StateError('Google tanpa idToken');
      }
      final res = await _c.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: gauth.accessToken,
      );
      // Link sesi Firebase untuk AI parser struk (fail-open: gagal
      // link = AI mati, sesi Supabase tetap sumber kebenaran).
      // Tanpa idToken (fallback browser) = top-up anonim agar AI tetap
      // hidup untuk user Google juga.
      await ensureFirebaseSession(
        idToken: idToken,
        accessToken: gauth.accessToken,
      );
      return res.session != null;
    } on GoogleSignInCancelled {
      rethrow;
    } catch (e) {
      // Alasan native gagal dicatat untuk diagnosis (adb logcat):
      // config (tanpa google-services/SHA-1/audien) = wajar → browser.
      debugPrint('google native gagal, fallback browser: $e');
      await _c.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: pinLinkCallback,
      );
      return false;
    }
  }
}
