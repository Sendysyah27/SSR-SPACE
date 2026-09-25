import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ssr_space/services/app_settings.dart';
import 'package:ssr_space/services/currency.dart';
import 'package:ssr_space/services/session_service.dart';
import 'package:ssr_space/services/supabase_config.dart';
import 'package:ssr_space/theme/app_theme.dart';
import 'package:ssr_space/utils/mask.dart';
import 'package:ssr_space/utils/strings.dart';
import 'package:ssr_space/widgets/labeled_section_card.dart';
import 'package:ssr_space/widgets/pin_field.dart';
import 'package:ssr_space/widgets/primary_button.dart';

/// Pengaturan: bahasa, mata uang, ukuran huruf, ganti PIN via OTP email.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String? fxMsg;
  bool fxBusy = false;

  Future<void> _refreshFx() async {
    setState(() {
      fxBusy = true;
      fxMsg = null;
    });
    final ok = await CurrencyService.refresh();
    if (!mounted) return;
    setState(() {
      fxBusy = false;
      fxMsg = ok ? tr('st_fx_ok') : tr('st_fx_fail');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('st_title'))),
      body: ListView(
        padding: const EdgeInsets.all(SsrSpace.lg),
        children: [
          _LangCard(
            value: localeCode.value,
            onChanged: (v) => setLocaleCode(v),
          ),
          const SizedBox(height: SsrSpace.md),
          _CurrencyCard(
            value: currencyCode.value,
            fxBusy: fxBusy,
            fxMsg: fxMsg,
            onChanged: (v) => setCurrencyCode(v),
            onRefresh: _refreshFx,
          ),
          const SizedBox(height: SsrSpace.md),
          _FontCard(value: fontScale.value, onChanged: (v) => setFontScale(v)),
          const SizedBox(height: SsrSpace.md),
          const _PinCard(),
        ],
      ),
    );
  }
}

/// Bahasa aplikasi: Indonesia / English.
class _LangCard extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;

  const _LangCard({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return LabeledSectionCard(
      label: tr('st_lang'),
      children: [
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'id', label: Text('Indonesia')),
            ButtonSegment(value: 'en', label: Text('English')),
          ],
          selected: {value},
          showSelectedIcon: false,
          onSelectionChanged: (s) => onChanged(s.first),
        ),
      ],
    );
  }
}

/// Mata uang tampilan + status kurs.
class _CurrencyCard extends StatelessWidget {
  final String value;
  final bool fxBusy;
  final String? fxMsg;
  final ValueChanged<String> onChanged;
  final VoidCallback onRefresh;

  const _CurrencyCard({
    required this.value,
    required this.fxBusy,
    required this.fxMsg,
    required this.onChanged,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final at = CurrencyService.fetchedAt;
    final info =
        fxMsg ??
        (at == null
            ? tr('st_fx_none')
            : tr('st_fx_cache')
                  .replaceFirst('{d}', '${at.day}-${at.month}-${at.year}'));
    return LabeledSectionCard(
      label: tr('st_currency'),
      children: [
        DropdownButtonFormField<String>(
          initialValue: value,
          decoration: const InputDecoration(),
          items: [
            for (final c in kCurrencySymbols.keys)
              DropdownMenuItem(value: c, child: Text(c)),
          ],
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
        const SizedBox(height: SsrSpace.sm),
        Text(info, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: SsrSpace.sm),
        OutlinedButton(
          onPressed: fxBusy ? null : onRefresh,
          child: Text(tr('st_fx_refresh')),
        ),
      ],
    );
  }
}

/// Skala huruf aplikasi 0,85–1,30 + pratinjau nominal.
class _FontCard extends StatelessWidget {
  final double value;
  final ValueChanged<double> onChanged;

  const _FontCard({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return LabeledSectionCard(
      label: tr('st_font'),
      children: [
        Text(amt(100000)),
        Slider(
          value: value,
          min: 0.85,
          max: 1.3,
          divisions: 9,
          label: value.toStringAsFixed(2),
          onChanged: onChanged,
        ),
      ],
    );
  }
}

/// Ganti PIN: kirim OTP ke email → verifikasi → PIN baru 2x.
class _PinCard extends StatefulWidget {
  const _PinCard();

  @override
  State<_PinCard> createState() => _PinCardState();
}

class _PinCardState extends State<_PinCard> {
  String step = 'idle';
  String? msg;
  String? err;
  bool busy = false;
  String email = '';
  final otpC = TextEditingController();
  final pinC = TextEditingController();
  final pin2C = TextEditingController();

  @override
  void dispose() {
    otpC.dispose();
    pinC.dispose();
    pin2C.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() {
      busy = true;
      err = null;
      msg = null;
    });
    try {
      final mail = SupabaseConfig.client.auth.currentUser?.email ?? '';
      if (mail.isEmpty) {
        setState(() => err = tr('st_pin_noemail'));
        return;
      }
      await SupabaseConfig.client.auth.signInWithOtp(email: mail);
      if (!mounted) return;
      setState(() {
        email = mail;
        step = 'sent';
        msg = tr('st_pin_sent').replaceFirst('{e}', mail);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => err = tr('w_err_save'));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _verify() async {
    if (otpC.text.trim().length < 6) {
      setState(() => err = tr('st_pin_badcode'));
      return;
    }
    setState(() {
      busy = true;
      err = null;
    });
    try {
      final res = await SupabaseConfig.client.auth.verifyOTP(
        type: OtpType.email,
        token: otpC.text.trim(),
        email: email,
      );
      if (!mounted) return;
      if (res.session == null) {
        setState(() => err = tr('st_pin_badcode'));
        return;
      }
      setState(() => step = 'verified');
    } catch (_) {
      if (!mounted) return;
      setState(() => err = tr('st_pin_badcode'));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _savePin() async {
    if (pinC.text.length < 4) {
      setState(() => err = tr('st_pin_short'));
      return;
    }
    if (pinC.text != pin2C.text) {
      setState(() => err = tr('st_pin_mismatch'));
      return;
    }
    setState(() {
      busy = true;
      err = null;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      await SessionService(prefs).setPin(pinC.text);
      if (!mounted) return;
      setState(() {
        step = 'idle';
        msg = tr('st_pin_changed');
      });
      pinC.clear();
      pin2C.clear();
      otpC.clear();
    } catch (_) {
      if (!mounted) return;
      setState(() => err = tr('w_err_save'));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LabeledSectionCard(
      label: tr('st_pin'),
      children: [
        _PinFeedback(msg: msg, err: err),
        if (step == 'idle')
          PrimaryButton(
            label: tr('st_pin_send'),
            loading: busy,
            onPressed: _send,
          ),
        if (step == 'sent')
          _CodeForm(otpC: otpC, busy: busy, onVerify: _verify),
        if (step == 'verified')
          _NewPinForm(pinC: pinC, pin2C: pin2C, busy: busy, onSave: _savePin),
      ],
    );
  }
}

/// Pesan info / galat kartu PIN.
class _PinFeedback extends StatelessWidget {
  final String? msg;
  final String? err;

  const _PinFeedback({required this.msg, required this.err});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (msg != null) ...[
          Text(msg!, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: SsrSpace.sm),
        ],
        if (err != null) ...[
          Text(
            err!,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: SsrColors.danger),
          ),
          const SizedBox(height: SsrSpace.sm),
        ],
      ],
    );
  }
}

/// Form kode OTP 6 digit.
class _CodeForm extends StatelessWidget {
  final TextEditingController otpC;
  final bool busy;
  final VoidCallback onVerify;

  const _CodeForm({
    required this.otpC,
    required this.busy,
    required this.onVerify,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: otpC,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: tr('st_pin_code')),
        ),
        const SizedBox(height: SsrSpace.md),
        PrimaryButton(
          label: tr('st_pin_verify'),
          loading: busy,
          onPressed: onVerify,
        ),
      ],
    );
  }
}

/// Form PIN baru 2x.
class _NewPinForm extends StatelessWidget {
  final TextEditingController pinC;
  final TextEditingController pin2C;
  final bool busy;
  final VoidCallback onSave;

  const _NewPinForm({
    required this.pinC,
    required this.pin2C,
    required this.busy,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PinField(controller: pinC, length: 6, autofocus: true),
        const SizedBox(height: SsrSpace.md),
        PinField(controller: pin2C, length: 6),
        const SizedBox(height: SsrSpace.md),
        PrimaryButton(
          label: tr('st_pin_save'),
          loading: busy,
          onPressed: onSave,
        ),
      ],
    );
  }
}
