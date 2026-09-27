import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ssr_space/services/app_settings.dart';
import 'package:ssr_space/services/currency.dart';
import 'package:ssr_space/services/instant_correct.dart';
import 'package:ssr_space/services/pin_link_verify.dart';
import 'package:ssr_space/services/reminder_service.dart';
import 'package:ssr_space/services/session_service.dart';
import 'package:ssr_space/services/supabase_config.dart';
import 'package:ssr_space/services/today_widget.dart';
import 'package:ssr_space/theme/app_icons.dart';
import 'package:ssr_space/theme/app_theme.dart';
import 'package:ssr_space/utils/mask.dart';
import 'package:ssr_space/utils/strings.dart';
import 'package:ssr_space/widgets/labeled_section_card.dart';
import 'package:ssr_space/widgets/pin_field.dart';
import 'package:ssr_space/widgets/primary_button.dart';
import 'package:ssr_space/widgets/tx_type_selector.dart';

/// Pengaturan: bahasa, mata uang, ukuran huruf, ganti PIN via magic link.
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
          const _P2StatusLine(),
          const SizedBox(height: SsrSpace.md),
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
          const _DefaultCurrencyCard(),
          const SizedBox(height: SsrSpace.md),
          const _TopNCard(),
          const SizedBox(height: SsrSpace.md),
          const _AnimsCard(),
          const SizedBox(height: SsrSpace.md),
          const _ListStyleCard(),
          const SizedBox(height: SsrSpace.md),
          const _DateStyleCard(),
          const SizedBox(height: SsrSpace.md),
          const _HeroStyleCard(),
          const SizedBox(height: SsrSpace.md),
          const _ReminderCard(),
          const SizedBox(height: SsrSpace.md),
          const _WidgetCard(),
          const SizedBox(height: SsrSpace.md),
          const _ResetCorrectCard(),
          const SizedBox(height: SsrSpace.md),
          const _PinCard(),
        ],
      ),
    );
  }
}

/// Satu baris status jujur tahap P2 untuk seluruh layar ini, ganti
/// 6 subtitle msg_p2 per kartu yang berulang (kalimat jujur dipertahankan).
class _P2StatusLine extends StatelessWidget {
  const _P2StatusLine();

  @override
  Widget build(BuildContext context) {
    return Text(tr('msg_p2'), style: Theme.of(context).textTheme.bodySmall);
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
          style: ssrSegmentedStyle(context),
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

/// Skala huruf aplikasi 0,85 sampai 1,30 + pratinjau nominal.
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

/// Mata uang bawaan form input (dropdown kode, ikut validasi kCurrencySymbols).
class _DefaultCurrencyCard extends StatelessWidget {
  const _DefaultCurrencyCard();

  @override
  Widget build(BuildContext context) {
    return LabeledSectionCard(
      label: tr('st_def_currency'),
      children: [
        ValueListenableBuilder<String>(
          valueListenable: inputDefaultCurrency,
          builder: (context, value, _) => DropdownButtonFormField<String>(
            initialValue: value,
            decoration: const InputDecoration(),
            items: [
              for (final c in kCurrencySymbols.keys)
                DropdownMenuItem(value: c, child: Text(c)),
            ],
            onChanged: (v) {
              if (v != null) setInputDefaultCurrency(v);
            },
          ),
        ),
      ],
    );
  }
}

/// Top 8 + Lainnya di laporan.
class _TopNCard extends StatelessWidget {
  const _TopNCard();

  @override
  Widget build(BuildContext context) {
    return LabeledSectionCard(
      label: tr('st_topn'),
      children: [
        ValueListenableBuilder<bool>(
          valueListenable: reportsTopN,
          builder: (context, value, _) => SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(tr('st_topn')),
            subtitle: Text(tr('st_topn_sub')),
            value: value,
            onChanged: setReportsTopN,
          ),
        ),
      ],
    );
  }
}

/// Animasi UI.
class _AnimsCard extends StatelessWidget {
  const _AnimsCard();

  @override
  Widget build(BuildContext context) {
    return LabeledSectionCard(
      label: tr('st_anims'),
      children: [
        ValueListenableBuilder<bool>(
          valueListenable: uiAnims,
          builder: (context, value, _) => SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(tr('st_anims')),
            value: value,
            onChanged: setUiAnims,
          ),
        ),
      ],
    );
  }
}

/// Gaya daftar: rapat / lega.
class _ListStyleCard extends StatelessWidget {
  const _ListStyleCard();

  @override
  Widget build(BuildContext context) {
    return LabeledSectionCard(
      label: tr('st_list_style'),
      children: [
        ValueListenableBuilder<String>(
          valueListenable: uiListStyle,
          builder: (context, value, _) => SegmentedButton<String>(
            style: ssrSegmentedStyle(context),
            segments: [
              ButtonSegment(
                value: 'compact',
                label: Text(tr('st_list_compact')),
              ),
              ButtonSegment(
                value: 'comfortable',
                label: Text(tr('st_list_comfortable')),
              ),
            ],
            selected: {
              ['compact', 'comfortable'].contains(value)
                  ? value
                  : 'comfortable',
            },
            showSelectedIcon: false,
            onSelectionChanged: (s) => setUiListStyle(s.first),
          ),
        ),
      ],
    );
  }
}

/// Gaya pemilih tanggal.
class _DateStyleCard extends StatelessWidget {
  const _DateStyleCard();

  static const _styles = ['system', 'calendar', 'spinner'];

  @override
  Widget build(BuildContext context) {
    return LabeledSectionCard(
      label: tr('st_date_style'),
      children: [
        ValueListenableBuilder<String>(
          valueListenable: uiDateStyle,
          builder: (context, value, _) => DropdownButtonFormField<String>(
            initialValue: _styles.contains(value) ? value : 'system',
            decoration: const InputDecoration(),
            items: [
              for (final s in _styles)
                DropdownMenuItem(value: s, child: Text(s)),
            ],
            onChanged: (v) {
              if (v != null) setUiDateStyle(v);
            },
          ),
        ),
      ],
    );
  }
}

/// Gaya ringkasan: satu varian dulu, sisanya tahap P2.
class _HeroStyleCard extends StatelessWidget {
  const _HeroStyleCard();

  @override
  Widget build(BuildContext context) {
    return LabeledSectionCard(
      label: tr('st_hero_style'),
      children: [
        ValueListenableBuilder<String>(
          valueListenable: uiHeroStyle,
          builder: (context, value, _) => DropdownButtonFormField<String>(
            initialValue: value == 'emerald-calm' ? value : 'emerald-calm',
            decoration: const InputDecoration(),
            items: const [
              DropdownMenuItem(
                value: 'emerald-calm',
                child: Text('emerald-calm'),
              ),
            ],
            onChanged: (v) {
              if (v != null) setUiHeroStyle(v);
            },
          ),
        ),
      ],
    );
  }
}

/// Pengingat harian: toggle + jam via TimePicker.
class _ReminderCard extends StatelessWidget {
  const _ReminderCard();

  Future<void> _toggle(bool v) async {
    await setReminderEnabled(v);
    try {
      if (v) {
        await ReminderService.scheduleDaily(
          reminderHour.value,
          reminderMinute.value,
        );
      } else {
        await ReminderService.cancel();
      }
    } catch (e) {
      debugPrint('pengingat gagal: $e');
    }
  }

  Future<void> _pick(BuildContext context, int h, int m) async {
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: h, minute: m),
    );
    if (t == null) return;
    await setReminderTime(t.hour, t.minute);
    if (!reminderEnabled.value) return;
    try {
      await ReminderService.scheduleDaily(t.hour, t.minute);
    } catch (e) {
      debugPrint('pengingat gagal: $e');
    }
  }

  String _fmt(int h, int m) =>
      '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return LabeledSectionCard(
      label: tr('st_reminder_time'),
      children: [
        ValueListenableBuilder<bool>(
          valueListenable: reminderEnabled,
          builder: (context, enabled, _) => ValueListenableBuilder<int>(
            valueListenable: reminderHour,
            builder: (context, h, _) => ValueListenableBuilder<int>(
              valueListenable: reminderMinute,
              builder: (context, m, _) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(tr('st_reminder_on')),
                    value: enabled,
                    onChanged: _toggle,
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _fmt(h, m),
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      IconButton(
                        icon: const DuoIcon(AppIcons.clock),
                        tooltip: tr('st_reminder_time'),
                        onPressed: () => _pick(context, h, m),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Widget hari ini: sakelar nyata untuk provider + QS tile (P2).
/// Mati menghapus snapshot lokal; angka ditulis Beranda saat dimuat.
class _WidgetCard extends StatelessWidget {
  const _WidgetCard();

  Future<void> _toggle(bool v) async {
    await setWidgetToday(v);
    if (!v) {
      try {
        await clearTodaySnapshot();
      } catch (e) {
        debugPrint('widget clear gagal: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return LabeledSectionCard(
      label: tr('st_widget_today'),
      children: [
        ValueListenableBuilder<bool>(
          valueListenable: widgetToday,
          builder: (context, value, _) => SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(tr('st_widget_today')),
            subtitle: Text(tr('wg_open')),
            value: value,
            onChanged: _toggle,
          ),
        ),
      ],
    );
  }
}

/// Atur ulang memori koreksi instan (pending + popup), tanpa hapus data.
class _ResetCorrectCard extends StatelessWidget {
  const _ResetCorrectCard();

  Future<void> _reset(BuildContext context) async {
    await InstantCorrect.clearMemory();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(tr('st_reset_correct_done'))));
  }

  @override
  Widget build(BuildContext context) {
    return LabeledSectionCard(
      label: tr('st_reset_correct'),
      children: [
        OutlinedButton(
          onPressed: () => _reset(context),
          child: Text(tr('st_reset_correct')),
        ),
      ],
    );
  }
}

/// Ganti PIN: kirim magic link ke email -> ketuk link (app terbuka
/// otomatis, token ditukar sesi) -> PIN baru 2x.
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
  final pinC = TextEditingController();
  final pin2C = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (pinLinkVerified.value) step = 'verified';
    pinLinkVerified.addListener(_onLinkVerified);
  }

  @override
  void dispose() {
    pinLinkVerified.removeListener(_onLinkVerified);
    pinC.dispose();
    pin2C.dispose();
    super.dispose();
  }

  void _onLinkVerified() {
    if (pinLinkVerified.value && mounted && step == 'sent') {
      setState(() => step = 'verified');
    }
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
      PinLinkVerify.reset();
      await SupabaseConfig.client.auth.signInWithOtp(
        email: mail,
        emailRedirectTo: pinLinkCallback,
        shouldCreateUser: false,
      );
      if (!mounted) return;
      setState(() {
        step = 'sent';
        msg = tr('st_pin_sent_link').replaceFirst('{e}', mail);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => err = tr('w_err_save'));
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
      PinLinkVerify.reset();
      setState(() {
        step = 'idle';
        msg = tr('st_pin_changed');
      });
      pinC.clear();
      pin2C.clear();
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
        if (step == 'sent') _WaitLink(busy: busy, onResend: _send),
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
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.error,
            ),
          ),
          const SizedBox(height: SsrSpace.sm),
        ],
      ],
    );
  }
}

/// Tunggu ketuk link di email + kirim ulang.
class _WaitLink extends StatelessWidget {
  final bool busy;
  final VoidCallback onResend;

  const _WaitLink({required this.busy, required this.onResend});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(tr('st_pin_wait'), style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: SsrSpace.md),
        TextButton(
          onPressed: busy ? null : onResend,
          child: Text(tr('st_pin_resend')),
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
