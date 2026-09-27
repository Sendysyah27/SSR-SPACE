import 'package:flutter/material.dart';
import 'package:ssr_space/services/app_settings.dart';
import 'package:ssr_space/services/session_service.dart';
import 'package:ssr_space/screens/auth/splash_screen.dart';
import 'package:ssr_space/theme/app_theme.dart';
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
  static const _iconNoir = IconData(0xE330, fontFamily: SsrFonts.icon);
  static const _iconCheck = IconData(0xE184, fontFamily: SsrFonts.icon);

  late String _pilih;

  @override
  void initState() {
    super.initState();
    _pilih = themeChoice.value == 'noir' ? 'noir' : 'otomatis';
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

  Widget _iconChip(IconData icon, {double size = 44}) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: scheme.outline.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(SsrRadius.tile),
        border: Border.all(color: scheme.outline),
      ),
      child: Icon(icon, size: size * 0.5, color: scheme.primary),
    );
  }

  Widget _optionCard(String value, String label, IconData icon) {
    final t = Theme.of(context);
    final scheme = t.colorScheme;
    final selected = _pilih == value;
    return InkWell(
      onTap: () => _pilihOption(value),
      borderRadius: BorderRadius.circular(SsrRadius.card),
      child: Container(
        padding: const EdgeInsets.all(SsrSpace.lg),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(SsrRadius.card),
          border: Border.all(color: selected ? scheme.primary : scheme.outline),
        ),
        child: Row(
          children: [
            _iconChip(icon),
            const SizedBox(width: SsrSpace.lg),
            Expanded(child: Text(label, style: t.textTheme.titleMedium)),
            if (selected) Icon(_iconCheck, size: 24, color: scheme.primary),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Scaffold(
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
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: SsrSpace.sm),
                      Text(
                        tr('th_theme_desc'),
                        textAlign: TextAlign.center,
                        style: t.textTheme.bodyMedium?.copyWith(
                          color: t.textTheme.bodySmall?.color,
                        ),
                      ),
                      const SizedBox(height: SsrSpace.xl),
                      _optionCard('otomatis', tr('th_auto'), _iconAuto),
                      const SizedBox(height: SsrSpace.md),
                      _optionCard('noir', tr('th_noir'), _iconNoir),
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
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: t.colorScheme.outline)),
              ),
              child: PrimaryButton(label: tr('in_next'), onPressed: _lanjut),
            ),
          ],
        ),
      ),
    );
  }
}
