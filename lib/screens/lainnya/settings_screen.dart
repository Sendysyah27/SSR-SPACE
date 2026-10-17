import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'package:ssr_space/services/firebase_ai_parser.dart';
import 'package:ssr_space/services/ai_key_store.dart';
import 'package:ssr_space/services/ai_quota.dart';
import 'package:ssr_space/services/plan_limits.dart';
import 'package:ssr_space/services/ai_cli_client.dart';
import 'package:ssr_space/services/app_settings.dart';
import 'package:ssr_space/services/biometric_auth.dart';
import 'package:ssr_space/services/currency.dart';
import 'package:ssr_space/services/pin_link_verify.dart';
import 'package:ssr_space/services/reminder_service.dart';
import 'package:ssr_space/services/session_service.dart';
import 'package:ssr_space/services/supabase_config.dart';
import 'package:ssr_space/services/today_widget.dart';
import 'package:ssr_space/services/wallet_service.dart';
import 'package:ssr_space/models/wallet.dart';
import 'package:ssr_space/utils/org_prefs.dart';
import 'package:ssr_space/theme/app_icons.dart';
import 'package:ssr_space/theme/app_theme.dart';
import 'package:ssr_space/theme/dribbble_tokens.dart';
import 'package:ssr_space/utils/mask.dart';
import 'package:ssr_space/utils/app_info.dart';
import 'package:ssr_space/utils/datetime.dart';
import 'package:ssr_space/utils/strings.dart';
import 'package:ssr_space/widgets/labeled_section_card.dart';
import 'package:ssr_space/theme/tokens.dart';
import 'package:ssr_space/widgets/premium/premium_section_header.dart';
import 'package:ssr_space/widgets/pin_field.dart';
import 'package:ssr_space/widgets/pin_pad.dart';
import 'package:ssr_space/widgets/primary_button.dart';
import 'package:ssr_space/widgets/tx_type_selector.dart';

/// Pengaturan: bahasa, tema, mata uang, ukuran huruf, ganti PIN
/// (verifikasi PIN lama; lupa PIN via magic link email sebagai cadangan).
/// [focus] = kunci kartu yang dibuka otomatis (dari pintu hub Profil):
/// 'lang' | 'font' | 'reminder' | 'pin'. Null = dari atas seperti biasa.
class SettingsScreen extends StatefulWidget {
  final String? focus;

  const SettingsScreen({super.key, this.focus});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String? fxMsg;
  bool fxBusy = false;
  final _langKey = GlobalKey();
  final _fontKey = GlobalKey();
  final _reminderKey = GlobalKey();
  final _pinKey = GlobalKey();
  final _currencyKey = GlobalKey();
  final _topnKey = GlobalKey();
  final _animsKey = GlobalKey();
  final _listKey = GlobalKey();
  final _dateKey = GlobalKey();
  final _heroKey = GlobalKey();
  final _cardThemeKey = GlobalKey();
  final _widgetKey = GlobalKey();
  final _numKey = GlobalKey();
  final _defWalletKey = GlobalKey();
  final _weekStartKey = GlobalKey();
  final _lockKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    final f = widget.focus;
    if (f == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final key = switch (f) {
        'lang' => _langKey,
        'font' => _fontKey,
        'reminder' => _reminderKey,
        'pin' => _pinKey,
        'currency' => _currencyKey,
        'topn' => _topnKey,
        'anims' => _animsKey,
        'list' => _listKey,
        'date' => _dateKey,
        'hero' => _heroKey,
        'card-theme' => _cardThemeKey,
        'widget' => _widgetKey,
        'numformat' => _numKey,
        'defwallet' => _defWalletKey,
        'weekstart' => _weekStartKey,
        'lock' => _lockKey,
        _ => null,
      };
      if (key?.currentContext != null) {
        Scrollable.ensureVisible(
          key!.currentContext!,
          duration: const Duration(milliseconds: 300),
        );
      }
    });
  }

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
      backgroundColor: DribTokens.bg,
      appBar: AppBar(title: Text(tr('st_title'))),
      body: ListView(
        padding: const EdgeInsets.all(SsrSpace.lg),
        children: [
          const _P2StatusLine(),
          const SizedBox(height: SsrSpace.md),
          // Grup iOS batch 1 (brief §7.2): caption caps + kartu.
          // Isi kartu tak diubah (R-26: semua kontrol tetap jalan).
          PremiumSectionHeader(title: tr('st_group_ai')),
          const SizedBox(height: SsrSpace.sm),
          const _AiCard(),
          const SizedBox(height: SsrSpace.md),
          PremiumSectionHeader(title: tr('st_group_data')),
          const SizedBox(height: SsrSpace.sm),
          ValueListenableBuilder<String>(
            valueListenable: localeCode,
            builder: (context, loc, _) => Container(
              key: _langKey,
              child: _LangCard(value: loc, onChanged: (v) => setLocaleCode(v)),
            ),
          ),
          const SizedBox(height: SsrSpace.md),
          ValueListenableBuilder<String>(
            valueListenable: currencyCode,
            builder: (context, cur, _) => Container(
              key: _currencyKey,
              child: _CurrencyCard(
                value: cur,
                fxBusy: fxBusy,
                fxMsg: fxMsg,
                onChanged: (v) => setCurrencyCode(v),
                onRefresh: _refreshFx,
              ),
            ),
          ),
          const SizedBox(height: SsrSpace.md),
          const _DefaultCurrencyCard(),
          const SizedBox(height: SsrSpace.md),
          Container(key: _numKey, child: const _NumberFormatCard()),
          const SizedBox(height: SsrSpace.md),
          Container(
            key: _defWalletKey,
            child: const _DefaultWalletCard(),
          ),
          const SizedBox(height: SsrSpace.md),
          Container(
            key: _weekStartKey,
            child: const _WeekStartCard(),
          ),
          const SizedBox(height: SsrSpace.md),
          Container(key: _topnKey, child: const _TopNCard()),
          const SizedBox(height: SsrSpace.md),
          PremiumSectionHeader(title: tr('st_group_display')),
          const SizedBox(height: SsrSpace.sm),
          // Grup Tampilan: grid 2 kolom (Batch Ollo 2). Kartu
          // _CardThemeCard & _WidgetCard full-width (butuh lebar penuh untuk
          // preview horizontal / konten lega). Focus key dipertahankan.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ValueListenableBuilder<double>(
                  valueListenable: fontScale,
                  builder: (context, fs, _) => Container(
                    key: _fontKey,
                    child:
                        _FontCard(value: fs, onChanged: (v) => setFontScale(v)),
                  ),
                ),
              ),
              const SizedBox(width: SsrSpace.md),
              Expanded(
                child: Container(
                  key: _animsKey,
                  child: const _AnimsCard(),
                ),
              ),
            ],
          ),
          const SizedBox(height: SsrSpace.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
                  key: _listKey,
                  child: const _ListStyleCard(),
                ),
              ),
              const SizedBox(width: SsrSpace.md),
              Expanded(
                child: Container(
                  key: _dateKey,
                  child: const _DateStyleCard(),
                ),
              ),
            ],
          ),
          const SizedBox(height: SsrSpace.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
                  key: _heroKey,
                  child: const _HeroStyleCard(),
                ),
              ),
              const SizedBox(width: SsrSpace.md),
              Expanded(
                child: ValueListenableBuilder<String>(
                  valueListenable: themeChoice,
                  builder: (context, theme) => _ThemeCard(
                      value: theme, onChanged: (v) => setThemeChoice(v)),
                ),
              ),
            ],
          ),
          const SizedBox(height: SsrSpace.md),
          Container(key: _cardThemeKey, child: const _CardThemeCard()),
          const SizedBox(height: SsrSpace.md),
          Container(key: _widgetKey, child: const _WidgetCard()),
          const SizedBox(height: SsrSpace.md),
          PremiumSectionHeader(title: tr('st_group_reminder')),
          const SizedBox(height: SsrSpace.sm),
          Container(key: _reminderKey, child: const _ReminderCard()),
          const SizedBox(height: SsrSpace.md),
          PremiumSectionHeader(title: tr('st_group_security')),
          const SizedBox(height: SsrSpace.sm),
          Container(key: _lockKey, child: const _LockTimeoutCard()),
          const SizedBox(height: SsrSpace.md),
          Container(key: _pinKey, child: const _PinCard()),
          const SizedBox(height: SsrSpace.md),
          const _BiometricCard(),
          const SizedBox(height: SsrSpace.md),
          const _VersionCard(),
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

/// Baris versi app (read-only, dari AppInfo — ikut bump pubspec).
/// Hero treatment kaca untuk seksi Tentang (Batch 5): GlassPanel +
/// tagline brand + angka versi.
class _VersionCard extends StatelessWidget {
  const _VersionCard();

  @override
  Widget build(BuildContext context) {
    const onHero = DribTokens.onNavy;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        gradient: DribTokens.balanceGradient,
        borderRadius:
            BorderRadius.circular(DribTokens.cardRadius),
        boxShadow: DribTokens.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr('st_group_about').toUpperCase(),
            style: const TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: GlassSpace.xs),
          Text(
            tr('sp_tagline'),
            style: const TextStyle(
              color: onHero,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: GlassSpace.sm),
          Text(
            '${tr('st_version')} ${AppInfo.version}',
            style: const TextStyle(color: Colors.white70),
          ),
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
    return GlassLabeledCard(
      label: tr('st_lang'),
      icon: AppIcons.menu,
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
    return GlassLabeledCard(
      label: tr('st_currency'),
      icon: AppIcons.billing,
      children: [
        DropdownButtonFormField<String>(dropdownColor: Colors.white,
          initialValue: value,
          decoration: const InputDecoration(),
          items: [
            for (final c in kCurrencySymbols.keys)
              DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(color: Color(0xFF12285A)))),
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
          style: OutlinedButton.styleFrom(
            foregroundColor: DribTokens.primary,
            side: const BorderSide(color: DribTokens.primary),
          ),
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
    return GlassLabeledCard(
      label: tr('st_font'),
      icon: AppIcons.settings,
      children: [
        Text(amt(100000)),
        Slider(
          value: value,
          min: 0.85,
          max: 1.3,
          divisions: 9,
          label: value.toStringAsFixed(2),
          activeColor: DribTokens.primary,
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
    return GlassLabeledCard(
      label: tr('st_def_currency'),
      icon: AppIcons.billing,
      children: [
        ValueListenableBuilder<String>(
          valueListenable: inputDefaultCurrency,
          builder: (context, value, _) => DropdownButtonFormField<String>(dropdownColor: Colors.white,
            initialValue: value,
            decoration: const InputDecoration(),
            items: [
              for (final c in kCurrencySymbols.keys)
                DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(color: Color(0xFF12285A)))),
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

/// Format angka: ID (1.000.000) atau US (1,000,000).
class _NumberFormatCard extends StatelessWidget {
  const _NumberFormatCard();

  @override
  Widget build(BuildContext context) {
    return GlassLabeledCard(
      label: tr('st_numformat'),
      icon: AppIcons.reports,
      children: [
        ValueListenableBuilder<String>(
          valueListenable: numberFormat,
          builder: (context, value, _) => SegmentedButton<String>(
            style: ssrSegmentedStyle(context),
            segments: const [
              ButtonSegment(value: 'id', label: Text('1.000.000')),
              ButtonSegment(value: 'us', label: Text('1,000,000')),
            ],
            selected: {value == 'us' ? 'us' : 'id'},
            showSelectedIcon: false,
            onSelectionChanged: (s) => setNumberFormat(s.first),
          ),
        ),
      ],
    );
  }
}

/// Dompet default form catat (id hilang = fallback Most-used).
class _DefaultWalletCard extends StatefulWidget {
  const _DefaultWalletCard();

  @override
  State<_DefaultWalletCard> createState() => _DefaultWalletCardState();
}

class _DefaultWalletCardState extends State<_DefaultWalletCard> {
  late Future<List<Wallet>> _wallets;

  @override
  void initState() {
    super.initState();
    _wallets = _load();
  }

  Future<List<Wallet>> _load() async {
    try {
      final orgId = await activeOrgId();
      if (orgId.isEmpty) return [];
      return await WalletService().list(orgId);
    } catch (_) {
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return GlassLabeledCard(
      label: tr('st_def_wallet'),
      icon: AppIcons.wallet,
      children: [
        FutureBuilder<List<Wallet>>(
          future: _wallets,
          builder: (context, snap) {
            final ws = snap.data ?? [];
            return ValueListenableBuilder<String>(
              valueListenable: defaultWalletId,
              builder: (context, value, _) {
                final valid =
                    ws.any((w) => w.id == value) ? value : '';
                return DropdownButtonFormField<String>(dropdownColor: Colors.white,
                  initialValue: valid,
                  decoration: const InputDecoration(),
                  items: [
                    DropdownMenuItem(
                      value: '',
                      child: Text(tr('st_def_wallet_none'), style: const TextStyle(color: Color(0xFF12285A))),
                    ),
                    for (final w in ws)
                      DropdownMenuItem(value: w.id, child: Text(w.name, style: const TextStyle(color: Color(0xFF12285A)))),
                  ],
                  onChanged: (v) => setDefaultWalletId(v ?? ''),
                );
              },
            );
          },
        ),
      ],
    );
  }
}

/// Hari awal minggu: Senin atau Minggu.
class _WeekStartCard extends StatelessWidget {
  const _WeekStartCard();

  @override
  Widget build(BuildContext context) {
    return GlassLabeledCard(
      label: tr('st_weekstart'),
      icon: AppIcons.calendar,
      children: [
        ValueListenableBuilder<int>(
          valueListenable: weekStart,
          builder: (context, value, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SegmentedButton<int>(
                style: ssrSegmentedStyle(context),
                segments: [
                  ButtonSegment(value: 1, label: Text(tr('wd_1'))),
                  ButtonSegment(value: 7, label: Text(tr('wd_7'))),
                ],
                selected: {value == 7 ? 7 : 1},
                showSelectedIcon: false,
                onSelectionChanged: (s) => setWeekStart(s.first),
              ),
              const SizedBox(height: 4),
              Text(
                tr('st_weekstart_sub'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Timeout kunci otomatis setelah background (PIN harus terpasang).
class _LockTimeoutCard extends StatelessWidget {
  const _LockTimeoutCard();

  static const _options = [1, 5, 15, 30];

  @override
  Widget build(BuildContext context) {
    return GlassLabeledCard(
      label: tr('st_lock_timeout'),
      icon: AppIcons.lock,
      children: [
        ValueListenableBuilder<int>(
          valueListenable: lockTimeoutMinutes,
          builder: (context, value, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SegmentedButton<int>(
                style: ssrSegmentedStyle(context),
                segments: [
                  for (final m in _options)
                    ButtonSegment(
                      value: m,
                      label: Text(
                        tr('st_lock_min').replaceFirst('{n}', '$m'),
                      ),
                    ),
                ],
                selected: {
                  _options.contains(value) ? value : 5,
                },
                showSelectedIcon: false,
                onSelectionChanged: (s) => setLockTimeoutMinutes(s.first),
              ),
              const SizedBox(height: 4),
              Text(
                tr('st_lock_sub'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
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
    return GlassLabeledCard(
      label: tr('st_topn'),
      icon: AppIcons.reports,
      children: [
        ValueListenableBuilder<bool>(
          valueListenable: reportsTopN,
          builder: (context, value, _) => SwitchListTile(
            activeThumbColor: DribTokens.primary,
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
    return GlassLabeledCard(
      label: tr('st_anims'),
      icon: AppIcons.menu,
      children: [
        ValueListenableBuilder<bool>(
          valueListenable: uiAnims,
          builder: (context, value, _) => SwitchListTile(
            activeThumbColor: DribTokens.primary,
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
    return GlassLabeledCard(
      label: tr('st_list_style'),
      icon: AppIcons.menu,
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
    return GlassLabeledCard(
      label: tr('st_date_style'),
      icon: AppIcons.calendar,
      children: [
        ValueListenableBuilder<String>(
          valueListenable: uiDateStyle,
          builder: (context, value, _) => DropdownButtonFormField<String>(dropdownColor: Colors.white,
            initialValue: _styles.contains(value) ? value : 'system',
            decoration: const InputDecoration(),
            items: [
              for (final s in _styles)
                DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(color: Color(0xFF12285A)))),
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
    return GlassLabeledCard(
      label: tr('st_hero_style'),
      icon: AppIcons.eye,
      children: [
        ValueListenableBuilder<String>(
          valueListenable: uiHeroStyle,
          builder: (context, value, _) => DropdownButtonFormField<String>(dropdownColor: Colors.white,
            initialValue: value == 'emerald-calm' ? value : 'emerald-calm',
            decoration: const InputDecoration(),
            items: const [
              DropdownMenuItem(
                value: 'emerald-calm',
                child: Text('emerald-calm', style: TextStyle(color: Color(0xFF12285A))),
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

/// Tema kartu saldo: varian gradient kartu (navy/ocean/midnight/steel).
class _CardThemeCard extends StatelessWidget {
  const _CardThemeCard();

  static const _themes = ['navy', 'ocean', 'midnight', 'steel'];

  @override
  Widget build(BuildContext context) {
    return GlassLabeledCard(
      label: tr('st_card_theme'),
      icon: AppIcons.eye,
      children: [
        ValueListenableBuilder<String>(
          valueListenable: cardTheme,
          builder: (context, value, _) => DropdownButtonFormField<String>(
            dropdownColor: Colors.white,
            initialValue: _themes.contains(value) ? value : 'navy',
            decoration: const InputDecoration(),
            items: [
              DropdownMenuItem(
                value: 'navy',
                child: Text(
                  tr('st_card_navy'),
                  style: const TextStyle(color: Color(0xFF12285A)),
                ),
              ),
              DropdownMenuItem(
                value: 'ocean',
                child: Text(
                  tr('st_card_ocean'),
                  style: const TextStyle(color: Color(0xFF12285A)),
                ),
              ),
              DropdownMenuItem(
                value: 'midnight',
                child: Text(
                  tr('st_card_midnight'),
                  style: const TextStyle(color: Color(0xFF12285A)),
                ),
              ),
              DropdownMenuItem(
                value: 'steel',
                child: Text(
                  tr('st_card_steel'),
                  style: const TextStyle(color: Color(0xFF12285A)),
                ),
              ),
            ],
            onChanged: (v) {
              if (v != null) setCardTheme(v);
            },
          ),
        ),
      ],
    );
  }
}

/// Tema aplikasi: Otomatis (ikut sistem) atau Noir.
class _ThemeCard extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;

  const _ThemeCard({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GlassLabeledCard(
      label: tr('st_theme'),
      icon: AppIcons.eye,
      children: [
        SegmentedButton<String>(
          style: ssrSegmentedStyle(context),
          segments: [
            ButtonSegment(value: 'otomatis', label: Text(tr('th_auto'))),
            ButtonSegment(value: 'noir', label: Text(tr('th_noir'))),
          ],
          selected: {value},
          showSelectedIcon: false,
          onSelectionChanged: (s) => onChanged(s.first),
        ),
        const SizedBox(height: SsrSpace.sm),
        Text(tr('th_theme_desc'), style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

/// Pengingat harian: toggle + jam via TimePicker.
class _ReminderCard extends StatelessWidget {
  const _ReminderCard();

  Future<void> _toggle(BuildContext context, bool v) async {
    if (v && !await ReminderService.notificationsAllowed()) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('st_notif_denied'))),
        );
      }
      return;
    }
    await setReminderEnabled(v);
    try {
      if (v) {
        await ReminderService.scheduleDaily(
          reminderHour.value,
          reminderMinute.value,
          interactive: true,
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
      await ReminderService.scheduleDaily(
        t.hour,
        t.minute,
        interactive: true,
      );
    } catch (e) {
      debugPrint('pengingat gagal: $e');
    }
  }

  String _fmt(int h, int m) =>
      '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return GlassLabeledCard(
      label: tr('st_reminder_time'),
      icon: AppIcons.clock,
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
                    activeThumbColor: DribTokens.primary,
                    contentPadding: EdgeInsets.zero,
                    title: Text(tr('st_reminder_on')),
                    value: enabled,
                    onChanged: (v) => _toggle(context, v),
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
        const _WeeklySection(),
      ],
    );
  }
}

/// Pengingat mingguan: toggle + hari + jam via TimePicker.
/// Id notif 7002, terpisah dari harian agar tak saling menimpa.
class _WeeklySection extends StatelessWidget {
  const _WeeklySection();

  Future<void> _toggle(BuildContext context, bool v) async {
    if (v && !await ReminderService.notificationsAllowed()) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('st_notif_denied'))),
        );
      }
      return;
    }
    await setWeeklyEnabled(v);
    try {
      if (v) {
        await ReminderService.scheduleWeekly(
          weeklyWeekday.value,
          weeklyHour.value,
          weeklyMinute.value,
          interactive: true,
        );
      } else {
        await ReminderService.cancelWeekly();
      }
    } catch (e) {
      debugPrint('pengingat mingguan gagal: $e');
    }
  }

  Future<void> _pick(BuildContext context, int h, int m) async {
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: h, minute: m),
    );
    if (t == null) return;
    await setWeeklyTime(t.hour, t.minute);
    if (!weeklyEnabled.value) return;
    try {
      await ReminderService.scheduleWeekly(
        weeklyWeekday.value,
        t.hour,
        t.minute,
        interactive: true,
      );
    } catch (e) {
      debugPrint('pengingat mingguan gagal: $e');
    }
  }

  Future<void> _pickDay(int? wd) async {
    if (wd == null) return;
    await setWeeklyDay(wd);
    if (!weeklyEnabled.value) return;
    try {
      await ReminderService.scheduleWeekly(
        wd,
        weeklyHour.value,
        weeklyMinute.value,
        interactive: true,
      );
    } catch (e) {
      debugPrint('pengingat mingguan gagal: $e');
    }
  }

  String _fmt(int h, int m) =>
      '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: weeklyEnabled,
      builder: (context, enabled, _) => ValueListenableBuilder<int>(
        valueListenable: weeklyWeekday,
        builder: (context, wd, _) => ValueListenableBuilder<int>(
          valueListenable: weeklyHour,
          builder: (context, h, _) => ValueListenableBuilder<int>(
            valueListenable: weeklyMinute,
            builder: (context, m, _) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Divider(height: 1),
                SwitchListTile(
                  activeThumbColor: DribTokens.primary,
                  contentPadding: EdgeInsets.zero,
                  title: Text(tr('st_weekly_on')),
                  value: enabled,
                  onChanged: (v) => _toggle(context, v),
                ),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButton<int>(
                        value: wd,
                        isExpanded: true,
                        items: [
                          for (var d = 1; d <= 7; d++)
                            DropdownMenuItem(
                              value: d,
                              child: Text(tr('wd_$d')),
                            ),
                        ],
                        onChanged: _pickDay,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _fmt(h, m),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    IconButton(
                      icon: const DuoIcon(AppIcons.clock),
                      tooltip: tr('st_weekly_time'),
                      onPressed: () => _pick(context, h, m),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
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
    return GlassLabeledCard(
      label: tr('st_widget_today'),
      icon: AppIcons.transactions,
      children: [
        ValueListenableBuilder<bool>(
          valueListenable: widgetToday,
          builder: (context, value, _) => SwitchListTile(
            activeThumbColor: DribTokens.primary,
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

/// AI Parser struk via Firebase: aktif otomatis bila login Google,
/// tanpa input kunci. Mati diam bila belum login (jujur di subtitle).
class _AiCard extends StatefulWidget {
  const _AiCard();

  @override
  State<_AiCard> createState() => _AiCardState();
}

class _AiCardState extends State<_AiCard> {
  bool _on = true;
  bool _busy = true;
  String? _msg;
  String? _quotaInfo;
  bool _hasZenKey = false;
  final _zenKeyC = TextEditingController();

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _zenKeyC.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final on = await aiEnabled();
    final hit = await lastQuotaHit();
    final zenKey = await readZenKey();
    if (!mounted) return;
    setState(() {
      _on = on;
      _busy = false;
      _hasZenKey = zenKey != null;
      _quotaInfo = hit == null
          ? null
          : '${dayLabel(_ymd(hit))} '
              '${hit.hour.toString().padLeft(2, '0')}:'
              '${hit.minute.toString().padLeft(2, '0')}';
    });
  }

  static String _ymd(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  Future<void> _toggle(bool v) async {
    setState(() => _busy = true);
    await setAiEnabled(v);
    await _refresh();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _msg = null;
    });
  }

  Future<void> _saveZenKey() async {
    setState(() => _busy = true);
    await writeZenKey(_zenKeyC.text);
    _zenKeyC.clear();
    await _refresh();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _msg = tr('ai_saved');
    });
  }

  Future<void> _clearZenKey() async {
    setState(() => _busy = true);
    await clearZenKey();
    await _refresh();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _msg = tr('ai_cleared');
    });
  }

  /// Tes AI via Zen langsung ("Halo"): tampilkan jawaban mentah atau
  /// sebab gagal mentah. Tanpa kunci = mode anonim.
  Future<void> _testAi() async {
    setState(() {
      _busy = true;
      _msg = tr('ai_working');
    });
    // Gate kuota AI (entitlement Fase 1): Tes = aksi user eksplisit ->
    // mentok = paywall + batal (tanpa panggil model).
    // Fail-open: server diam -> lolos (aiAllowed true).
    final orgId = await activeOrgId();
    if (orgId.isNotEmpty && !await aiAllowed(orgId)) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _msg = null;
      });
      await requirePro(context, tr('q_ai_exceeded'));
      return;
    }
    String out;
    try {
      final r = await aiChatViaCli('Halo')
          .timeout(const Duration(seconds: 120));
      // Sukses -> catat pemakaian kuota AI (fail-silent, tanpa blokir UI).
      if (orgId.isNotEmpty) unawaited(recordAiUse(orgId, 'chat'));
      out = '[CLI: ${r.provider}]\n'
          '${r.text.trim().isEmpty ? 'AI: (kosong)' : r.text}';
    } on AiFailure catch (e) {
      if (e.code == 'quota') await noteQuotaHit();
      out = e.code == 'quota'
          ? '[CLI] ${quotaWaitLine(e.detail)}'
          : '[CLI] AI gagal (${e.code})'
              '${e.detail == null ? '' : '\n${e.detail}'}';
    } on TimeoutException catch (e) {
      out = '[CLI] AI gagal (timeout)\n$e';
    } catch (e) {
      out = '[CLI] AI gagal (tak dikenal)\n$e';
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _msg = null;
    });
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('ai_test')),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: SelectableText(out),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(tr('rcp_raw_close')),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              unawaited(_testAi());
            },
            child: Text(tr('ai_retry')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // AI Parser di-hide: sudah ada OpenCode lokal di Mang AI
    return const SizedBox.shrink();
    // ignore: dead_code
    return GlassLabeledCard(
      label: tr('ai_title'),
      icon: AppIcons.autoBadge,
      children: [
        Text(tr('ai_sub'), style: Theme.of(context).textTheme.bodySmall),
        SwitchListTile(
          activeThumbColor: DribTokens.primary,
          contentPadding: EdgeInsets.zero,
          title: Text(tr('ai_enable')),
          subtitle: Text(
            _hasZenKey ? tr('ai_zen_saved') : tr('ai_zen_anon'),
          ),
          value: _on,
          onChanged: _busy ? null : _toggle,
        ),
        const SizedBox(height: SsrSpace.xs),
        // Kunci Zen tak pernah tampil mentah: hanya status ***.
        SelectableText(
          tr('ai_zen_where'),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
        ),
        const SizedBox(height: SsrSpace.xs),
        TextField(
          controller: _zenKeyC,
          obscureText: true,
          enableSuggestions: false,
          autocorrect: false,
          decoration: InputDecoration(
            hintText: tr('ai_zen_hint'),
            border: const OutlineInputBorder(),
            isDense: true,
          ),
        ),
        const SizedBox(height: SsrSpace.sm),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _busy ? null : _saveZenKey,
                child: Text(tr('ai_save')),
              ),
            ),
            const SizedBox(width: SsrSpace.sm),
            Expanded(
              child: OutlinedButton(
                onPressed: _busy ? null : _clearZenKey,
                child: Text(tr('ai_clear')),
              ),
            ),
          ],
        ),
        const SizedBox(height: SsrSpace.xs),
        Text(
          tr('ai_quota_info'),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        if (_quotaInfo != null)
          Text(
            '${tr('ai_quota_last')} $_quotaInfo',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
          ),
        const SizedBox(height: SsrSpace.sm),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: _busy ? null : _testAi,
            child: Text(tr('ai_test')),
          ),
        ),
        if (_msg != null) ...[
          const SizedBox(height: SsrSpace.xs),
          Text(_msg!, style: Theme.of(context).textTheme.bodySmall),
        ],
      ],
    );
  }
}

/// Biometrik sebagai alternatif PIN (opt-in, default mati).
/// Toggle hanya aktif bila HP mendukung + ada biometrik terdaftar;
/// buka kunci tetap bisa lewat PIN kapan saja.
class _BiometricCard extends StatefulWidget {
  const _BiometricCard();

  @override
  State<_BiometricCard> createState() => _BiometricCardState();
}

class _BiometricCardState extends State<_BiometricCard> {
  bool? supported;

  @override
  void initState() {
    super.initState();
    BiometricAuth.isSupported().then((v) {
      if (mounted) setState(() => supported = v);
    });
  }

  Future<void> _toggle(bool v) async {
    if (v && supported != true) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('bio_unsupported'))),
      );
      return;
    }
    await setBiometricEnabled(v);
  }

  @override
  Widget build(BuildContext context) {
    return GlassLabeledCard(
      label: tr('bio_t'),
      icon: AppIcons.success,
      children: [
        ValueListenableBuilder<bool>(
          valueListenable: biometricEnabled,
          builder: (context, enabled, _) => SwitchListTile(
            activeThumbColor: DribTokens.primary,
            contentPadding: EdgeInsets.zero,
            title: Text(tr('bio_t')),
            subtitle: Text(
              supported == false ? tr('bio_unsupported') : tr('bio_s'),
            ),
            value: enabled && supported == true,
            onChanged: supported == null ? null : _toggle,
          ),
        ),
      ],
    );
  }
}

/// Ganti PIN: verifikasi PIN lama dulu -> PIN baru 2x.
/// Lupa PIN lama? Kirim magic link ke email (jalur lama) sebagai cadangan.
class _PinCard extends StatefulWidget {
  const _PinCard();

  @override
  State<_PinCard> createState() => _PinCardState();
}

class _PinCardState extends State<_PinCard> {
  String step = 'checkOld';
  String? msg;
  String? err;
  bool busy = false;
  final oldC = TextEditingController();
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
    oldC.dispose();
    pinC.dispose();
    pin2C.dispose();
    super.dispose();
  }

  void _onLinkVerified() {
    if (pinLinkVerified.value && mounted && step == 'sent') {
      setState(() => step = 'verified');
    }
  }

  Future<void> _checkOld() async {
    setState(() {
      busy = true;
      err = null;
      msg = null;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      final svc = SessionService(prefs);
      if (!svc.hasPin) {
        if (!mounted) return;
        setState(() => step = 'newPin');
        return;
      }
      if (svc.isLockedOut) {
        if (!mounted) return;
        setState(() => err = tr('lk_lockout'));
        return;
      }
      final ok = await svc.verifyPin(oldC.text);
      if (!mounted) return;
      if (ok) {
        setState(() => step = 'newPin');
        oldC.clear();
      } else {
        setState(
          () => err = svc.isLockedOut ? tr('lk_lockout') : tr('b_pin_wrong'),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
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
        step = 'checkOld';
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
    return GlassLabeledCard(
      label: tr('st_pin'),
      icon: AppIcons.lock,
      children: [
        _PinFeedback(msg: msg, err: err),
        if (step == 'checkOld') ...[
          Text(tr('st_pin_old'), style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: SsrSpace.sm),
          PinField(controller: oldC, length: 6, digitColor: Colors.white),
          const SizedBox(height: SsrSpace.md),
          PinPad(controller: oldC, length: 6),
          const SizedBox(height: SsrSpace.md),
          PrimaryButton(
            label: tr('st_pin_next'),
            loading: busy,
            onPressed: _checkOld,
          ),
          TextButton(
            onPressed: busy
                ? null
                : () => setState(() {
                    step = 'idle';
                    err = null;
                  }),
            style: TextButton.styleFrom(
              foregroundColor: DribTokens.primary,
            ),
            child: Text(tr('st_pin_forgot')),
          ),
        ],
        if (step == 'idle')
          PrimaryButton(
            label: tr('st_pin_send'),
            loading: busy,
            onPressed: _send,
          ),
        if (step == 'sent') _WaitLink(busy: busy, onResend: _send),
        if (step == 'verified' || step == 'newPin')
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
            style: TextStyle(
              color: Colors.red.shade200,
              fontSize: 12,
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
          style: TextButton.styleFrom(
            foregroundColor: DribTokens.primary,
          ),
          child: Text(tr('st_pin_resend')),
        ),
      ],
    );
  }
}

/// Form PIN baru 2x: kolom aktif ditandai border primer; pad menulis
/// ke kolom aktif (ketuk kotak untuk pindah kolom).
class _NewPinForm extends StatefulWidget {
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
  State<_NewPinForm> createState() => _NewPinFormState();
}

class _NewPinFormState extends State<_NewPinForm> {
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PinField(
          controller: widget.pinC,
          length: 6,
          selected: _activePin == 0,
          onTap: () => _select(0),
          digitColor: Colors.white,
        ),
        const SizedBox(height: SsrSpace.md),
        PinField(
          controller: widget.pin2C,
          length: 6,
          selected: _activePin == 1,
          onTap: () => _select(1),
          digitColor: Colors.white,
        ),
        const SizedBox(height: SsrSpace.lg),
        PinPad(
          controller: _activePin == 0 ? widget.pinC : widget.pin2C,
          length: 6,
        ),
        const SizedBox(height: SsrSpace.md),
        PrimaryButton(
          label: tr('st_pin_save'),
          loading: widget.busy,
          onPressed: widget.onSave,
        ),
      ],
    );
  }
}
