import 'package:flutter/material.dart';
import 'package:ssr_space/services/session_service.dart';
import 'package:ssr_space/theme/app_theme.dart';
import 'package:ssr_space/theme/dribbble_tokens.dart';
import 'package:ssr_space/screens/auth/lock_screen.dart';
import 'package:ssr_space/widgets/pin_field.dart';
import 'package:ssr_space/widgets/pin_pad.dart';
import 'package:ssr_space/widgets/primary_button.dart';
import 'package:ssr_space/utils/strings.dart';

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
  final nameFocus = FocusNode();
  String? errName;
  String? errPin;
  String? errPin2;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    pinC.addListener(_onChanged);
    pin2C.addListener(_onChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) nameFocus.requestFocus();
    });
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    nameC.dispose();
    pinC.dispose();
    pin2C.dispose();
    nameFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final eName = nameC.text.isEmpty ? tr('ob_name_err') : null;
    final ePin = pinC.text.length < 4 ? tr('ob_pin_err') : null;
    final ePin2 = pinC.text != pin2C.text ? tr('ob_pin2_err') : null;
    if (eName != null || ePin != null || ePin2 != null) {
      setState(() {
        errName = eName;
        errPin = ePin;
        errPin2 = ePin2;
      });
      return;
    }
    setState(() {
      saving = true;
      errName = null;
      errPin = null;
      errPin2 = null;
    });
    await widget.session.completeOnboarding(nameC.text);
    await widget.session.setPin(pinC.text);
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => LockScreen(session: widget.session)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DribTokens.bgOf(context),
      body: SafeArea(
        child: _OnboardingBody(
          nameC: nameC,
          nameFocus: nameFocus,
          pinC: pinC,
          pin2C: pin2C,
          errName: errName,
          errPin: errPin,
          errPin2: errPin2,
          saving: saving,
          onNameChanged: (_) => setState(() => errName = null),
          onSubmit: _submit,
        ),
      ),
    );
  }
}

/// Isi layar onboarding: judul, field nama, dua field PIN + pad,
/// dan tombol Mulai. Kolom PIN aktif ditandai border primer; pad
/// menulis ke kolom aktif (ketuk kotak untuk pindah kolom).
class _OnboardingBody extends StatefulWidget {
  final TextEditingController nameC;
  final FocusNode nameFocus;
  final TextEditingController pinC;
  final TextEditingController pin2C;
  final String? errName;
  final String? errPin;
  final String? errPin2;
  final bool saving;
  final ValueChanged<String> onNameChanged;
  final VoidCallback onSubmit;

  const _OnboardingBody({
    required this.nameC,
    required this.nameFocus,
    required this.pinC,
    required this.pin2C,
    required this.errName,
    required this.errPin,
    required this.errPin2,
    required this.saving,
    required this.onNameChanged,
    required this.onSubmit,
  });

  @override
  State<_OnboardingBody> createState() => _OnboardingBodyState();
}

class _OnboardingBodyState extends State<_OnboardingBody> {
  int _activePin = 0;

  @override
  void initState() {
    super.initState();
    widget.pinC.addListener(_onFirstChanged);
  }

  void _onFirstChanged() {
    if (_activePin == 0 && widget.pinC.text.length >= 6) {
      setState(() => _activePin = 1);
    }
  }

  @override
  void dispose() {
    widget.pinC.removeListener(_onFirstChanged);
    super.dispose();
  }

  void _select(int i) => setState(() => _activePin = i);

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(SsrSpace.xxl),
      children: [
        Text(
          tr('ob_welcome'),
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: DribTokens.navy,
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: SsrSpace.xs),
        Text(
          tr('ob_sub'),
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: DribTokens.textSecondary),
        ),
        const SizedBox(height: SsrSpace.xl),
        Text(
          tr('ob_profile'),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: DribTokens.navy,
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: SsrSpace.md),
        TextField(
          controller: widget.nameC,
          focusNode: widget.nameFocus,
          textInputAction: TextInputAction.next,
          onChanged: widget.onNameChanged,
          decoration: InputDecoration(
            labelText: tr('ob_name'),
            errorText: widget.errName,
          ),
        ),
        const SizedBox(height: SsrSpace.xl),
        Text(
          tr('ob_pin'),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: DribTokens.navy,
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: SsrSpace.md),
        PinField(
          controller: widget.pinC,
          length: 6,
          error: widget.errPin,
          selected: _activePin == 0,
          onTap: () => _select(0),
        ),
        const SizedBox(height: SsrSpace.md),
        PinField(
          controller: widget.pin2C,
          length: 6,
          error: widget.errPin2,
          selected: _activePin == 1,
          onTap: () => _select(1),
        ),
        const SizedBox(height: SsrSpace.lg),
        PinPad(
          controller: _activePin == 0 ? widget.pinC : widget.pin2C,
          length: 6,
        ),
        const SizedBox(height: SsrSpace.xxl),
        PrimaryButton(
          label: tr('ob_start'),
          loading: widget.saving,
          onPressed: widget.onSubmit,
        ),
      ],
    );
  }
}
