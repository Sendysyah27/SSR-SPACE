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
                    foregroundColor: SsrColors.danger,
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
            style: TextButton.styleFrom(foregroundColor: SsrColors.danger),
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
            _BudgetEntry(budget: b, onTap: () => _openEdit(b)),
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

/// Banner: total limit bulan ini melebihi pemasukan bulan ini.
/// Sembunyi sendiri bila tak over-alloc (pola _NoWalletBanner).
class _OverAllocBanner extends StatelessWidget {
  final BudgetMonth? data;

  const _OverAllocBanner({required this.data});

  @override
  Widget build(BuildContext context) {
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
        color: SsrColors.dangerSoft,
        borderRadius: BorderRadius.circular(SsrRadius.tile),
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
  final VoidCallback onTap;

  const _BudgetEntry({required this.budget, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: isSavingCategory(budget.category)
          ? _SavingCard(budget: budget)
          : _BudgetCard(budget: budget),
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
          Row(
            children: [
              _BudgetGauge(
                progress: budgetProgress(b.spent, b.limit),
                pct: done ? 100 : pct,
                color: SsrColors.saving, soft: SsrColors.savingSoft,
              ),
              const SizedBox(width: SsrSpace.md),
              Expanded(
                child: Text(
                  '${amt(b.spent)} ${tr('sv_of')} ${amt(b.limit)}',
                  style: SsrType.moneyMedium,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Chip persen emas; bila target tercapai tampilkan label selesai.
class _SavingChip extends StatelessWidget {
  final int pct;
  final bool done;

  const _SavingChip({required this.pct, required this.done});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: SsrColors.savingSoft,
        borderRadius: BorderRadius.circular(SsrRadius.chip),
      ),
      child: Text(
        done ? tr('sv_done') : '$pct%',
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: SsrColors.saving,
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

  const _BudgetCard({required this.budget});

  @override
  Widget build(BuildContext context) {
    final b = budget;
    final over = b.spent > b.limit;
    final progress = budgetProgress(b.spent, b.limit);
    final pct = b.limit > 0 ? (b.spent / b.limit * 100).round() : 0;
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
              _BudgetGauge(progress: progress, over: over, pct: pct),
              const SizedBox(width: SsrSpace.md),
              Expanded(
                child: Text(
                  '${amt(b.spent)} dari ${amt(b.limit)}',
                  style: SsrType.moneyMedium,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Cincin progres budget: terpakai (zamrud/bata) vs sisa.
/// [color]/[soft] opsional untuk varian lain (misal emas tabungan).
class _BudgetGauge extends StatelessWidget {
  final double progress;
  final bool over;
  final int pct;
  final Color? color;
  final Color? soft;

  const _BudgetGauge({
    required this.progress,
    this.over = false,
    required this.pct,
    this.color,
    this.soft,
  });

  @override
  Widget build(BuildContext context) {
    final used = progress.clamp(0.0, 1.0).toDouble();
    final main = color ?? (over ? SsrColors.danger : SsrColors.accent);
    return SizedBox(
      width: 56,
      height: 56,
      child: Stack(
        children: [
          PieChart(
            _gaugeData(used, over, color: color, soft: soft),
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

PieChartData _gaugeData(double used, bool over, {Color? color, Color? soft}) {
  final main = color ?? (over ? SsrColors.danger : SsrColors.accent);
  final rest = soft ?? SsrColors.accentSoft;
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
                  ?.copyWith(color: SsrColors.danger),
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
