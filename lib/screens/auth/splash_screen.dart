import 'package:flutter/material.dart';
import 'package:app_links/app_links.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ssr_space/services/pin_link_verify.dart';
import 'package:ssr_space/services/supabase_config.dart';
import 'package:ssr_space/services/session_service.dart';
import 'package:ssr_space/theme/app_icons.dart';
import 'package:ssr_space/theme/app_theme.dart';
import 'package:ssr_space/screens/auth/onboarding_screen.dart';
import 'package:ssr_space/screens/auth/lock_screen.dart';
import 'package:ssr_space/screens/auth/set_password_screen.dart';
import 'package:ssr_space/screens/shell/main_shell.dart';
import 'package:ssr_space/screens/auth/auth_screen.dart';
import 'package:ssr_space/screens/auth/intro_consent_screen.dart';
import 'package:ssr_space/screens/workspace/org_switcher_screen.dart';
import 'package:ssr_space/widgets/primary_button.dart';
import 'package:ssr_space/utils/strings.dart';
import 'package:ssr_space/widgets/state_views.dart';

class SplashScreen extends StatefulWidget {
  final SessionService session;
  final bool skipAuth;
  const SplashScreen({super.key, required this.session, this.skipAuth = false});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool failed = false;
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _visible = true);
    });
    _boot();
  }

  Future<void> _go(Widget w) async {
    if (!mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => w));
  }

  Future<void> _boot() async {
    setState(() => failed = false);
    try {
      await Future.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;
      // Link awal (mis. ketukan email lupa-password): tukar dulu sebelum
      // cek sesi — stream AppLinks bisa datang setelah boot lewat.
      try {
        final initial = await AppLinks().getInitialLink();
        if (initial != null) await PinLinkVerify.consume(initial);
      } catch (_) {}
      if (passwordRecovery.value) {
        await _go(SetPasswordScreen(session: widget.session));
        return;
      }
      if (SupabaseConfig.isConfigured) {
        if (!widget.skipAuth &&
            SupabaseConfig.client.auth.currentSession == null) {
          await _go(AuthScreen(session: widget.session));
          return;
        }
      }
      final prefs = await SharedPreferences.getInstance();
      if ((prefs.getString('consent_v1') ?? '').isEmpty) {
        await _go(
          IntroConsentScreen(
            session: widget.session,
            skipAuth: widget.skipAuth,
          ),
        );
        return;
      }
      if (SupabaseConfig.isConfigured) {
        if ((prefs.getString('active_org_id') ?? '').isEmpty) {
          await _go(OrgSwitcherScreen(session: widget.session));
          return;
        }
      }
      if (!mounted) return;
      if (widget.session.isFirstRun) {
        await _go(OnboardingScreen(session: widget.session));
        return;
      } else if (widget.session.hasPin) {
        await _go(LockScreen(session: widget.session));
        return;
      }
      await _go(MainShell(session: widget.session));
    } catch (_) {
      if (mounted) setState(() => failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: SsrSpace.xxl),
            child: !failed
                ? _SplashLoading(visible: _visible)
                : _SplashError(onRetry: _boot),
          ),
        ),
      ),
    );
  }
}

/// Bagian splash saat boot: wordmark + tagline (fade-in) + indikator muat.
class _SplashLoading extends StatelessWidget {
  final bool visible;
  const _SplashLoading({required this.visible});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: SsrMotion.base,
          curve: SsrMotion.curve,
          child: Column(
            children: [
              Text(
                tr('au_title'),
                style: Theme.of(context).textTheme.displaySmall,
              ),
              const SizedBox(height: SsrSpace.md),
              Container(width: 56, height: 1, color: AppColors.gold),
              const SizedBox(height: SsrSpace.md),
              Text(
                tr('sp_tagline'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        const SizedBox(height: SsrSpace.xxl),
        LoadingView(label: tr('sp_loading')),
      ],
    );
  }
}

/// Bagian splash saat gagal: ikon offline + pesan + tombol coba lagi.
class _SplashError extends StatelessWidget {
  final VoidCallback onRetry;
  const _SplashError({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        DuoIcon(
          AppIcons.cloudOff,
          size: 40,
          color: Theme.of(context).textTheme.bodySmall?.color,
        ),
        const SizedBox(height: SsrSpace.md),
        Text(
          tr('sp_err'),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: SsrSpace.lg),
        PrimaryButton(label: tr('retry'), onPressed: onRetry),
      ],
    );
  }
}
