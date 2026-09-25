import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ssr_space/services/supabase_config.dart';

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
}
