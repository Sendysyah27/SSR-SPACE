import 'package:flutter/material.dart';
import 'package:ssr_space/services/auth_service.dart';
import 'package:ssr_space/services/password_reset_logic.dart';
import 'package:ssr_space/services/pin_link_verify.dart';
import 'package:ssr_space/services/session_service.dart';
import 'package:ssr_space/theme/app_theme.dart';
import 'package:ssr_space/theme/app_icons.dart';
import 'package:ssr_space/theme/dribbble_tokens.dart';
import 'package:ssr_space/screens/auth/splash_screen.dart';
import 'package:ssr_space/utils/strings.dart';
import 'package:ssr_space/widgets/primary_button.dart';

/// Layar password baru setelah link lupa-password diketuk (type=recovery).
/// Dibuka Splash/MainShell saat `passwordRecovery` true. Sukses → flag
/// di-reset lalu alur normal (kunci/PIN/beranda) via Splash.
class SetPasswordScreen extends StatefulWidget {
  final SessionService session;
  const SetPasswordScreen({super.key, required this.session});
  @override
  State<SetPasswordScreen> createState() => _SetPasswordScreenState();
}

class _SetPasswordScreenState extends State<SetPasswordScreen> {
  final p1C = TextEditingController();
  final p2C = TextEditingController();
  bool loading = false;
  String? err;

  @override
  void dispose() {
    p1C.dispose();
    p2C.dispose();
    super.dispose();
  }

  String _label(String? code) {
    if (code == 'mismatch') return tr('np_mismatch');
    return tr('np_short');
  }

  Future<void> _submit() async {
    final code = newPasswordError(p1C.text, p2C.text);
    if (code != null) {
      setState(() => err = _label(code));
      return;
    }
    setState(() {
      loading = true;
      err = null;
    });
    try {
      await AuthService().updatePassword(p1C.text);
      PinLinkVerify.reset();
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => SplashScreen(
            session: widget.session,
            skipAuth: true,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => err = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DribTokens.bgOf(context),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(SsrSpace.xxl),
          children: [
            const SizedBox(height: SsrSpace.xxl),
            Text(
              tr('np_title'),
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    color: DribTokens.navy,
                    fontWeight: FontWeight.w800,
                    fontSize: 23,
                  ),
            ),
            const SizedBox(height: SsrSpace.sm),
            Text(
              tr('np_sub'),
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: DribTokens.textSecondary),
            ),
            const SizedBox(height: SsrSpace.xxl),
            TextField(
              controller: p1C,
              obscureText: true,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.newPassword],
              decoration: InputDecoration(
                labelText: tr('np_pass1'),
                prefixIcon: const Icon(
                  AppIcons.lock,
                  size: 18,
                  color: DribTokens.textSecondary,
                ),
              ),
            ),
            const SizedBox(height: SsrSpace.md),
            TextField(
              controller: p2C,
              obscureText: true,
              onSubmitted: (_) => _submit(),
              autofillHints: const [AutofillHints.newPassword],
              decoration: InputDecoration(
                labelText: tr('np_pass2'),
                prefixIcon: const Icon(
                  AppIcons.lock,
                  size: 18,
                  color: DribTokens.textSecondary,
                ),
              ),
            ),
            if (err != null) ...[
              const SizedBox(height: SsrSpace.md),
              Text(err!, style: const TextStyle(color: DribTokens.errorText, fontSize: 13)),
            ],
            const SizedBox(height: SsrSpace.lg),
            PrimaryButton(
              label: tr('np_save'),
              loading: loading,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}
