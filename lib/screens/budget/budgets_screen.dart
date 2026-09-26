import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ssr_space/utils/org_prefs.dart';
import 'package:ssr_space/utils/mask.dart';
import 'package:ssr_space/services/budget_service.dart';
import 'package:ssr_space/services/month.dart';
import 'package:ssr_space/services/session_service.dart';
import 'package:ssr_space/services/currency.dart';
import 'package:ssr_space/services/app_settings.dart';
import 'package:ssr_space/utils/strings.dart';
import 'package:ssr_space/theme/app_icons.dart';
import 'package:ssr_space/theme/app_theme.dart';
import 'package:ssr_space/theme/app_typography.dart';
import 'package:ssr_space/widgets/pin_field.dart';
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
  List<Budget> items = [];
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
        items = b;
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
    final cat = catC.text.trim();
    final typedLimit = double.tryParse(limitC.text);
    final limit = typedLimit == null ? null : CurrencyService.toIdr(typedLimit);
    if (cat.isEmpty) {
      setState(() => formErr = tr('b_err_cat'));
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
      final value = await showDialog<double>(
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
      if (value == null || !mounted) return;
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
    return Scaffold(
      appBar: AppBar(title: Text(_title)),
      body: ListView(
        padding: const EdgeInsets.all(SsrSpace.lg),
        children: [
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
            GestureDetector(
              onTap: () => _openEdit(b),
              child: _BudgetCard(budget: b),
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
class _BudgetGauge extends StatelessWidget {
  final double progress;
  final bool over;
  final int pct;

  const _BudgetGauge({
    required this.progress,
    required this.over,
    required this.pct,
  });

  @override
  Widget build(BuildContext context) {
    final used = progress.clamp(0.0, 1.0);
    return SizedBox(
      width: 56,
      height: 56,
      child: Stack(
        children: [
          PieChart(
            _gaugeData(used, over),
            duration: SsrMotion.base,
            curve: SsrMotion.curve,
          ),
          Center(
            child: Text(
              '$pct',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: over ? SsrColors.danger : SsrColors.accent,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

PieChartData _gaugeData(double used, bool over) {
  return PieChartData(
    pieTouchData: PieTouchData(enabled: false),
    sectionsSpace: 0,
    centerSpaceRadius: 20,
    startDegreeOffset: 270,
    sections: [
      PieChartSectionData(
        value: used,
        color: over ? SsrColors.danger : SsrColors.accent,
        radius: 8,
        showTitle: false,
      ),
      PieChartSectionData(
        value: 1 - used,
        color: SsrColors.accentSoft,
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
