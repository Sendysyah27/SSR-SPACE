import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ssr_space/services/app_settings.dart';
import 'package:ssr_space/services/biometric_auth.dart';
import 'package:ssr_space/services/session_service.dart';
import 'package:ssr_space/theme/app_icons.dart';
import 'package:ssr_space/theme/app_theme.dart';
import 'package:ssr_space/theme/dribbble_tokens.dart';
import 'package:ssr_space/screens/shell/main_shell.dart';
import 'package:ssr_space/widgets/pin_field.dart';
import 'package:ssr_space/widgets/pin_pad.dart';
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
  bool _verifying = false;
  bool _bioTried = false;
  bool _bioAvailable = false;

  @override
  void initState() {
    super.initState();
    if (widget.session.isLockedOut) {
      err = tr('lk_lockout');
      _startTicker();
    }
    _checkBio();
    WidgetsBinding.instance.addPostFrameCallback((_) => _tryBiometric());
  }

  /// Cek dukungan biometrik sekali (untuk tombol manual). Gagal = sembunyi.
  Future<void> _checkBio() async {
    if (!biometricEnabled.value) return;
    final ok = await BiometricAuth.isSupported();
    if (mounted) setState(() => _bioAvailable = ok);
  }

  /// Coba biometrik otomatis sekali saat layar dibuka (opt-in saja).
  /// Batal/gagal = diam, PIN pad tetap jadi jalan utama.
  Future<void> _tryBiometric() async {
    if (_bioTried || !mounted) return;
    _bioTried = true;
    if (!biometricEnabled.value) return;
    if (!await BiometricAuth.isSupported()) return;
    if (!mounted) return;
    final ok = await BiometricAuth.unlock(tr('lk_bio'));
    if (!mounted) return;
    if (ok) _openApp();
  }

  /// Ketuk tombol sidik jari manual (coba ulang setelah batal).
  /// Gagal config = tampil jujur di bawah PIN (jangan diam seperti dulu).
  Future<void> _bioManual() async {
    _bioTried = true;
    if (!mounted) return;
    final ok = await BiometricAuth.unlock(tr('lk_bio'));
    if (!mounted) return;
    if (ok) {
      _openApp();
      return;
    }
    final errDetail = BiometricAuth.lastError;
    if (errDetail != null && errDetail.isNotEmpty) {
      setState(() {
        err = tr('bio_failed').replaceFirst('{c}', errDetail);
      });
    }
  }

  void _openApp() {
    widget.session.markUnlocked();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => MainShell(session: widget.session)),
    );
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
    if (_verifying) return;
    _verifying = true;
    var ok = false;
    try {
      ok = await widget.session.verifyPin(pinC.text);
    } catch (_) {
      ok = false;
    }
    if (!mounted) return;
    if (ok) {
      _openApp();
      return;
    }
    setState(() {
      err = widget.session.isLockedOut ? tr('lk_lockout') : tr('lk_wrong');
      pinC.clear();
    });
    _verifying = false;
    if (widget.session.isLockedOut) _startTicker();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DribTokens.bgOf(context),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(SsrSpace.xxl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [DribTokens.primary, DribTokens.primaryStrong],
                    ),
                  ),
                  child: const DuoIcon(
                    AppIcons.lock,
                    size: 26,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: SsrSpace.lg),
                Text(
                  tr('lk_title'),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: DribTokens.navy,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: SsrSpace.xs),
                Text(
                  tr('lk_sub'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: DribTokens.textSecondary,
                  ),
                ),
                const SizedBox(height: SsrSpace.xxl),
                PinField(
                  controller: pinC,
                  length: 6,
                  error: err,
                  onCompleted: (_) => _verify(),
                ),
                const SizedBox(height: SsrSpace.xxl),
                PinPad(controller: pinC, length: 6),
                if (_bioAvailable) ...[
                  const SizedBox(height: SsrSpace.md),
                  TextButton(
                    onPressed: _bioManual,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.fingerprint,
                          size: 19,
                          color: DribTokens.primaryStrong,
                        ),
                        const SizedBox(width: 7),
                        Text(
                          tr('lk_bio'),
                          style: const TextStyle(
                            color: DribTokens.primaryStrong,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
