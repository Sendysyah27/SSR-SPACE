import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ssr_space/services/auth_service.dart';
import 'package:ssr_space/services/supabase_config.dart';
import 'package:ssr_space/services/session_service.dart';
import 'package:ssr_space/theme/app_icons.dart';
import 'package:ssr_space/theme/app_theme.dart';
import 'package:ssr_space/theme/dribbble_tokens.dart';
import 'package:ssr_space/screens/auth/splash_screen.dart';
import 'package:ssr_space/screens/auth/set_password_screen.dart';
import 'package:ssr_space/services/pin_link_verify.dart';
import 'package:ssr_space/widgets/premium/premium_button.dart';
import 'package:ssr_space/widgets/drib_card.dart';
import 'package:ssr_space/utils/strings.dart';

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
  StreamSubscription<AuthState>? _authSub;
  bool _navigated = false;

  void _goSplash() {
    if (_navigated || !mounted) return;
    _navigated = true;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => SplashScreen(session: widget.session, skipAuth: true),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    // Sesi OAuth browser datang via deep-link (plugin tukar otomatis):
    // dengar sekali, navigasi sekali.
    _authSub = AuthService().authChanges().listen((s) {
      if (s.session != null) _goSplash();
    });
    passwordRecovery.addListener(_onRecovery);
  }

  @override
  void dispose() {
    _authSub?.cancel();
    passwordRecovery.removeListener(_onRecovery);
    emailC.dispose();
    passC.dispose();
    super.dispose();
  }

  /// App dibuka hangat saat link recovery diketuk: langsung ke password baru.
  void _onRecovery() {
    if (passwordRecovery.value && mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => SetPasswordScreen(session: widget.session),
        ),
      );
    }
  }

  String _friendly(Object e) {
    final s = e.toString();
    if (s.contains('Failed host lookup')) {
      return tr('au_err_server').replaceFirst('{h}', SupabaseConfig.host);
    }
    if (s.contains('SocketException') ||
        s.contains('ClientException') ||
        s.contains('Connection')) {
      return tr('au_err_net');
    }
    if (s.contains('Email not confirmed')) {
      return tr('au_err_unconfirmed');
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
            err = tr('au_err_empty');
            needVerify = true;
          });
          return;
        }
        _goSplash();
      } else {
        final res = await auth.signUp(emailC.text.trim(), passC.text);
        if (res.session == null) {
          setState(() {
            info = tr('au_created');
            isLogin = true;
            needVerify = true;
          });
          return;
        }
        _goSplash();
      }
    } catch (e) {
      final m = _friendly(e);
      setState(() {
        err = m;
        final raw = e.toString();
        if (raw.contains('Email not confirmed') ||
            m.contains('verifikasi') ||
            m.contains('not verified') ||
            m.contains('confirm')) {
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
      setState(() => info = tr('au_resent'));
    } catch (e) {
      setState(() => err = _friendly(e));
    }
  }

  /// Login Google: native dulu; false = browser dibuka (sesi datang
  /// via listener). Batal = diam di form.
  Future<void> _google() async {
    setState(() {
      loading = true;
      err = null;
      info = null;
    });
    try {
      final native = await AuthService().signInWithGoogle();
      if (native) _goSplash();
    } on GoogleSignInCancelled {
      // User batal pilih akun: diam, tetap di form.
    } catch (e) {
      if (!mounted) return;
      setState(() => err = _friendly(e));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }
  Future<void> _forgot() async {
    // Lupa password: email reset, link kembali via deep-link app.
    final email = emailC.text.trim();
    if (email.isEmpty) {
      setState(() {
        err = tr('au_need_email');
        info = null;
      });
      return;
    }
    setState(() {
      loading = true;
      err = null;
      info = null;
    });
    try {
      await AuthService().resetPassword(email);
      if (!mounted) return;
      setState(() => info = tr('au_reset_sent'));
    } catch (e) {
      if (!mounted) return;
      setState(() => err = _friendly(e));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DribTokens.bg,
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
          onForgot: _forgot,
          onGoogle: _google,
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
  final Future<void> Function() onForgot;
  final Future<void> Function() onGoogle;
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
    required this.onForgot,
    required this.onGoogle,
    required this.onToggleMode,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(SsrSpace.lg),
      children: [
        const _AuthHeader(),
        const SizedBox(height: SsrSpace.md),
        DribCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _AuthFields(emailC: emailC, passC: passC, onSubmit: onSubmit),
              _AuthMessages(
                err: err,
                info: info,
                showResend: needVerify && emailC.text.isNotEmpty,
                onResend: onResend,
              ),
            ],
          ),
        ),
        _AuthActions(
          isLogin: isLogin,
          loading: loading,
          onSubmit: onSubmit,
          onForgot: onForgot,
          onGoogle: onGoogle,
          onToggleMode: onToggleMode,
        ),
      ],
    );
  }
}

/// Kopi halaman auth: jarak atas + wordmark "SSR SPACE" + subjudul.
class _AuthHeader extends StatelessWidget {
  const _AuthHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: SsrSpace.xxl),
        Text(tr('au_title'), style: Theme.of(context).textTheme.displaySmall),
        const SizedBox(height: SsrSpace.sm),
        Text(
          tr('au_sub'),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).textTheme.bodySmall?.color,
          ),
        ),
        const SizedBox(height: SsrSpace.xxl),
      ],
    );
  }
}

/// Field email + password (sandi tersembunyi, submit lewat tombol keyboard).
class _AuthFields extends StatelessWidget {
  final TextEditingController emailC;
  final TextEditingController passC;
  final Future<void> Function() onSubmit;

  const _AuthFields({
    required this.emailC,
    required this.passC,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    const labelStyle = TextStyle(color: Colors.white70, fontSize: 13);
    const inputStyle = TextStyle(color: Colors.white);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: DribTokens.balanceGradient,
        borderRadius:
            BorderRadius.circular(DribTokens.cardRadius),
        boxShadow: DribTokens.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: emailC,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.email],
            style: inputStyle,
            decoration: InputDecoration(
              labelText: tr('au_email'),
              labelStyle: labelStyle,
            ),
          ),
          const SizedBox(height: SsrSpace.md),
          TextField(
            controller: passC,
            obscureText: true,
            onSubmitted: (_) => onSubmit(),
            style: inputStyle,
            decoration: InputDecoration(
              labelText: tr('au_pass'),
              labelStyle: labelStyle,
            ),
          ),
        ],
      ),
    );
  }
}

/// Pesan error/info + tombol kirim ulang verifikasi (bila perlu).
class _AuthMessages extends StatelessWidget {
  final String? err;
  final String? info;
  final bool showResend;
  final Future<void> Function() onResend;

  const _AuthMessages({
    required this.err,
    required this.info,
    required this.showResend,
    required this.onResend,
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
        border: Border.all(color: fg.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          DuoIcon(icon, size: 16, color: fg),
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
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (err != null) ...[
          const SizedBox(height: SsrSpace.md),
          _messageRow(
            text: err!,
            bg: scheme.error.withValues(alpha: 0.08),
            fg: scheme.error,
            icon: AppIcons.warning,
          ),
        ],
        if (info != null) ...[
          const SizedBox(height: SsrSpace.md),
          _messageRow(
            text: info!,
            bg: scheme.primary.withValues(alpha: 0.08),
            fg: scheme.primary,
            icon: AppIcons.mail,
          ),
        ],
        if (showResend)
          TextButton(
            onPressed: onResend,
            child: Text(tr('au_resend')),
          ),
      ],
    );
  }
}

/// Tombol submit utama + tautan ganti mode masuk/daftar.
class _AuthActions extends StatelessWidget {
  final bool isLogin;
  final bool loading;
  final Future<void> Function() onSubmit;
  final Future<void> Function() onForgot;
  final Future<void> Function() onGoogle;
  final VoidCallback onToggleMode;

  const _AuthActions({
    required this.isLogin,
    required this.loading,
    required this.onSubmit,
    required this.onForgot,
    required this.onGoogle,
    required this.onToggleMode,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: SsrSpace.lg),
        PremiumButton(
          label: isLogin ? tr('au_login') : tr('au_register'),
          loading: loading,
          onPressed: onSubmit,
          gradient: const LinearGradient(
            colors: [DribTokens.primary, DribTokens.primary],
          ),
              foreground: DribTokens.navy,
        ),
        const SizedBox(height: SsrSpace.sm),
        OutlinedButton(
          onPressed: loading ? null : onGoogle,
          child: Text(tr('au_google')),
        ),
        if (isLogin)
          TextButton(
            onPressed: onForgot,
            child: Text(tr('au_forgot')),
          ),
        TextButton(
          onPressed: onToggleMode,
          child: Text(
            isLogin ? tr('au_to_register') : tr('au_to_login'),
          ),
        ),
      ],
    );
  }
}
