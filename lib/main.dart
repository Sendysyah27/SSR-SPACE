import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ssr_space/utils/mask.dart';
import 'package:ssr_space/services/error_reporter.dart';
import 'package:ssr_space/services/foreground_track.dart';
import 'package:ssr_space/services/supabase_config.dart';
import 'package:ssr_space/services/session_service.dart';
import 'package:ssr_space/theme/app_theme.dart';
import 'package:ssr_space/screens/auth/splash_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  ErrorReporter.init();
  await SupabaseConfig.init();
  ForegroundTrack.initOnce();
  final prefs = await SharedPreferences.getInstance();
  await loadMaskAmounts(prefs);
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
    return MaterialApp(
      title: 'SSR SPACE',
      theme: SsrTheme.light(),
      home: SplashScreen(session: session),
      debugShowCheckedModeBanner: false,
    );
  }
}
