import 'package:flutter/material.dart';
import 'package:ssr_space/core/session/session_service.dart';
import 'package:ssr_space/screens/main_shell.dart';

class LockScreen extends StatefulWidget {
  final SessionService session;
  const LockScreen({super.key, required this.session});
  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final pinC = TextEditingController();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SSR SPACE Terkunci')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          const Text('Masukkan PIN untuk membuka sesi'),
          TextField(controller: pinC, obscureText: true, keyboardType: TextInputType.number),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () async {
              final ok = await widget.session.verifyPin(pinC.text);
              if (!context.mounted) return;
              if (ok) {
                Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => MainShell(session: widget.session)));
              } else {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(widget.session.isLockedOut ? 'Terkunci 60 detik' : 'PIN salah')));
              }
            },
            child: const Text('Buka'),
          ),
        ]),
      ),
    );
  }
}
