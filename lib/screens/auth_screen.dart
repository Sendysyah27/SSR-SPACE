import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ssr_space/core/saas/auth_service.dart';
import 'package:ssr_space/core/saas/supabase_config.dart';
import 'package:ssr_space/core/session/session_service.dart';
import 'package:ssr_space/screens/splash_screen.dart';

class AuthScreen extends StatefulWidget {
  final SessionService session;
  const AuthScreen({super.key, required this.session});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final emailC = TextEditingController();
  final passC = TextEditingController();
  bool isLogin = true;
  bool loading = false;
  String? err;

  Future<void> _submit() async {
    setState(() { loading = true; err = null; });
    try {
      final auth = AuthService();
      AuthResponse res;
      if (isLogin) {
        res = await auth.signIn(emailC.text.trim(), passC.text);
      } else {
        res = await auth.signUp(emailC.text.trim(), passC.text);
      }
      if (res.session != null || SupabaseConfig.client.auth.currentUser != null) {
        if (!mounted) return;
        Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (_) => SplashScreen(session: widget.session, skipAuth: true)));
      } else {
        setState(() => err = 'Cek email — verifikasi mungkin diperlukan.');
      }
    } on AuthException catch (e) {
      setState(() => err = e.message);
    } catch (e) {
      setState(() => err = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(isLogin ? 'Masuk SSR SPACE' : 'Daftar SSR SPACE')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          TextField(controller: emailC, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email')),
          TextField(controller: passC, obscureText: true, decoration: const InputDecoration(labelText: 'Password')),
          if (err != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(err!, style: const TextStyle(color: Colors.red))),
          const SizedBox(height: 12),
          loading
              ? const CircularProgressIndicator()
              : ElevatedButton(onPressed: _submit, child: Text(isLogin ? 'Masuk' : 'Daftar')),
          TextButton(
            onPressed: () => setState(() => isLogin = !isLogin),
            child: Text(isLogin ? 'Belum punya akun? Daftar' : 'Sudah punya akun? Masuk'),
          ),
        ]),
      ),
    );
  }
}
