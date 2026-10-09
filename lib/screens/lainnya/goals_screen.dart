import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:ssr_space/services/app_settings.dart';
import 'package:ssr_space/services/category_icons.dart';
import 'package:ssr_space/services/category_meta.dart';
import 'package:ssr_space/services/currency.dart';
import 'package:ssr_space/services/goal_forecast.dart';
import 'package:ssr_space/services/goal_store.dart';
import 'package:ssr_space/services/savings_goal.dart';
import 'package:ssr_space/services/month.dart';
import 'package:ssr_space/services/saving.dart';
import 'package:ssr_space/services/transaction_service.dart';
import 'package:ssr_space/theme/app_icons.dart';
import 'package:ssr_space/theme/app_theme.dart';
import 'package:ssr_space/utils/mask.dart';
import 'package:ssr_space/utils/org_prefs.dart';
import 'package:ssr_space/utils/strings.dart';
import 'package:ssr_space/widgets/primary_button.dart';
import 'package:ssr_space/widgets/section_card.dart';
import 'package:ssr_space/widgets/skeletons.dart';
import 'package:ssr_space/widgets/state_views.dart';

/// Daftar target nabung: tambah + setor progres + hapus.
/// Progres auto dihitung dari kategori sejak goal dibuat (jujur, bukan
/// sepanjang waktu). Setor manual = catat progres, bukan transaksi.
class GoalsScreen extends StatefulWidget {
  const GoalsScreen({super.key});
  @override
  State<GoalsScreen> createState() => GoalsScreenState();
}

class GoalsScreenState extends State<GoalsScreen> {
  List<SavingsGoal> goals = [];
  Map<String, double> autoSums = {};
  Map<String, GoalForecast> forecasts = {};
  bool loading = true;
  String? err;
  String? formErr;
  final nameC = TextEditingController();
  final targetC = TextEditingController();
  final deadlineC = TextEditingController();
  final iconC = TextEditingController(text: 'Tabungan');
  final nameFocus = FocusNode();
  bool autoMode = true;

  @override
  void dispose() {
    nameC.dispose();
    targetC.dispose();
    deadlineC.dispose();
    iconC.dispose();
    nameFocus.dispose();
    super.dispose();
  }

  void _focusForm() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      nameFocus.requestFocus();
    });
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> reload() => _load();

  static String _ym(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}';

  Future<void> _load() async {
    setState(() {
      loading = true;
      err = null;
    });
    try {
      final orgId = await activeOrgId();
      final gs = await loadGoals();
      final sums = <String, double>{};
      final fcs = <String, GoalForecast>{};
      if (orgId.isNotEmpty && gs.isNotEmpty) {
        try {
          final now = DateTime.now();
          var start = DateTime(now.year, now.month - 11, 1);
          for (final g in gs) {
            final s =
                g.since.isEmpty ? null : DateTime.tryParse(g.since);
            if (s != null && s.isBefore(start)) start = s;
          }
          final tomorrow = now.add(const Duration(days: 1));
          final range = await TransactionService().listRange(
            orgId,
            '${start.year.toString().padLeft(4, '0')}-'
            '${start.month.toString().padLeft(2, '0')}-'
            '${start.day.toString().padLeft(2, '0')}',
            '${tomorrow.year.toString().padLeft(4, '0')}-'
            '${tomorrow.month.toString().padLeft(2, '0')}-'
            '${tomorrow.day.toString().padLeft(2, '0')}',
            limit: 500,
          );
          final months = <String>[];
          var m = prevMonth(_ym(now));
          for (var i = 0; i < 6; i++) {
            months.add(m);
            m = prevMonth(m);
          }
          for (final g in gs) {
            var sum = 0.0;
            final perMonth = <String, double>{};
            for (final t in range) {
              if (t.type != 'out') continue;
              if (topOf(t.category) != g.linkCategory) continue;
              final dd = DateTime.tryParse(t.date ?? '');
              if (dd == null) continue;
              if (g.since.isNotEmpty && dd.isBefore(DateTime.parse(g.since))) {
                continue;
              }
              sum += t.amount;
              final key = _ym(dd);
              perMonth[key] = (perMonth[key] ?? 0) + t.amount;
            }
            sums[g.id] = g.auto ? sum : 0;
            final hist = [for (final m in months) perMonth[m] ?? 0];
            final fc = forecastGoal(
              saved: g.savedManual + (g.auto ? sum : 0),
              target: g.target,
              savePerMonth: hist,
              today: now,
              deadline: g.deadline == null
                  ? null
                  : DateTime.tryParse(g.deadline!),
            );
            if (fc != null) fcs[g.id] = fc;
          }
        } catch (_) {
          // Fail-open: daftar tetap tampil tanpa angka auto.
        }
      }
      if (!mounted) return;
      setState(() {
        goals = gs;
        autoSums = sums;
        forecasts = fcs;
        loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        loading = false;
        err = tr('beranda_err');
      });
    }
  }

  Future<void> _save() async {
    final name = nameC.text.trim();
    final typed = double.tryParse(targetC.text);
    final target = typed == null ? null : CurrencyService.toIdr(typed);
    final dlRaw = deadlineC.text.trim();
    DateTime? dl;
    if (dlRaw.isNotEmpty) {
      dl = DateTime.tryParse(dlRaw);
      if (dl == null) {
        setState(() => formErr = tr('goal_err'));
        return;
      }
    }
    if (name.isEmpty || target == null || target <= 0) {
      setState(() => formErr = tr('goal_err'));
      return;
    }
    final now = DateTime.now();
    final since =
        '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
    final icon = iconC.text.trim();
    final next = [
      ...goals,
      SavingsGoal(
        id: 'g${now.microsecondsSinceEpoch}',
        name: name.length > 40 ? name.substring(0, 40) : name,
        target: target,
        deadline: dl == null
            ? null
            : '${dl.year.toString().padLeft(4, '0')}-'
                '${dl.month.toString().padLeft(2, '0')}-'
                '${dl.day.toString().padLeft(2, '0')}',
        icon: icon.isEmpty ? 'Tabungan' : icon,
        auto: autoMode,
        linkCategory: 'Tabungan',
        since: since,
      ),
    ];
    await saveGoals(next);
    nameC.clear();
    targetC.clear();
    deadlineC.clear();
    if (!mounted) return;
    setState(() => formErr = null);
    await _load();
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(tr('goal_saved'))));
    }
  }

  Future<void> _deposit(SavingsGoal g) async {
    final c = TextEditingController();
    try {
      final v = await showDialog<double>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(tr('goal_deposit')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(tr('goal_deposit_hint')),
              const SizedBox(height: SsrSpace.sm),
              TextField(
                controller: c,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  prefixText:
                      '${kCurrencySymbols[currencyCode.value] ?? 'Rp'} ',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(tr('cancel')),
            ),
            TextButton(
              onPressed: () {
                final t = double.tryParse(c.text);
                final idr = t == null ? null : CurrencyService.toIdr(t);
                if (idr == null || idr <= 0) {
                  Navigator.pop(ctx);
                  return;
                }
                Navigator.pop(ctx, idr);
              },
              child: Text(tr('save')),
            ),
          ],
        ),
      );
      if (v == null || !mounted) return;
      final next = [
        for (final x in goals)
          if (x.id == g.id)
            SavingsGoal(
              id: x.id,
              name: x.name,
              target: x.target,
              savedManual: x.savedManual + v,
              deadline: x.deadline,
              icon: x.icon,
              auto: x.auto,
              linkCategory: x.linkCategory,
              since: x.since,
            )
          else
            x,
      ];
      await saveGoals(next);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(tr('goal_deposited'))));
      }
    } finally {
      c.dispose();
    }
  }

  Future<void> _delete(SavingsGoal g) async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('goal_delete')),
        content: Text(g.name),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(tr('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(tr('goal_del_yes')),
          ),
        ],
      ),
    );
    if (sure != true || !mounted) return;
    await saveGoals([for (final x in goals) if (x.id != g.id) x]);
    await _load();
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(tr('goal_deleted'))));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Scaffold(
        appBar: AppBar(title: Text(tr('goal_title'))),
        body: const BudgetListSkeleton(),
      );
    }
    if (err != null) {
      return Scaffold(
        appBar: AppBar(title: Text(tr('goal_title'))),
        body: ErrorView(message: err!, onRetry: _load),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(tr('goal_title'))),
      body: ListView(
        padding: const EdgeInsets.all(SsrSpace.lg),
        children: [
          if (goals.isEmpty)
            EmptyView(
              icon: AppIcons.topup,
              illustration: 'assets/illustrations/empty_budget.svg',
              title: tr('goal_empty_t'),
              subtitle: tr('goal_empty_s'),
              actionLabel: tr('goal_empty_a'),
              onAction: _focusForm,
            ),
          for (final g in goals) ...[
            _GoalCard(
              goal: g,
              autoSaved: autoSums[g.id] ?? 0,
              forecast: forecasts[g.id],
              onDeposit: () => _deposit(g),
              onDelete: () => _delete(g),
            ),
          ],
          const SizedBox(height: SsrSpace.md),
          _GoalForm(
            nameC: nameC,
            targetC: targetC,
            deadlineC: deadlineC,
            iconC: iconC,
            nameFocus: nameFocus,
            autoMode: autoMode,
            onAuto: (v) => setState(() => autoMode = v),
            formErr: formErr,
            onSave: _save,
          ),
        ],
      ),
    );
  }
}

/// Satu kartu goal: badge ikon + nama + persen, bar progres, angka,
/// deadline, baris proyeksi, aksi setor/hapus.
class _GoalCard extends StatelessWidget {
  final SavingsGoal goal;
  final double autoSaved;
  final GoalForecast? forecast;
  final VoidCallback onDeposit;
  final VoidCallback onDelete;

  const _GoalCard({
    required this.goal,
    required this.autoSaved,
    required this.forecast,
    required this.onDeposit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final g = goal;
    final got = g.savedManual + (g.auto ? autoSaved : 0);
    final pct = (g.progress(autoSaved) * 100).round();
    final done = g.remaining(autoSaved) <= 0;
    final days = g.daysLeft(DateTime.now());
    return SectionCard(
      margin: const EdgeInsets.only(bottom: SsrSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SvgPicture.asset(svgForCategory(g.icon), height: 32),
              const SizedBox(width: SsrSpace.sm),
              Expanded(
                child: Text(
                  g.name,
                  style: theme.textTheme.titleMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '$pct%',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: SsrSpace.sm),
          SizedBox(
            height: 8,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ColoredBox(
                      color: scheme.outline.withValues(alpha: 0.35),
                    ),
                  ),
                  FractionallySizedBox(
                    widthFactor: g.progress(autoSaved),
                    heightFactor: 1,
                    alignment: Alignment.centerLeft,
                    child: ColoredBox(
                      color: done ? AppColors.gold : scheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: SsrSpace.xs),
          Text(
            tr('goal_of')
                .replaceFirst('{s}', amt(got))
                .replaceFirst('{t}', amt(g.target)),
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: SsrSpace.xs),
          Text(
            done
                ? tr('goal_done')
                : days == null
                ? (g.auto ? tr('goal_mode_auto') : tr('goal_mode_manual'))
                : days >= 0
                ? tr('goal_days_left').replaceFirst('{n}', '$days')
                : tr('goal_overdue').replaceFirst('{n}', '${-days}'),
            style: theme.textTheme.bodySmall,
          ),
          if (!done) _ForecastLine(forecast: forecast),
          const SizedBox(height: SsrSpace.sm),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onDeposit,
                  child: Text(tr('goal_deposit')),
                ),
              ),
              const SizedBox(width: SsrSpace.sm),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 20),
                tooltip: tr('goal_delete'),
                onPressed: onDelete,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Baris proyeksi di kartu goal: kecapai kapan / butuh berapa / saran.
class _ForecastLine extends StatelessWidget {
  final GoalForecast? forecast;

  const _ForecastLine({required this.forecast});

  @override
  Widget build(BuildContext context) {
    final f = forecast;
    if (f == null || f.projectedMonth == null) {
      return Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Text(
          tr('goal_noproj'),
          style: Theme.of(context).textTheme.bodySmall,
        ),
      );
    }
    final m = f.projectedMonth!;
    final label =
        '${m.year}-${m.month.toString().padLeft(2, '0')}';
    final lines = <String>[
      tr('goal_proj').replaceFirst('{m}', monthLabel(label)),
    ];
    if (f.needPerMonth != null && f.needPerMonth! > 0) {
      lines.add(
        tr('goal_need').replaceFirst('{m}', amt(f.needPerMonth!)),
      );
    }
    if (f.extraPerMonth != null && f.extraPerMonth! > 0) {
      lines.add(
        tr('goal_extra').replaceFirst('{m}', amt(f.extraPerMonth!)),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final l in lines)
            Text(l, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

/// Form target baru: nama + nominal + deadline + ikon + mode.
class _GoalForm extends StatelessWidget {
  final TextEditingController nameC;
  final TextEditingController targetC;
  final TextEditingController deadlineC;
  final TextEditingController iconC;
  final FocusNode nameFocus;
  final bool autoMode;
  final ValueChanged<bool> onAuto;
  final String? formErr;
  final VoidCallback onSave;

  const _GoalForm({
    required this.nameC,
    required this.targetC,
    required this.deadlineC,
    required this.iconC,
    required this.nameFocus,
    required this.autoMode,
    required this.onAuto,
    required this.formErr,
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
            tr('goal_add'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: SsrSpace.md),
          TextField(
            controller: nameC,
            focusNode: nameFocus,
            decoration: InputDecoration(labelText: tr('goal_name')),
          ),
          const SizedBox(height: SsrSpace.sm),
          TextField(
            controller: targetC,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: tr('goal_target'),
              prefixText: '${kCurrencySymbols[currencyCode.value] ?? 'Rp'} ',
            ),
          ),
          const SizedBox(height: SsrSpace.sm),
          TextField(
            controller: deadlineC,
            keyboardType: TextInputType.datetime,
            decoration: InputDecoration(
              labelText: tr('goal_deadline'),
              hintText: tr('goal_deadline_hint'),
            ),
          ),
          const SizedBox(height: SsrSpace.sm),
          TextField(
            controller: iconC,
            decoration: InputDecoration(labelText: tr('goal_icon')),
          ),
          SwitchListTile(
            value: autoMode,
            onChanged: onAuto,
            title: Text(
              autoMode ? tr('goal_mode_auto') : tr('goal_mode_manual'),
            ),
            contentPadding: EdgeInsets.zero,
          ),
          if (formErr != null) ...[
            Text(
              formErr!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.error,
              ),
            ),
            const SizedBox(height: SsrSpace.sm),
          ],
          const SizedBox(height: SsrSpace.sm),
          PrimaryButton(label: tr('save'), onPressed: onSave),
        ],
      ),
    );
  }
}
