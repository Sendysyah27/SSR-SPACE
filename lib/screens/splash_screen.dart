import 'package:flutter/material.dart';
import 'package:ssr_space/core/session/session_service.dart';
import 'package:ssr_space/screens/onboarding_screen.dart';
import 'package:ssr_space/screens/lock_screen.dart';
import 'package:ssr_space/screens/home_screen.dart';

class SplashScreen extends StatefulWidget {
  final SessionService session;
  const SplashScreen({super.key, required this.session});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  String? error;
  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    try {
      await Future.delayed(const Duration(milliseconds: 800));
      if (!mounted) return;
      if (widget.session.isFirstRun) {
        Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (_) => OnboardingScreen(session: widget.session)));
      } else if (widget.session.hasPin) {
        Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (_) => LockScreen(session: widget.session)));
      } else {
        Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (_) => HomeScreen(session: widget.session)));
      }
    } catch (e) {
      setState(() => error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: error == null
            ? const Column(mainAxisSize: MainAxisSize.min, children: [
                Text('SSR SPACE', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
                SizedBox(height: 12),
                CircularProgressIndicator(),
              ])
            : Column(mainAxisSize: MainAxisSize.min, children: [
                Text('Gagal init: $error'),
                ElevatedButton(onPressed: _boot, child: const Text('Retry')),
              ]),
      ),
    );
  }
}
