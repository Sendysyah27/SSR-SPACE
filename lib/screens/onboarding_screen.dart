import 'package:flutter/material.dart';
import 'package:ssr_space/core/session/session_service.dart';
import 'package:ssr_space/screens/lock_screen.dart';

class OnboardingScreen extends StatefulWidget {
  final SessionService session;
  const OnboardingScreen({super.key, required this.session});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final nameC = TextEditingController();
  final pinC = TextEditingController();
  final pin2C = TextEditingController();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Selamat datang di SSR SPACE')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        const Text('Langkah 1: Profil'),
        TextField(controller: nameC, decoration: const InputDecoration(labelText: 'Nama')),
        const SizedBox(height: 16),
        const Text('Langkah 2: PIN keamanan (6 digit)'),
        TextField(controller: pinC, obscureText: true, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'PIN')),
        TextField(controller: pin2C, obscureText: true, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Ulangi PIN')),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: () async {
            if (nameC.text.isEmpty || pinC.text.length < 4 || pinC.text != pin2C.text) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cek nama & PIN')));
              return;
            }
            await widget.session.completeOnboarding(nameC.text);
            await widget.session.setPin(pinC.text);
            if (!context.mounted) return;
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => LockScreen(session: widget.session)));
          },
          child: const Text('Mulai'),
        ),
      ]),
    );
  }
}
