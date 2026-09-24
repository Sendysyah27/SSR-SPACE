import 'package:flutter/material.dart';
import 'package:ssr_space/core/saas/supabase_config.dart';
import 'package:ssr_space/core/session/session_service.dart';
import 'package:ssr_space/core/theme/app_theme.dart';
import 'package:ssr_space/screens/splash_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseConfig.init();
  final prefs = await SharedPreferences.getInstance();
  runApp(SsrSpaceApp(session: SessionService(prefs)));
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
