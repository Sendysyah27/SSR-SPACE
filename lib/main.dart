import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:ssr_space/services/firebase_ai_factory.dart';
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
import 'package:ssr_space/screens/auth/splash_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Firebase untuk AI parser struk: gagal init = AI mati, app tetap
  // jalan (tanpa google-services.json di device lama / build lokal).
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('firebase init gagal (AI mati): $e');
  }
  // SENGAJA tanpa Firebase App Check: token invalid yang menempel
  // justru bikin 403 "App attestation failed" walau console Unenforced
  // (token invalid != tanpa token). Tanpa activate = tanpa token =
  // lolos saat unenforced. Jangan tambah activate() lagi kecuali
  // console di-enforce.
  ErrorReporter.init();
  await SupabaseConfig.init();
  // Perbaiki sesi lama / fallback browser: ada sesi Supabase tapi tanpa
  // sesi Firebase → top-up (link/anonim), fail-open. Tanpa ini user yang
  // login sebelum update tak pernah dapat AI sampai login ulang.
  try {
    if (SupabaseConfig.client.auth.currentSession != null) {
      await ensureFirebaseSession();
    }
  } catch (e) {
    debugPrint('firebase ensure gagal (AI mati): $e');
  }
  ForegroundTrack.initOnce();
  PinLinkVerify.initOnce();
  final prefs = await SharedPreferences.getInstance();
  await loadMaskAmounts(prefs);
  await loadAppSettings(prefs);
  await loadAppCategories(prefs);
  await refreshCategoryMeta();
  await CurrencyService.loadCache(prefs);
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
