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
  String? info;
  bool needVerify = false;

  String _friendly(Object e) {
    final s = e.toString();
    if (s.contains('Failed host lookup')) {
      return 'Tidak bisa menghubungi server (${SupabaseConfig.host}). Cek internet / matikan VPN-adblock, lalu Coba Lagi.';
    }
    if (s.contains('SocketException') || s.contains('ClientException') || s.contains('Connection')) {
      return 'Jaringan bermasalah. Cek internet lalu Coba Lagi.';
    }
    if (s.contains('Email not confirmed')) {
      return 'Email belum verifikasi. Cek inbox lalu klik link, atau kirim ulang di bawah.';
    }
    if (e is AuthException) return e.message;
    return s;
  }

  Future<void> _submit() async {
    setState(() { loading = true; err = null; info = null; needVerify = false; });
    try {
      final auth = AuthService();
      if (isLogin) {
        final res = await auth.signIn(emailC.text.trim(), passC.text);
        if (res.session == null) {
          setState(() {
            err = 'Masuk gagal — sesi kosong. Kalau baru daftar, verifikasi email dulu.';
            needVerify = true;
          });
          return;
        }
        if (!mounted) return;
        Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (_) => SplashScreen(session: widget.session, skipAuth: true)));
      } else {
        final res = await auth.signUp(emailC.text.trim(), passC.text);
        if (res.session == null) {
          setState(() {
            info = 'Akun dibuat. Cek email, klik link verifikasi, lalu Masuk.';
            isLogin = true;
            needVerify = true;
          });
          return;
        }
        if (!mounted) return;
        Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (_) => SplashScreen(session: widget.session, skipAuth: true)));
      }
    } catch (e) {
      final m = _friendly(e);
      setState(() {
        err = m;
        if (m.contains('verifikasi') || m.contains('confirm')) needVerify = true;
      });
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _resend() async {
    try {
      await AuthService().resendVerification(emailC.text.trim());
      setState(() => info = 'Link verifikasi dikirim ulang. Cek inbox/spam.');
    } catch (e) {
      setState(() => err = _friendly(e));
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
          if (info != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(info!, style: const TextStyle(color: Colors.green))),
          if (needVerify && emailC.text.isNotEmpty)
            TextButton(onPressed: _resend, child: const Text('Kirim ulang verifikasi')),
          const SizedBox(height: 12),
          loading
              ? const CircularProgressIndicator()
              : ElevatedButton(onPressed: _submit, child: Text(isLogin ? 'Masuk' : 'Daftar')),
          TextButton(
            onPressed: () => setState(() => isLogin = !isLogin),
            child: Text(isLogin ? 'Belum punya akun? Daftar' : 'Sudah punya akun? Masuk'),
          ),
          const Spacer(),
          Text('server: ${SupabaseConfig.host}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ]),
      ),
    );
  }
}
