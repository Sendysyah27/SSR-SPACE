import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ssr_space/services/session_service.dart';
import 'package:ssr_space/theme/app_theme.dart';
import 'package:ssr_space/screens/shell/main_shell.dart';
import 'package:ssr_space/widgets/pin_field.dart';
import 'package:ssr_space/widgets/primary_button.dart';

class LockScreen extends StatefulWidget {
  final SessionService session;
  const LockScreen({super.key, required this.session});
  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final pinC = TextEditingController();
  String? err;
  Timer? _ticker;

  static const _lockoutMsg =
      'Terlalu banyak salah. Tunggu 60 detik lalu coba lagi.';

  @override
  void initState() {
    super.initState();
    if (widget.session.isLockedOut) {
      err = _lockoutMsg;
      _startTicker();
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    pinC.dispose();
    super.dispose();
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (!widget.session.isLockedOut) {
        _ticker?.cancel();
        setState(() => err = null);
      }
    });
  }

  Future<void> _verify() async {
    final ok = await widget.session.verifyPin(pinC.text);
    if (!mounted) return;
    if (ok) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => MainShell(session: widget.session)),
      );
      return;
    }
    setState(() {
      err = widget.session.isLockedOut ? _lockoutMsg : 'PIN salah. Coba lagi.';
    });
    if (widget.session.isLockedOut) _startTicker();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(SsrSpace.xxl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: SsrColors.accentSoft,
                    borderRadius: BorderRadius.circular(SsrRadius.tile),
                  ),
                  child: const Icon(
                    Icons.lock_outline,
                    size: 28,
                    color: SsrColors.accent,
                  ),
                ),
                const SizedBox(height: SsrSpace.xl),
                Text('Terkunci', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: SsrSpace.xs),
                Text(
                  'Masukkan PIN untuk buka sesi',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(color: SsrColors.secondary),
                ),
                const SizedBox(height: SsrSpace.xxl),
                PinField(
                  controller: pinC,
                  length: 6,
                  error: err,
                  autofocus: true,
                ),
                const SizedBox(height: SsrSpace.xl),
                PrimaryButton(label: 'Buka', onPressed: _verify),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
