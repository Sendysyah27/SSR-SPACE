import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ssr_space/core/saas/supabase_config.dart';
import 'package:ssr_space/core/session/session_service.dart';
import 'package:ssr_space/core/theme/app_theme.dart';
import 'package:ssr_space/screens/onboarding_screen.dart';
import 'package:ssr_space/screens/lock_screen.dart';
import 'package:ssr_space/screens/main_shell.dart';
import 'package:ssr_space/screens/auth_screen.dart';
import 'package:ssr_space/screens/org_switcher_screen.dart';
import 'package:ssr_space/widgets/primary_button.dart';
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
      await Future.delayed(const Duration(milliseconds: 800));
      if (!mounted) return;
      if (SupabaseConfig.isConfigured) {
        if (!widget.skipAuth &&
            SupabaseConfig.client.auth.currentSession == null) {
          return _go(AuthScreen(session: widget.session));
        }
        final prefs = await SharedPreferences.getInstance();
        if ((prefs.getString('active_org_id') ?? '').isEmpty) {
          return _go(OrgSwitcherScreen(session: widget.session));
        }
      }
      if (!mounted) return;
      if (widget.session.isFirstRun) {
        return _go(OnboardingScreen(session: widget.session));
      } else if (widget.session.hasPin) {
        return _go(LockScreen(session: widget.session));
      }
      return _go(MainShell(session: widget.session));
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
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedOpacity(
                        opacity: _visible ? 1 : 0,
                        duration: SsrMotion.base,
                        curve: SsrMotion.curve,
                        child: Column(
                          children: [
                            Text(
                              'SSR SPACE',
                              style: Theme.of(context).textTheme.displaySmall,
                            ),
                            const SizedBox(height: SsrSpace.sm),
                            Text(
                              'Buku kas harian.',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: SsrSpace.xxl),
                      const LoadingView(label: 'Menyiapkan buku kas...'),
                    ],
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.cloud_off_outlined,
                        size: 40,
                        color: SsrColors.secondary,
                      ),
                      const SizedBox(height: SsrSpace.md),
                      Text(
                        'Gagal menyiapkan buku kas. Periksa koneksi lalu coba lagi.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: SsrSpace.lg),
                      PrimaryButton(label: 'Coba lagi', onPressed: _boot),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
