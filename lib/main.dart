import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ssr_space/utils/mask.dart';
import 'package:ssr_space/services/app_categories.dart';
import 'package:ssr_space/services/category_meta.dart';
import 'package:ssr_space/services/app_settings.dart';
import 'package:ssr_space/services/currency.dart';
import 'package:ssr_space/services/error_reporter.dart';
import 'package:ssr_space/services/pin_debug_log.dart';
import 'package:ssr_space/services/foreground_track.dart';
import 'package:ssr_space/services/pin_link_verify.dart';
import 'package:ssr_space/services/reminder_service.dart';
import 'package:ssr_space/services/supabase_config.dart';
import 'package:ssr_space/services/session_service.dart';
import 'package:ssr_space/theme/app_theme.dart';
import 'package:ssr_space/screens/auth/splash_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Boundary per-kartu: subtree yang throw saat build diganti placeholder
  // tak terlihat (bukan layar abu/merah seluruh halaman). Satu kartu data
  // aneh tak mematikan Beranda; error tetap dilaporkan via ErrorReporter
  // oleh framework (FlutterError.onError).
  ErrorWidget.builder = (details) {
    try {
      ErrorReporter.capture(
        details.exception,
        details.stack ?? StackTrace.empty,
        context: 'widget_build',
      );
    } catch (_) {}
    return const SizedBox.shrink();
  };
  ErrorReporter.init();
  await SupabaseConfig.init();
  ForegroundTrack.initOnce();
  PinLinkVerify.initOnce();
  await clearPinLog();
  await pinLog('main start');
  final prefs = await SharedPreferences.getInstance();
  await pinLog('main prefs ok');
  await loadMaskAmounts(prefs);
  await loadAppSettings(prefs);
  await pinLog('main settings ok');
  await loadAppCategories(prefs);
  await refreshCategoryMeta();
  await CurrencyService.loadCache(prefs);
  try {
    unawaited(CurrencyService.refresh());
  } catch (e) {
    debugPrint('kurs refresh gagal: $e');
  }
  try {
    if (reminderEnabled.value) {
      final h = reminderHour.value.clamp(0, 23);
      final m = reminderMinute.value.clamp(0, 59);
      await ReminderService.init();
      await ReminderService.scheduleDaily(h, m);
    }
    if (weeklyEnabled.value) {
      await ReminderService.scheduleWeekly(
        weeklyWeekday.value.clamp(1, 7),
        weeklyHour.value.clamp(0, 23),
        weeklyMinute.value.clamp(0, 59),
      );
    }
  } catch (e) {
    debugPrint('jadwal ulang pengingat gagal: $e');
  }
  await pinLog('main pre-runApp');
  final app = SsrSpaceApp(session: SessionService(prefs));
  runZonedGuarded(
    () => runApp(app),
    // Handler zona tak boleh throw: bungkus ganda (capture sendiri
    // sudah anti-throw, tapi kontrak ini dijaga eksplisit).
    (err, stack) {
      try {
        ErrorReporter.capture(err, stack, context: 'zone');
      } catch (_) {}
    },
  );
}

class SsrSpaceApp extends StatelessWidget {
  final SessionService session;
  const SsrSpaceApp({super.key, required this.session});
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: themeChoice,
      builder: (_, choice, ___) {
        final isNoir = choice == 'noir';
        return ValueListenableBuilder<String>(
          valueListenable: localeCode,
          builder: (_, __, ___) => ValueListenableBuilder<String>(
            valueListenable: currencyCode,
            builder: (_, __, ___) => ValueListenableBuilder<double>(
              valueListenable: fontScale,
              builder: (_, scale, ___) => MaterialApp(
                title: 'SSR SPACE',
                theme: AppTheme.light(),
                darkTheme: AppTheme.dark(),
                themeMode: isNoir ? ThemeMode.dark : ThemeMode.system,
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
      },
    );
  }
}
