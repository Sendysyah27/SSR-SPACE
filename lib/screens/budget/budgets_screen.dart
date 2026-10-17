import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ssr_space/utils/org_prefs.dart';
import 'package:ssr_space/utils/mask.dart';
import 'package:ssr_space/utils/datetime.dart';
import 'package:ssr_space/services/budget_alerts.dart';
import 'package:ssr_space/services/budget_pace.dart';
import 'package:ssr_space/services/budget_service.dart';
import 'package:ssr_space/services/plan_limits.dart';
import 'package:ssr_space/services/wallet_service.dart';
import 'package:ssr_space/services/today_widget.dart';
import 'package:ssr_space/services/category_meta.dart';
import 'package:ssr_space/services/app_categories.dart';
import 'package:ssr_space/services/saving.dart';
import 'package:ssr_space/services/month.dart';
import 'package:ssr_space/services/session_service.dart';
import 'package:ssr_space/services/currency.dart';
import 'package:ssr_space/services/app_settings.dart';
import 'package:ssr_space/utils/strings.dart';
import 'package:ssr_space/theme/app_icons.dart';
import 'package:ssr_space/theme/app_theme.dart';
import 'package:ssr_space/theme/app_typography.dart';
import 'package:ssr_space/theme/category_emoji.dart';
import 'package:ssr_space/theme/dribbble_tokens.dart';
import 'package:ssr_space/widgets/drib_card.dart';
import 'package:ssr_space/widgets/restyle/budget_progress_bar.dart';
import 'package:ssr_space/widgets/restyle/donut_chart.dart';
import 'package:ssr_space/theme/tokens.dart';
import 'package:ssr_space/widgets/pin_field.dart';
import 'package:ssr_space/widgets/pin_pad.dart';
import 'package:ssr_space/widgets/primary_button.dart';
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
  List<Map<String, dynamic>> alerts = [];
  int alertsSeen = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
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
      if (!mounted) return;
      if (orgId.isEmpty) {
        setState(() => loading = false);
        return;
      }
      final b = await fetchBudgets(orgId);
      // Alert fail-open: banner sembunyi bila query gagal.
      var a = <Map<String, dynamic>>[];
      var s = 0;
      try {
        a = await fetchAlerts(orgId, currentMonth());
        s = await budgetAlertsSeen(orgId, currentMonth());
      } catch (_) {
        a = [];
        s = 0;
      }
      if (!mounted) return;
      setState(() {
        data = b;
        alerts = a;
        alertsSeen = s;
        loading = false;
      });
      // Snapshot + refresh widget home: fail-silent (sisa budget berubah).
      unawaited(refreshBudgetWidgetSnapshot(orgId).catchError((_) {}));
    } catch (_) {
      if (!mounted) return;
      setState(() {
        loading = false;
        err = tr('b_err_load');
      });
    }
  }

  /// Ketuk banner = tandai semua alert bulan ini sudah dilihat.
  /// Prefs saja, tanpa write server.
  Future<void> _markAlertsSeen() async {
    try {
      final orgId = await activeOrgId();
      if (orgId.isEmpty || !mounted) return;
      await markBudgetAlertsSeen(orgId, currentMonth(), alerts.length);
      if (!mounted) return;
      setState(() => alertsSeen = alerts.length);
    } catch (_) {
      // Fail-open: banner tetap tampil.
    }
  }

  Future<void> _openEdit(Budget b) async {
    final scheme = Theme.of(context).colorScheme;
    final whole = b.limit.truncateToDouble() == b.limit;
    final limitC = TextEditingController(
      text: b.limit.toStringAsFixed(whole ? 0 : 2),
    );
    final warnC = TextEditingController(text: b.warnPct.toString());
    try {
      final value = await showDialog<dynamic>(
        context: context,
        builder: (ctx) {
          String? errLimit;
          String? errWarn;
          return StatefulBuilder(
            builder: (ctx, setD) => AlertDialog(
              title: Text(tr('b_edit_title').replaceFirst('{c}', b.category)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: limitC,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: tr('b_f_limit'),
                      prefixText:
                          '${kCurrencySymbols[currencyCode.value] ?? 'Rp'} ',
                      errorText: errLimit,
                    ),
                  ),
                  const SizedBox(height: SsrSpace.sm),
                  TextField(
                    controller: warnC,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: tr('b_f_warn'),
                      suffixText: '%',
                      errorText: errWarn,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  style: TextButton.styleFrom(foregroundColor: scheme.error),
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
                    final w = parseWarnPct(warnC.text);
                    if (v == null || v <= 0 || w == null) {
                      setD(() {
                        errLimit =
                            (v == null || v <= 0) ? tr('b_err_limit') : null;
                        errWarn = w == null ? tr('b_err_warn') : null;
                      });
                      return;
                    }
                    Navigator.pop(ctx, (v, w));
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
      if (value is! (double, int)) return;
      final (newLimit, newWarn) = value;
      final ok = await _confirmPin();
      if (!ok || !mounted) return;
      try {
        await setBudget(await activeOrgId(), b.category, newLimit,
            warnPct: newWarn);
        await _load();
        if (!mounted) return;
        unawaited(showSuccessFlash(context));
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(tr('b_updated'))));
      } on QuotaExceededException catch (e) {
        if (!mounted) return;
        await requirePro(context, e.message);
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(tr('b_err_save'))));
      }
    } finally {
      limitC.dispose();
      warnC.dispose();
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
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(tr('b_pin_body')),
                        const SizedBox(height: SsrSpace.md),
                        PinField(
                          controller: pinC,
                          length: 6,
                          error: err,
                          onCompleted: (_) => _submitPin(
                            ctx,
                            setD,
                            pinC,
                            (String? e) => err = e,
                          ),
                        ),
                        const SizedBox(height: SsrSpace.md),
                        PinPad(controller: pinC, length: 6),
                      ],
                    ),
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
        backgroundColor: DribTokens.bgOf(context),
        appBar: AppBar(title: Text(_title)),
        body: const BudgetListSkeleton(),
      );
    }
    if (err != null) {
      return Scaffold(
        backgroundColor: DribTokens.bgOf(context),
        appBar: AppBar(title: Text(_title)),
        body: ErrorView(message: err!, onRetry: _load),
      );
    }
    final items = data?.items ?? [];
    return Scaffold(
      backgroundColor: DribTokens.bgOf(context),
      appBar: AppBar(
        title: Text(_title),
        actions: [
          TextButton(
            onPressed: () => _openAdd(null),
            child: Text('+ ${tr('b_add')}'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(SsrSpace.lg),
        children: [
          _BudgetAlertBanner(
            alerts: alerts,
            seen: alertsSeen,
            onTap: _markAlertsSeen,
          ),
          _OverAllocBanner(data: data),
          _MonthCaption(leftDays: _daysLeft()),
          if (items.isEmpty)
            EmptyView(
              icon: AppIcons.budget,
              illustration: 'assets/illustrations/empty_budget.svg',
              title: tr('b_empty_t'),
              subtitle: tr('b_empty_s'),
              actionLabel: tr('b_empty_a'),
              onAction: () => _openAdd(null),
            ),
          for (final b in items)
            _BudgetEntry(
              budget: b,
              onTap: () => _openEdit(b),
            ),
          const SizedBox(height: SsrSpace.md),
          _OthersChips(
            items: items,
            onPick: (cat) => _openAdd(cat),
          ),
        ],
      ),
    );
  }

  /// Sisa hari bulan berjalan (0 bila ganti bulan).
  int _daysLeft() {
    final now = DateTime.now();
    final last = DateTime(now.year, now.month + 1, 0).day;
    final left = last - now.day;
    return left < 0 ? 0 : left;
  }

  /// Simpan budget baru/edit (validasi sama untuk sheet + dialog edit).
  /// Return null bila sukses, atau kunci strings error.
  Future<String?> _submitBudget({
    required String cat,
    required double limit,
    required int warn,
  }) async {
    try {
      await setBudget(await activeOrgId(), cat, limit, warnPct: warn);
      await _load();
      if (mounted) {
        unawaited(showSuccessFlash(context));
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(tr('b_saved'))));
      }
      return null;
    } on QuotaExceededException catch (e) {
      if (mounted) await requirePro(context, e.message);
      return null;
    } catch (_) {
      return tr('b_err_save');
    }
  }

  /// Buka bottom sheet tambah (preset kategori opsional dari chip).
  Future<void> _openAdd(String? preset) async {
    final cats = appCategories.value
        .map(topOf)
        .toSet()
        .where((c) => c.isNotEmpty)
        .toList();
    final have =
        data?.items.map((b) => topOf(b.category).toLowerCase()).toSet() ?? {};
    final options =
        cats.where((c) => !have.contains(c.toLowerCase())).toList();
    if (!mounted) return;
    final res = await showModalBottomSheet<(String, double, int)?>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _BudgetAddSheet(
        options: options,
        preset: preset,
      ),
    );
    if (!mounted || res == null) return;
    setState(() => saving = true);
    final err = await _submitBudget(
      cat: res.$1,
      limit: res.$2,
      warn: res.$3,
    );
    if (!mounted) return;
    setState(() {
      saving = false;
      if (err != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(err)));
      }
    });
  }
}

/// Warna status budget by persen (brief §4.2, adaptasi AA tercatat):
/// <70 emerald, 70-90 gold-dark, ≥90/jebol rust. Deviasi dari hex iOS
/// mentah (gagal AA di putih) — tercatat di token Ind.
Color _statusColor(bool over, int pct, BuildContext context) {
  final scheme = Theme.of(context).colorScheme;
  final dark = Theme.of(context).brightness == Brightness.dark;
  if (over || pct >= 90) return scheme.error;
  if (pct >= 70) return AppColors.chipSurplusText;
  return dark ? AppColors.emeraldBright : AppColors.emerald;
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
        border: Border.all(color: scheme.error.withValues(alpha: 0.45)),
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

/// Banner: alert budget bulan ini (warn/breach dari trigger server).
/// Hanya baris unseen yang tampil (indeks >= seen, konsisten dengan
/// badge = count minus seen). Sembunyi sendiri bila tak ada yang belum
/// dilihat (pola _NoWalletBanner). Ketuk banner = tandai seen (prefs saja).
class _BudgetAlertBanner extends StatelessWidget {
  final List<Map<String, dynamic>> alerts;
  final int seen;
  final VoidCallback onTap;

  const _BudgetAlertBanner({
    required this.alerts,
    required this.seen,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final start = seen.clamp(0, alerts.length).toInt();
    final unseen = alerts.sublist(start);
    if (unseen.isEmpty) {
      return const SizedBox.shrink();
    }
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: SsrSpace.sm),
        padding: const EdgeInsets.all(SsrSpace.md),
        decoration: BoxDecoration(
          color: scheme.error.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(SsrRadius.tile),
          border: Border.all(color: scheme.error.withValues(alpha: 0.45)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tr('ba_title'),
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: SsrSpace.xs),
            for (final a in unseen)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  alertLabel(a),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
          ],
        ),
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

  const _BudgetEntry({
    required this.budget,
    required this.onTap,
  });

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
    return DribCard(
      margin: const EdgeInsets.only(bottom: GlassSpace.md),
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

/// Kartu satu kategori (brief §4): emoji + persen status + bar 8px +
/// angka "terpakai dari batas" + insight pace. Tanpa cincin.
class _BudgetCard extends StatelessWidget {
  final Budget budget;

  const _BudgetCard({required this.budget});

  @override
  Widget build(BuildContext context) {
    final b = budget;
    final over = b.spent > b.limit;
    final progress = budgetProgress(b.spent, b.limit);
    final pct = b.limit > 0 ? (b.spent / b.limit * 100).round() : 0;
    final color = _statusColor(over, pct, context);
    return DribCard(
      margin: const EdgeInsets.only(bottom: GlassSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                categoryEmoji(b.category),
                style: const TextStyle(fontSize: 22),
              ),
              const SizedBox(width: SsrSpace.sm),
              Expanded(
                child: Text(
                  b.category,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              if (over)
                StatusChip(label: tr('b_over'), tone: StatusTone.danger)
              else
                Text(
                  '$pct%',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: color,
                        fontFeatures: const [
                          FontFeature.tabularFigures()
                        ],
                      ),
                ),
            ],
          ),
          const SizedBox(height: SsrSpace.sm),
          BudgetProgressBar(progress: progress, label: '$pct%'),
          const SizedBox(height: SsrSpace.xs),
          Text(
            '${amt(b.spent)} ${tr('sv_of')} ${amt(b.limit)}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          _PaceLine(budget: b),
        ],
      ),
    );
  }
}

/// Baris pace budget: titik warna + satu kalimat. Hijau aman, emas
/// waspada (tanggal proyeksi habis), merah bahaya. Sembunyi bila limit
/// nol (tak ada batas yang bisa dikejar).
class _PaceLine extends StatelessWidget {
  final Budget budget;

  const _PaceLine({required this.budget});

  @override
  Widget build(BuildContext context) {
    final b = budget;
    if (b.limit <= 0) return const SizedBox.shrink();
    final pace = budgetPace(spent: b.spent, limit: b.limit, today: DateTime.now());
    final scheme = Theme.of(context).colorScheme;
    final Color dot;
    final String text;
    switch (pace.state) {
      case PaceState.safe:
        dot = scheme.primary;
        text = tr('pace_safe');
        break;
      case PaceState.warn:
        dot = AppColors.gold;
        final dd = pace.depletedDate!;
        final ymd =
            '${dd.year.toString().padLeft(4, '0')}-'
            '${dd.month.toString().padLeft(2, '0')}-'
            '${dd.day.toString().padLeft(2, '0')}';
        text = tr('pace_warn').replaceFirst('{d}', dayLabel(ymd));
        break;
      case PaceState.danger:
        dot = scheme.error;
        text = tr('pace_danger');
        break;
    }
    return Padding(
      padding: const EdgeInsets.only(top: SsrSpace.xs),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
          ),
          const SizedBox(width: SsrSpace.sm),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall,
            ),
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
  final int pct;
  final Color? color;

  const _BudgetGauge({
    required this.progress,
    required this.pct,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final used = progress.clamp(0.0, 1.0).toDouble();
    final main = color ?? DribTokens.primary;
    return SizedBox(
      width: 64,
      height: 64,
      child: DonutChart(
        compact: true,
        centerText: '$pct',
        slices: [
          DonutSlice(value: used, label: '', color: main),
          DonutSlice(
            value: (1 - used).clamp(0.0, 1.0).toDouble(),
            label: '',
            color: Theme.of(context).colorScheme.outline,
          ),
        ],
      ),
    );
  }
}

/// Caption "OKTOBER 2026 · N hari tersisa" (brief §4.1).
class _MonthCaption extends StatelessWidget {
  final int leftDays;
  const _MonthCaption({required this.leftDays});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: SsrSpace.sm),
      child: Text(
        '${monthLabel(currentMonth()).toUpperCase()} · $leftDays ${tr('b_days')}',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w500,
              letterSpacing: 0.5,
            ),
      ),
    );
  }
}

/// Chip cepat tambah untuk kategori tanpa budget (brief §4.1).
/// Sembunyi total bila semua kategori sudah ada budgetnya.
class _OthersChips extends StatelessWidget {
  final List<Budget> items;
  final ValueChanged<String> onPick;

  const _OthersChips({required this.items, required this.onPick});

  @override
  Widget build(BuildContext context) {
    final have =
        items.map((b) => topOf(b.category).toLowerCase()).toSet();
    final options = appCategories.value
        .map(topOf)
        .toSet()
        .where((c) => c.isNotEmpty && !have.contains(c.toLowerCase()))
        .toList();
    if (options.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tr('b_others').toUpperCase(),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w500,
                letterSpacing: 0.5,
              ),
        ),
        const SizedBox(height: SsrSpace.sm),
        Wrap(
          spacing: SsrSpace.sm,
          runSpacing: SsrSpace.sm,
          children: [
            for (final c in options)
              ActionChip(
                label: Text('+ $c'),
                onPressed: () => onPick(c),
              ),
          ],
        ),
      ],
    );
  }
}

/// Bottom sheet tambah budget: kategori + nominal + segmented
/// peringatan (brief §4.1). Kembalikan (cat, limitIdr, warn) atau null.
class _BudgetAddSheet extends StatefulWidget {
  final List<String> options;
  final String? preset;

  const _BudgetAddSheet({required this.options, this.preset});

  @override
  State<_BudgetAddSheet> createState() => _BudgetAddSheetState();
}

class _BudgetAddSheetState extends State<_BudgetAddSheet> {
  late String? _cat;
  final _limitC = TextEditingController();
  int _warn = 80;
  String? _err;

  @override
  void initState() {
    super.initState();
    _cat = widget.preset != null && widget.options.contains(widget.preset)
        ? widget.preset
        : (widget.options.isNotEmpty ? widget.options.first : null);
  }

  @override
  void dispose() {
    _limitC.dispose();
    super.dispose();
  }

  void _submit() {
    final cat = topOf(_cat);
    if (cat.isEmpty) {
      setState(() => _err = tr('b_err_cat'));
      return;
    }
    if ((_cat ?? '').contains('>')) {
      setState(() => _err = tr('sub_sep_err'));
      return;
    }
    final typed = double.tryParse(_limitC.text);
    final limit = typed == null ? null : CurrencyService.toIdr(typed);
    if (limit == null || limit <= 0) {
      setState(() => _err = tr('b_err_limit'));
      return;
    }
    Navigator.pop(context, (cat, limit, _warn));
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          SsrSpace.lg,
          SsrSpace.sm,
          SsrSpace.lg,
          MediaQuery.of(context).viewInsets.bottom + SsrSpace.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: SsrSpace.md),
            Text(
              tr('b_add_title'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: SsrSpace.md),
            DropdownButtonFormField<String>(
              initialValue: _cat,
              decoration: InputDecoration(labelText: tr('b_f_cat')),
              items: [
                for (final c in widget.options)
                  DropdownMenuItem(value: c, child: Text('${categoryEmoji(c)} $c')),
              ],
              onChanged: (v) => setState(() => _cat = v),
            ),
            const SizedBox(height: SsrSpace.md),
            TextField(
              controller: _limitC,
              keyboardType: TextInputType.number,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
              decoration: InputDecoration(
                labelText: tr('b_f_limit'),
                prefixText:
                    '${kCurrencySymbols[currencyCode.value] ?? 'Rp'} ',
              ),
            ),
            const SizedBox(height: SsrSpace.md),
            Text(
              tr('b_f_warn'),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: SsrSpace.xs),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 70, label: Text('70%')),
                ButtonSegment(value: 80, label: Text('80%')),
                ButtonSegment(value: 90, label: Text('90%')),
              ],
              selected: {_warn},
              onSelectionChanged: (s) => setState(() => _warn = s.first),
            ),
            if (_err != null) ...[
              const SizedBox(height: SsrSpace.sm),
              Text(
                _err!,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: SsrSpace.lg),
            PrimaryButton(label: tr('b_save'), onPressed: _submit),
          ],
        ),
      ),
    );
  }
}
