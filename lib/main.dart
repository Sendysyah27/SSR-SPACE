import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ssr_space/utils/mask.dart';
import 'package:ssr_space/services/app_categories.dart';
import 'package:ssr_space/services/category_meta.dart';
import 'package:ssr_space/services/app_settings.dart';
import 'package:ssr_space/services/currency.dart';
import 'package:ssr_space/services/due_notify.dart';
import 'package:ssr_space/services/error_reporter.dart';
import 'package:ssr_space/services/foreground_track.dart';
import 'package:ssr_space/services/heartbeat_service.dart';
import 'package:ssr_space/services/pin_link_verify.dart';
import 'package:ssr_space/services/reminder_service.dart';
import 'package:ssr_space/services/save30_notify.dart';
import 'package:ssr_space/services/save30_store.dart';
import 'package:ssr_space/services/supabase_config.dart';
import 'package:ssr_space/services/session_service.dart';
import 'package:ssr_space/theme/app_theme.dart';
import 'package:ssr_space/utils/strings.dart';
import 'package:ssr_space/screens/auth/splash_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ssr_space/utils/diag_log.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterError.onError = (details) {
    DiagLog.error('DIAG FlutterError', details.exception, details.stack);
  };
  WidgetsBinding.instance.platformDispatcher.onError = (error, stack) {
    DiagLog.error('DIAG uncaught-async', error, stack);
    return true;
  };
  DiagLog.write('DIAG main start');
  ErrorReporter.init();
  // DIAG-FIX FC: ErrorReporter.init() menimpa FlutterError.onError &
  // platformDispatcher.onError yang dipasang di atas (dead code) -> crash
  // Dart tak pernah tercatat di log lokal. Rangkai ulang: catat DIAG lalu
  // teruskan ke handler ErrorReporter (perilaku upload tidak berubah).
  final erFlutterOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    DiagLog.error('DIAG FlutterError', details.exception, details.stack);
    erFlutterOnError?.call(details);
  };
  final erDispatcherOnError =
      WidgetsBinding.instance.platformDispatcher.onError;
  WidgetsBinding.instance.platformDispatcher.onError = (error, stack) {
    DiagLog.error('DIAG uncaught-async', error, stack);
    final h = erDispatcherOnError;
    if (h != null) return h(error, stack);
    return true;
  };
  DiagLog.write('DIAG ErrorReporter init ok');
  // Init inti dibungkus: kegagalan plugin native (mis. Pigeon di-strip R8)
  // TIDAK boleh jadi layar putih tanpa jejak — tampilkan pesan jujur.
  try {
    await SupabaseConfig.init();
    DiagLog.write('DIAG Supabase init ok');
  } catch (e, s) {
    DiagLog.error('DIAG Supabase init gagal', e, s);
    ErrorReporter.capture(e, s, context: 'SupabaseConfig.init');
    _bootFailed();
    return;
  }
  ForegroundTrack.initOnce();
  PinLinkVerify.initOnce();
  DiagLog.write('DIAG sebelum SharedPreferences.getInstance');
  late final dynamic prefs;
  try {
    prefs = await SharedPreferences.getInstance();
    DiagLog.write('DIAG SharedPreferences ok');
  } catch (e, s) {
    DiagLog.error('SharedPreferences.getInstance', e, s);
    ErrorReporter.capture(e, s, context: 'SharedPreferences.getInstance');
    _bootFailed();
    return;
  }
  // Optimasi startup: task independen jalan paralel (bukan sekuensial).
  await Future.wait([
    loadMaskAmounts(prefs),
    loadAppSettings(prefs),
    loadAppCategories(prefs),
    refreshCategoryMeta(),
    CurrencyService.loadCache(prefs),
  ]);
  try {
    unawaited(CurrencyService.refresh());
  } catch (e) {
    debugPrint('kurs refresh gagal: $e');
  }
  try {
    // Startup = silent reschedule (tanpa dialog izin; dialog izin hanya
    // dari toggle settings — minta izin sebelum Activity siap = FC 2.13.1).
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
  // Pengingat jatuh tempo utang/tagihan (H-3 & H-1): hitung ulang
  // tiap start, fail-silent seperti pengingat di atas.
  try {
    await DueNotify.reschedule();
  } catch (e) {
    debugPrint('jadwal ulang jatuh tempo gagal: $e');
  }
  // Pengingat harian tantangan hemat (silent, fail-silent).
  try {
    final a = await loadSave30Active();
    await Save30Notify.reschedule(
      active: a != null,
      startYmd: a?.startYmd ?? '',
    );
  } catch (e) {
    debugPrint('jadwal ulang save30 gagal: $e');
  }
  // Heartbeat anti-pause (max 1/hari, fail-silent): aktivitas API harian
  // menjaga project free-tier tetap hidup walau semua cron diam.
  unawaited(touchHeartbeatDaily());
  DiagLog.write('DIAG sebelum SessionService');
  final app = SsrSpaceApp(session: SessionService(prefs));
  DiagLog.write('DIAG runApp dipanggil');
  runZonedGuarded(
    () => runApp(app),
    (err, stack) {
      DiagLog.error('DIAG zone', err, stack);
      ErrorReporter.capture(err, stack, context: 'zone');
    },
  );
}

/// Startup minimal saat init inti gagal (mis. plugin native hilang karena
/// R8). Tampilkan pesan jujur + versi, bukan layar putih tanpa petunjuk.
void _bootFailed() {
  runZonedGuarded(
    () => runApp(const _StartupErrorApp()),
    (err, stack) {
      DiagLog.error('DIAG bootFailed zone', err, stack);
      ErrorReporter.capture(err, stack, context: 'bootFailed');
    },
  );
}

class _StartupErrorApp extends StatelessWidget {
  const _StartupErrorApp();
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(SsrSpace.xxl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    tr('boot_fail_title'),
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: SsrSpace.md),
                  Text(
                    tr('boot_fail_body'),
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
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
