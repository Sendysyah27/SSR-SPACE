import 'package:flutter/material.dart';
import 'package:ssr_space/services/app_settings.dart';
import 'package:ssr_space/services/session_service.dart';
import 'package:ssr_space/screens/auth/splash_screen.dart';
import 'package:ssr_space/theme/app_theme.dart';
import 'package:ssr_space/theme/dribbble_tokens.dart';
import 'package:ssr_space/widgets/primary_button.dart';
import 'package:ssr_space/utils/strings.dart';

class ThemeStepScreen extends StatefulWidget {
  final SessionService session;
  final bool skipAuth;
  const ThemeStepScreen({
    super.key,
    required this.session,
    this.skipAuth = false,
  });
  @override
  State<ThemeStepScreen> createState() => _ThemeStepScreenState();
}

class _ThemeStepScreenState extends State<ThemeStepScreen> {
  static const _iconAuto = IconData(0xE566, fontFamily: SsrFonts.icon);
  static const _iconTerang = IconData(0xE5F4, fontFamily: SsrFonts.icon);
  static const _iconGelap = IconData(0xE330, fontFamily: SsrFonts.icon);
  static const _iconCheck = IconData(0xE184, fontFamily: SsrFonts.icon);

  late String _pilih;

  @override
  void initState() {
    super.initState();
    final c = themeChoice.value;
    _pilih = (c == 'terang' || c == 'gelap' || c == 'otomatis')
        ? c
        : 'otomatis';
  }

  void _pilihOption(String v) {
    setState(() => _pilih = v);
    setThemeChoice(v);
  }

  void _lanjut() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) =>
            SplashScreen(session: widget.session, skipAuth: widget.skipAuth),
      ),
    );
  }

  Widget _iconChip(IconData icon, {double size = 44, Color? bg, Color? fg}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bg ?? DribTokens.blueLight,
        borderRadius: BorderRadius.circular(SsrRadius.tile),
      ),
      child: Icon(
        icon,
        size: size * 0.5,
        color: fg ?? DribTokens.primaryStrong,
      ),
    );
  }

  Widget _optionCard(String value, String label, IconData icon) {
    final t = Theme.of(context);
    final selected = _pilih == value;
    final pastel = switch (value) {
      'terang' => (bg: const Color(0xFFFFF3D6), fg: const Color(0xFFB98A12)),
      'gelap' => (bg: const Color(0xFFDCE6F5), fg: DribTokens.textSecondary),
      _ => (bg: DribTokens.purpleBg, fg: DribTokens.purple),
    };
    return InkWell(
      onTap: () => _pilihOption(value),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(SsrSpace.lg),
        decoration: BoxDecoration(
          color: DribTokens.cardOf(context),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? DribTokens.primary : const Color(0xFFDCE6F5),
            width: selected ? 2 : 1.5,
          ),
        ),
        child: Row(
          children: [
            _iconChip(icon, bg: pastel.bg, fg: pastel.fg),
            const SizedBox(width: SsrSpace.lg),
            Expanded(
              child: Text(
                label,
                style: t.textTheme.titleMedium?.copyWith(
                  color: DribTokens.navy,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (selected)
              Container(
                width: 22,
                height: 22,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: DribTokens.primaryStrong,
                ),
                child: Icon(_iconCheck, size: 12, color: Colors.white),
              )
            else
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFFC9D8F2),
                    width: 2,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Scaffold(
      backgroundColor: DribTokens.bgOf(context),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: SsrSpace.xxl,
                  vertical: SsrSpace.xl,
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: SsrSpace.xxl),
                      Text(
                        tr('st_theme'),
                        style: t.textTheme.titleLarge?.copyWith(
                          color: DribTokens.navy,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: SsrSpace.sm),
                      Text(
                        tr('th_theme_desc'),
                        textAlign: TextAlign.center,
                        style: t.textTheme.bodyMedium?.copyWith(
                          color: DribTokens.textSecondary,
                        ),
                      ),
                      const SizedBox(height: SsrSpace.xl),
                      _optionCard('terang', tr('th_terang'), _iconTerang),
                      const SizedBox(height: SsrSpace.md),
                      _optionCard('gelap', tr('th_gelap'), _iconGelap),
                      const SizedBox(height: SsrSpace.md),
                      _optionCard('otomatis', tr('th_auto'), _iconAuto),
                      const SizedBox(height: SsrSpace.xxl),
                    ],
                  ),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(
                SsrSpace.xxl,
                SsrSpace.lg,
                SsrSpace.xxl,
                SsrSpace.lg,
              ),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: DribTokens.border)),
              ),
              child: PrimaryButton(label: tr('in_next'), onPressed: _lanjut),
            ),
          ],
        ),
      ),
    );
  }
}
