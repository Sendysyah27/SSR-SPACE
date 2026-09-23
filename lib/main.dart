import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ssr_space/core/session/session_service.dart';
import 'package:ssr_space/screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final session = SessionService(prefs);
  runApp(SsrSpaceApp(session: session));
}

class SsrSpaceApp extends StatelessWidget {
  final SessionService session;
  const SsrSpaceApp({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SSR SPACE',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.teal),
      home: SplashScreen(session: session),
      debugShowCheckedModeBanner: false,
    );
  }
}
