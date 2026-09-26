import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ssr_space/utils/mask.dart';
import 'package:ssr_space/services/app_categories.dart';
import 'package:ssr_space/services/app_settings.dart';
import 'package:ssr_space/services/currency.dart';
import 'package:ssr_space/services/error_reporter.dart';
import 'package:ssr_space/services/foreground_track.dart';
import 'package:ssr_space/services/pin_link_verify.dart';
import 'package:ssr_space/services/reminder_service.dart';
import 'package:ssr_space/services/supabase_config.dart';
import 'package:ssr_space/services/session_service.dart';
import 'package:ssr_space/theme/app_theme.dart';
import 'package:ssr_space/screens/auth/splash_screen.dart';
import 'package:ssr_space/widgets/correct_overlay.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Entry-point isolate overlay koreksi instan (30 detik, tanpa izin tambahan
/// selain SYSTEM_ALERT_WINDOW yang diminta saat master tracking dinyalakan).
@pragma('vm:entry-point')
void overlayMain() {
  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: CorrectOverlay(),
    ),
  );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  ErrorReporter.init();
  await SupabaseConfig.init();
  ForegroundTrack.initOnce();
  PinLinkVerify.initOnce();
  final prefs = await SharedPreferences.getInstance();
  await loadMaskAmounts(prefs);
  await loadAppSettings(prefs);
  await loadAppCategories(prefs);
  await CurrencyService.loadCache(prefs);
  unawaited(CurrencyService.refresh());
  try {
    if (prefs.getBool('reminder_enabled') ?? false) {
      final h = (prefs.getInt('reminder_hour') ?? 7).clamp(0, 23);
      final m = (prefs.getInt('reminder_minute') ?? 0).clamp(0, 59);
      await ReminderService.init();
      await ReminderService.scheduleDaily(h, m);
    }
  } catch (e) {
    debugPrint('jadwal ulang pengingat gagal: $e');
  }
  final app = SsrSpaceApp(session: SessionService(prefs));
  runZonedGuarded(
    () => runApp(app),
    (err, stack) => ErrorReporter.capture(err, stack, context: 'zone'),
  );
}

class SsrSpaceApp extends StatelessWidget {
  final SessionService session;
  const SsrSpaceApp({super.key, required this.session});
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: localeCode,
      builder: (_, __, ___) => ValueListenableBuilder<String>(
        valueListenable: currencyCode,
        builder: (_, __, ___) => ValueListenableBuilder<double>(
          valueListenable: fontScale,
          builder: (_, scale, ___) => MaterialApp(
            title: 'SSR SPACE',
            theme: SsrTheme.light(),
            home: SplashScreen(session: session),
            debugShowCheckedModeBanner: false,
            builder: (ctx, child) => MediaQuery(
              data: MediaQuery.of(ctx)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child ?? const SizedBox.shrink(),
            ),
          ),
        ),
      ),
    );
  }
}
