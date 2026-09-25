import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ssr_space/services/auth_service.dart';
import 'package:ssr_space/services/supabase_config.dart';
import 'package:ssr_space/services/session_service.dart';
import 'package:ssr_space/theme/app_theme.dart';
import 'package:ssr_space/screens/auth/splash_screen.dart';
import 'package:ssr_space/widgets/primary_button.dart';

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

  @override
  void dispose() {
    emailC.dispose();
    passC.dispose();
    super.dispose();
  }

  String _friendly(Object e) {
    final s = e.toString();
    if (s.contains('Failed host lookup')) {
      return 'Tidak bisa menghubungi server (${SupabaseConfig.host}). Cek internet / matikan VPN-adblock, lalu Coba Lagi.';
    }
    if (s.contains('SocketException') ||
        s.contains('ClientException') ||
        s.contains('Connection')) {
      return 'Jaringan bermasalah. Cek internet lalu Coba Lagi.';
    }
    if (s.contains('Email not confirmed')) {
      return 'Email belum verifikasi. Cek inbox lalu klik link, atau kirim ulang di bawah.';
    }
    if (e is AuthException) return e.message;
    return s;
  }

  Future<void> _submit() async {
    setState(() {
      loading = true;
      err = null;
      info = null;
      needVerify = false;
    });
    try {
      final auth = AuthService();
      if (isLogin) {
        final res = await auth.signIn(emailC.text.trim(), passC.text);
        if (res.session == null) {
          setState(() {
            err = 'Masuk gagal, sesi kosong. Kalau baru daftar, verifikasi email dulu.';
            needVerify = true;
          });
          return;
        }
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) =>
                SplashScreen(session: widget.session, skipAuth: true),
          ),
        );
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
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) =>
                SplashScreen(session: widget.session, skipAuth: true),
          ),
        );
      }
    } catch (e) {
      final m = _friendly(e);
      setState(() {
        err = m;
        if (m.contains('verifikasi') || m.contains('confirm')) {
          needVerify = true;
        }
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
      body: SafeArea(
        child: _AuthForm(
          emailC: emailC,
          passC: passC,
          isLogin: isLogin,
          loading: loading,
          err: err,
          info: info,
          needVerify: needVerify,
          onSubmit: _submit,
          onResend: _resend,
          onToggleMode: () => setState(() => isLogin = !isLogin),
        ),
      ),
    );
  }
}

/// Form login/daftar: brand, field email/sandi, pesan error/info,
/// kirim ulang verifikasi, dan tombol submit + ganti mode.
class _AuthForm extends StatelessWidget {
  final TextEditingController emailC;
  final TextEditingController passC;
  final bool isLogin;
  final bool loading;
  final String? err;
  final String? info;
  final bool needVerify;
  final Future<void> Function() onSubmit;
  final Future<void> Function() onResend;
  final VoidCallback onToggleMode;

  const _AuthForm({
    required this.emailC,
    required this.passC,
    required this.isLogin,
    required this.loading,
    required this.err,
    required this.info,
    required this.needVerify,
    required this.onSubmit,
    required this.onResend,
    required this.onToggleMode,
  });

  Widget _messageRow({
    required String text,
    required Color bg,
    required Color fg,
    required IconData icon,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: SsrSpace.md,
        vertical: SsrSpace.md,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(SsrRadius.chip),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: fg),
          const SizedBox(width: SsrSpace.sm),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: fg, fontSize: 13, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(SsrSpace.xxl),
      children: [
        const SizedBox(height: SsrSpace.xxl),
        Text('SSR SPACE', style: Theme.of(context).textTheme.displaySmall),
        const SizedBox(height: SsrSpace.sm),
        Text(
          'Masuk untuk lanjut catat harian.',
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: SsrColors.secondary),
        ),
        const SizedBox(height: SsrSpace.xxl),
        TextField(
          controller: emailC,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.email],
          decoration: const InputDecoration(labelText: 'Email'),
        ),
        const SizedBox(height: SsrSpace.md),
        TextField(
          controller: passC,
          obscureText: true,
          onSubmitted: (_) => onSubmit(),
          decoration: const InputDecoration(labelText: 'Password'),
        ),
        if (err != null) ...[
          const SizedBox(height: SsrSpace.md),
          _messageRow(
            text: err!,
            bg: SsrColors.dangerSoft,
            fg: SsrColors.danger,
            icon: Icons.error_outline,
          ),
        ],
        if (info != null) ...[
          const SizedBox(height: SsrSpace.md),
          _messageRow(
            text: info!,
            bg: SsrColors.accentSoft,
            fg: SsrColors.accent,
            icon: Icons.mark_email_read_outlined,
          ),
        ],
        if (needVerify && emailC.text.isNotEmpty)
          TextButton(
            onPressed: onResend,
            child: const Text('Kirim ulang verifikasi'),
          ),
        const SizedBox(height: SsrSpace.lg),
        PrimaryButton(
          label: isLogin ? 'Masuk' : 'Daftar',
          loading: loading,
          onPressed: onSubmit,
        ),
        TextButton(
          onPressed: onToggleMode,
          child: Text(
            isLogin ? 'Belum punya akun? Daftar' : 'Sudah punya akun? Masuk',
          ),
        ),
      ],
    );
  }
}
