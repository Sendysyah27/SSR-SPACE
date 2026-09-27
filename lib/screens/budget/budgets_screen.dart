import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ssr_space/utils/org_prefs.dart';
import 'package:ssr_space/utils/mask.dart';
import 'package:ssr_space/services/budget_service.dart';
import 'package:ssr_space/services/category_meta.dart';
import 'package:ssr_space/services/saving.dart';
import 'package:ssr_space/services/month.dart';
import 'package:ssr_space/services/session_service.dart';
import 'package:ssr_space/services/currency.dart';
import 'package:ssr_space/services/app_settings.dart';
import 'package:ssr_space/utils/strings.dart';
import 'package:ssr_space/theme/app_icons.dart';
import 'package:ssr_space/theme/app_theme.dart';
import 'package:ssr_space/theme/app_typography.dart';
import 'package:ssr_space/widgets/pin_field.dart';
import 'package:ssr_space/widgets/category_chips.dart';
import 'package:ssr_space/widgets/primary_button.dart';
import 'package:ssr_space/widgets/section_card.dart';
import 'package:ssr_space/widgets/skeletons.dart';
import 'package:ssr_space/widgets/state_views.dart';
import 'package:ssr_space/widgets/status_chip.dart';
import 'package:ssr_space/widgets/success_lottie.dart';

class BudgetsScreen extends StatefulWidget {
  const BudgetsScreen({super.key});
  @override
  State<BudgetsScreen> createState() => BudgetsScreenState();
}

class BudgetsScreenState extends State<BudgetsScreen> {
  BudgetMonth? data;
  bool loading = true;
  bool saving = false;
  String? err;
  String? formErr;
  final catC = TextEditingController();
  final limitC = TextEditingController();
  final catFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    catC.dispose();
    limitC.dispose();
    catFocus.dispose();
    super.dispose();
  }

  Future<void> reload() => _load();

  String get _title => '${tr('nav_budget')} ${monthLabel(currentMonth())}';

  Future<void> _load() async {
    setState(() {
      loading = true;
      err = null;
    });
    try {
      final orgId = await activeOrgId();
      if (orgId.isEmpty) {
        setState(() => loading = false);
        return;
      }
      final b = await fetchBudgets(orgId);
      if (!mounted) return;
      setState(() {
        data = b;
        loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        loading = false;
        err = tr('b_err_load');
      });
    }
  }

  Future<void> _save() async {
    final cat = topOf(catC.text);
    final typedLimit = double.tryParse(limitC.text);
    final limit = typedLimit == null ? null : CurrencyService.toIdr(typedLimit);
    if (cat.isEmpty) {
      setState(() => formErr = tr('b_err_cat'));
      return;
    }
    if (catC.text.contains('>')) {
      // Budget selalu lapis kategori: sub ditolak, bukan dipotong diam-diam.
      setState(() => formErr = tr('sub_sep_err'));
      return;
    }
    if (limit == null || limit <= 0) {
      setState(() => formErr = tr('b_err_limit'));
      return;
    }
    setState(() {
      formErr = null;
      saving = true;
    });
    try {
      await setBudget(await activeOrgId(), cat, limit);
      catC.clear();
      limitC.clear();
      await _load();
      if (mounted) {
        unawaited(showSuccessFlash(context));
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(tr('b_saved'))));
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => formErr = tr('b_err_save'));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  void _focusForm() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      catFocus.requestFocus();
    });
  }

  Future<void> _openEdit(Budget b) async {
    final scheme = Theme.of(context).colorScheme;
    final whole = b.limit.truncateToDouble() == b.limit;
    final limitC = TextEditingController(
      text: b.limit.toStringAsFixed(whole ? 0 : 2),
    );
    try {
      final value = await showDialog<dynamic>(
        context: context,
        builder: (ctx) {
          String? err;
          return StatefulBuilder(
            builder: (ctx, setD) => AlertDialog(
              title: Text(tr('b_edit_title').replaceFirst('{c}', b.category)),
              content: TextField(
                controller: limitC,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: tr('b_f_limit'),
                  prefixText:
                      '${kCurrencySymbols[currencyCode.value] ?? 'Rp'} ',
                  errorText: err,
                ),
              ),
              actions: [
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: scheme.error,
                  ),
                  onPressed: () => Navigator.pop(ctx, 'delete'),
                  child: Text(tr('b_delete')),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(tr('cancel')),
                ),
                TextButton(
                  onPressed: () {
                    final v = double.tryParse(limitC.text);
                    if (v == null || v <= 0) {
                      setD(() => err = tr('b_err_limit'));
                      return;
                    }
                    Navigator.pop(ctx, v);
                  },
                  child: Text(tr('save')),
                ),
              ],
            ),
          );
        },
      );
      if (!mounted) return;
      if (value == 'delete') {
        await _deleteBudget(b);
        return;
      }
      if (value is! double) return;
      final ok = await _confirmPin();
      if (!ok || !mounted) return;
      try {
        await setBudget(await activeOrgId(), b.category, value);
        await _load();
        if (!mounted) return;
        unawaited(showSuccessFlash(context));
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(tr('b_updated'))));
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(tr('b_err_save'))));
      }
    } finally {
      limitC.dispose();
    }
  }

  Future<void> _deleteBudget(Budget b) async {
    final scheme = Theme.of(context).colorScheme;
    final sure = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('b_del_title').replaceFirst('{c}', b.category)),
        content: Text(tr('b_del_body').replaceFirst('{c}', b.category)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(tr('cancel')),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: scheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(tr('b_delete')),
          ),
        ],
      ),
    );
    if (sure != true || !mounted) return;
    final ok = await _confirmPin();
    if (!ok || !mounted) return;
    try {
      await deleteBudget(await activeOrgId(), b.category);
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(tr('b_deleted'))));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(tr('b_err_save'))));
    }
  }

  Future<bool> _confirmPin() async {
    final pinC = TextEditingController();
    try {
      return await showDialog<bool>(
            context: context,
            builder: (ctx) {
              String? err;
              return StatefulBuilder(
                builder: (ctx, setD) => AlertDialog(
                  title: Text(tr('b_pin_title')),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tr('b_pin_body')),
                      const SizedBox(height: SsrSpace.md),
                      PinField(
                        controller: pinC,
                        length: 6,
                        autofocus: true,
                        error: err,
                        onCompleted: (_) =>
                            _submitPin(ctx, setD, pinC, (String? e) => err = e),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: Text(tr('cancel')),
                    ),
                  ],
                ),
              );
            },
          ) ??
          false;
    } finally {
      pinC.dispose();
    }
  }

  Future<void> _submitPin(
    BuildContext ctx,
    StateSetter setD,
    TextEditingController pinC,
    void Function(String? err) setErr,
  ) async {
    final ok = await SessionService(await SharedPreferences.getInstance())
        .verifyPin(pinC.text);
    if (!ctx.mounted) return;
    if (ok) {
      Navigator.pop(ctx, true);
      return;
    }
    pinC.clear();
    setD(() => setErr(tr('b_pin_wrong')));
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Scaffold(
        appBar: AppBar(title: Text(_title)),
        body: const BudgetListSkeleton(),
      );
    }
    if (err != null) {
      return Scaffold(
        appBar: AppBar(title: Text(_title)),
        body: ErrorView(message: err!, onRetry: _load),
      );
    }
    final items = data?.items ?? [];
    final urgent = urgentBudgetCategory(items);
    return Scaffold(
      appBar: AppBar(title: Text(_title)),
      body: ListView(
        padding: const EdgeInsets.all(SsrSpace.lg),
        children: [
          _OverAllocBanner(data: data),
          if (items.isEmpty)
            EmptyView(
              icon: AppIcons.budget,
              illustration: 'assets/illustrations/empty_budget.svg',
              title: tr('b_empty_t'),
              subtitle: tr('b_empty_s'),
              actionLabel: tr('b_empty_a'),
              onAction: _focusForm,
            ),
          for (final b in items)
            _BudgetEntry(
              budget: b,
              urgent: b.category == urgent,
              onTap: () => _openEdit(b),
            ),
          const SizedBox(height: SsrSpace.md),
          _BudgetForm(
            catC: catC,
            limitC: limitC,
            catFocus: catFocus,
            formErr: formErr,
            saving: saving,
            onSave: _save,
          ),
        ],
      ),
    );
  }
}

/// Kategori belanja paling mendesak bulan ini: persen tertinggi di bawah
/// 100 persen; bila semua sudah jebol, yang tertinggi. Satu nama saja.
/// Kartu tabungan dikecualikan (cincinnya selalu emas, maknanya terkumpul,
/// bukan terpakai). Murni baca, math progres tak berubah.
String? urgentBudgetCategory(List<Budget> items) {
  String? best;
  var bestPct = -1.0;
  for (final b in items) {
    if (isSavingCategory(b.category) || b.limit <= 0) continue;
    final pct = b.spent / b.limit;
    if (pct < 1 && pct > bestPct) {
      bestPct = pct;
      best = b.category;
    }
  }
  if (best != null) return best;
  for (final b in items) {
    if (isSavingCategory(b.category) || b.limit <= 0) continue;
    final pct = b.spent / b.limit;
    if (pct > bestPct) {
      bestPct = pct;
      best = b.category;
    }
  }
  return best;
}

/// Warna cincin budget: jebol tampil rust, satu kategori mendesak tampil
/// gold, sisanya emerald. Penentu mendesak lihat [urgentBudgetCategory].
/// Bila yang mendesak ternyata sudah jebol, rust menang (jebol duluan).
Color budgetRingColor({
  required bool over,
  required bool urgent,
  required ColorScheme scheme,
}) {
  if (over) return scheme.error;
  if (urgent) return AppColors.gold;
  return scheme.primary;
}

/// Banner: total limit bulan ini melebihi pemasukan bulan ini.
/// Sembunyi sendiri bila tak over-alloc (pola _NoWalletBanner).
class _OverAllocBanner extends StatelessWidget {
  final BudgetMonth? data;

  const _OverAllocBanner({required this.data});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final totalIn = data?.totalIn ?? 0;
    final totalLimit = data?.totalLimit ?? 0;
    if (!(totalIn > 0 && totalLimit > totalIn)) {
      return const SizedBox.shrink();
    }
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: SsrSpace.sm),
      padding: const EdgeInsets.all(SsrSpace.md),
      decoration: BoxDecoration(
        color: scheme.error.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(SsrRadius.tile),
        border: Border.all(
          color: scheme.error.withValues(alpha: 0.45),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr('b_over_alloc'),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: SsrSpace.xs),
          Text(
            '${amt(totalLimit)} vs ${amt(totalIn)}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

/// Satu baris budget: kartu tabungan bila kategorinya tabungan,
///
/// kartu biasa bila bukan. Ketuk untuk ubah/hapus.
class _BudgetEntry extends StatelessWidget {
  final Budget budget;
  final bool urgent;
  final VoidCallback onTap;

  const _BudgetEntry({
    required this.budget,
    this.urgent = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: isSavingCategory(budget.category)
          ? _SavingCard(budget: budget)
          : _BudgetCard(budget: budget, urgent: urgent),
    );
  }
}

/// Kartu target tabungan: ilustrasi + nama + chip progres + angka
/// "terkumpul dari target" + cincin emas (reuse _BudgetGauge).
class _SavingCard extends StatelessWidget {
  final Budget budget;

  const _SavingCard({required this.budget});

  @override
  Widget build(BuildContext context) {
    final b = budget;
    final pct = b.limit > 0 ? (b.spent / b.limit * 100).round() : 0;
    final done = pct >= 100;
    return SectionCard(
      color: AppColors.gold.withValues(alpha: 0.14),
      borderColor: AppColors.gold.withValues(alpha: 0.45),
      margin: const EdgeInsets.only(bottom: SsrSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SvgPicture.asset(
                'assets/illustrations/savings.svg',
                height: 64,
                fit: BoxFit.contain,
              ),
              const SizedBox(width: SsrSpace.md),
              Expanded(
                child: Text(
                  b.category,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              _SavingChip(pct: pct, done: done),
            ],
          ),
          const SizedBox(height: SsrSpace.xs),
          _SavingProgress(budget: b, pct: pct, done: done),
          _SavingPace(budget: b, done: done),
        ],
      ),
    );
  }
}

/// Baris cincin emas + angka "terkumpul dari target" di kartu tabungan.
class _SavingProgress extends StatelessWidget {
  final Budget budget;
  final int pct;
  final bool done;

  const _SavingProgress({
    required this.budget,
    required this.pct,
    required this.done,
  });

  @override
  Widget build(BuildContext context) {
    final b = budget;
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        _BudgetGauge(
          progress: budgetProgress(b.spent, b.limit),
          pct: done ? 100 : pct,
          color: AppColors.gold,
        ),
        const SizedBox(width: SsrSpace.md),
        Expanded(
          child: Text(
            '${amt(b.spent)} ${tr('sv_of')} ${amt(b.limit)}',
            style: SsrType.moneyMedium.copyWith(color: scheme.onSurface),
          ),
        ),
      ],
    );
  }
}

/// Baris pace tabungan; sembunyi sendiri bila target tercapai.
class _SavingPace extends StatelessWidget {
  final Budget budget;
  final bool done;

  const _SavingPace({required this.budget, required this.done});

  @override
  Widget build(BuildContext context) {
    final b = budget;
    if (done || b.limit <= 0) return const SizedBox.shrink();
    final pace = savingPace(
      saved: b.spent,
      target: b.limit,
      today: DateTime.now(),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: SsrSpace.xs),
        Text(
          pace.onTrack
              ? tr('sv_pace_track').replaceFirst('{m}', amt(pace.projected))
              : tr('sv_pace_need').replaceFirst('{m}', amt(pace.needPerDay)),
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

/// Chip persen emas solid; teks gelap (pasangan #0C1210 di gold 7.80,
/// lolos AA; tint emas di atas kartu tint hanya 4.03 sehingga tak dipakai).
class _SavingChip extends StatelessWidget {
  final int pct;
  final bool done;

  const _SavingChip({required this.pct, required this.done});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.gold,
        borderRadius: BorderRadius.circular(SsrRadius.chip),
      ),
      child: Text(
        done ? tr('sv_done') : '$pct%',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: scheme.surfaceContainerLowest,
          height: 1.2,
        ),
      ),
    );
  }
}

/// Kartu satu kategori: nama + chip (persen / lebih batas), angka
/// "terpakai dari batas", dan bar progres.
class _BudgetCard extends StatelessWidget {
  final Budget budget;
  final bool urgent;

  const _BudgetCard({required this.budget, this.urgent = false});

  @override
  Widget build(BuildContext context) {
    final b = budget;
    final over = b.spent > b.limit;
    final progress = budgetProgress(b.spent, b.limit);
    final pct = b.limit > 0 ? (b.spent / b.limit * 100).round() : 0;
    final ring = budgetRingColor(
      over: over,
      urgent: urgent,
      scheme: Theme.of(context).colorScheme,
    );
    return SectionCard(
      margin: const EdgeInsets.only(bottom: SsrSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  b.category,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              if (over)
                StatusChip(label: tr('b_over'), tone: StatusTone.danger)
              else
                StatusChip(label: '$pct%', tone: StatusTone.accent),
            ],
          ),
          const SizedBox(height: SsrSpace.xs),
          Row(
            children: [
              _BudgetGauge(
                progress: progress,
                over: over,
                pct: pct,
                color: ring,
              ),
              const SizedBox(width: SsrSpace.md),
              Expanded(
                child: Text(
                  '${amt(b.spent)} dari ${amt(b.limit)}',
                  style: SsrType.moneyMedium.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Cincin progres budget: terpakai (emerald, gold, atau rust) vs sisa.
/// [color] opsional untuk varian lain (misal emas tabungan);
/// sisa default ikut outline tema agar adaptif light dan dark.
class _BudgetGauge extends StatelessWidget {
  final double progress;
  final bool over;
  final int pct;
  final Color? color;

  const _BudgetGauge({
    required this.progress,
    this.over = false,
    required this.pct,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final used = progress.clamp(0.0, 1.0).toDouble();
    final main = color ?? (over ? scheme.error : scheme.primary);
    final track = Theme.of(context).colorScheme.outline;
    return SizedBox(
      width: 56,
      height: 56,
      child: Stack(
        children: [
          PieChart(
            _gaugeData(used, main, track),
            duration: SsrMotion.base,
            curve: SsrMotion.curve,
          ),
          Center(
            child: Text(
              '$pct',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: main,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

PieChartData _gaugeData(double used, Color main, Color rest) {
  return PieChartData(
    pieTouchData: PieTouchData(enabled: false),
    sectionsSpace: 0,
    centerSpaceRadius: 20,
    startDegreeOffset: 270,
    sections: [
      PieChartSectionData(
        value: used,
        color: main,
        radius: 8,
        showTitle: false,
      ),
      PieChartSectionData(
        value: 1 - used,
        color: rest,
        radius: 8,
        showTitle: false,
      ),
    ],
  );
}

/// Kartu form "Batas baru": kategori + nominal batas + tombol simpan.
class _BudgetForm extends StatelessWidget {
  final TextEditingController catC;
  final TextEditingController limitC;
  final FocusNode catFocus;
  final String? formErr;
  final bool saving;
  final VoidCallback onSave;

  const _BudgetForm({
    required this.catC,
    required this.limitC,
    required this.catFocus,
    required this.formErr,
    required this.saving,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr('b_form_title'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: SsrSpace.md),
          TextField(
            controller: catC,
            focusNode: catFocus,
            decoration: InputDecoration(labelText: tr('b_f_cat')),
          ),
          const SizedBox(height: SsrSpace.sm),
          CategoryChips(controller: catC),
          const SizedBox(height: SsrSpace.md),
          TextField(
            controller: limitC,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: tr('b_f_limit'),
              prefixText: '${kCurrencySymbols[currencyCode.value] ?? 'Rp'} ',
            ),
          ),
          if (formErr != null) ...[
            const SizedBox(height: SsrSpace.sm),
            Text(
              formErr!,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: scheme.error),
            ),
          ],
          const SizedBox(height: SsrSpace.lg),
          PrimaryButton(
            label: tr('b_save'),
            loading: saving,
            onPressed: onSave,
          ),
        ],
      ),
    );
  }
}
