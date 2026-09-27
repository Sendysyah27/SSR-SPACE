import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ssr_space/services/session_service.dart';
import 'package:ssr_space/theme/app_icons.dart';
import 'package:ssr_space/theme/app_theme.dart';
import 'package:ssr_space/screens/shell/main_shell.dart';
import 'package:ssr_space/widgets/pin_field.dart';
import 'package:ssr_space/widgets/primary_button.dart';
import 'package:ssr_space/utils/strings.dart';

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

  @override
  void initState() {
    super.initState();
    if (widget.session.isLockedOut) {
      err = tr('lk_lockout');
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
      err = widget.session.isLockedOut ? tr('lk_lockout') : tr('lk_wrong');
    });
    if (widget.session.isLockedOut) _startTicker();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(SsrSpace.xxl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: scheme.outline.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(SsrRadius.tile),
                    border: Border.all(color: scheme.outline),
                  ),
                  child: DuoIcon(
                    AppIcons.lock,
                    size: 26,
                    color: scheme.primary,
                  ),
                ),
                const SizedBox(height: SsrSpace.lg),
                Text(
                  tr('lk_title'),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: SsrSpace.xs),
                Text(
                  tr('lk_sub'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).textTheme.bodySmall?.color,
                  ),
                ),
                const SizedBox(height: SsrSpace.lg),
                PinField(
                  controller: pinC,
                  length: 6,
                  error: err,
                  autofocus: true,
                ),
                const SizedBox(height: SsrSpace.lg),
                PrimaryButton(label: tr('lk_open'), onPressed: _verify),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
