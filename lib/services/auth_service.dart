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

class AuthService {
  SupabaseClient get _c => SupabaseConfig.client;

  Session? get session => _c.auth.currentSession;
  User? get user => _c.auth.currentUser;
  bool get isLoggedIn => session != null;

  Stream<AuthState> authChanges() => _c.auth.onAuthStateChange;

  Future<AuthResponse> signUp(String email, String password) =>
      _c.auth.signUp(email: email, password: password);

  Future<AuthResponse> signIn(String email, String password) =>
      _c.auth.signInWithPassword(email: email, password: password);

  Future<void> signOut() => _c.auth.signOut();

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
      final acct =
          await GoogleSignIn(scopes: const ['email']).signIn();
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
      return res.session != null;
    } on GoogleSignInCancelled {
      rethrow;
    } catch (_) {
      await _c.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: pinLinkCallback,
      );
      return false;
    }
  }
}
