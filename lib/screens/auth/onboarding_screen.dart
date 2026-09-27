import 'package:flutter/material.dart';
import 'package:ssr_space/services/session_service.dart';
import 'package:ssr_space/theme/app_theme.dart';
import 'package:ssr_space/screens/auth/lock_screen.dart';
import 'package:ssr_space/widgets/pin_field.dart';
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

/// Isi layar onboarding: judul + dots langkah, field nama, dua field PIN,
/// dan tombol Mulai.
class _OnboardingBody extends StatelessWidget {
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

  Widget _stepDots() {
    final step = (pinC.text.isNotEmpty || pin2C.text.isNotEmpty) ? 1 : 0;
    return Row(
      children: [
        for (var i = 0; i < 2; i++) ...[
          if (i > 0)
            Container(
              width: 18,
              height: 2,
              margin: const EdgeInsets.symmetric(horizontal: SsrSpace.xs),
              color: SsrColors.noirLine,
            ),
          AnimatedContainer(
            duration: SsrMotion.fast,
            curve: SsrMotion.curve,
            width: i <= step ? 22 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: i <= step ? SsrColors.mint : SsrColors.noirLine,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(SsrSpace.xxl),
      children: [
        Text(
          tr('ob_welcome'),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: SsrSpace.xs),
        Text(
          tr('ob_sub'),
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: SsrColors.noirSecondary),
        ),
        const SizedBox(height: SsrSpace.xl),
        _stepDots(),
        const SizedBox(height: SsrSpace.xl),
        Text(tr('ob_profile'), style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: SsrSpace.md),
        TextField(
          controller: nameC,
          focusNode: nameFocus,
          textInputAction: TextInputAction.next,
          onChanged: onNameChanged,
          decoration: InputDecoration(labelText: tr('ob_name'), errorText: errName),
        ),
        const SizedBox(height: SsrSpace.xl),
        Text(
          tr('ob_pin'),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: SsrSpace.md),
        PinField(controller: pinC, length: 6, error: errPin, autofocus: true),
        const SizedBox(height: SsrSpace.md),
        PinField(controller: pin2C, length: 6, error: errPin2),
        const SizedBox(height: SsrSpace.xxl),
        PrimaryButton(label: tr('ob_start'), loading: saving, onPressed: onSubmit),
      ],
    );
  }
}
