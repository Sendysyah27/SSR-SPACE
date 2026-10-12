import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ssr_space/services/category_meta.dart';
import 'package:ssr_space/services/save30.dart';
import 'package:ssr_space/services/save30_notify.dart';
import 'package:ssr_space/services/save30_store.dart';
import 'package:ssr_space/services/saving.dart';
import 'package:ssr_space/services/transaction_service.dart';
import 'package:ssr_space/theme/app_icons.dart';
import 'package:ssr_space/theme/app_theme.dart';
import 'package:ssr_space/utils/mask.dart';
import 'package:ssr_space/utils/org_prefs.dart';
import 'package:ssr_space/utils/strings.dart';
import 'package:ssr_space/widgets/section_card.dart';
import 'package:ssr_space/widgets/skeletons.dart';
import 'package:ssr_space/widgets/state_views.dart';
import 'package:ssr_space/widgets/status_chip.dart';

String _ymd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

String _plus1(String ymd) {
  final d = DateTime.tryParse(ymd) ?? DateTime.now();
  return _ymd(d.add(const Duration(days: 1)));
}

/// Tantangan hemat 30 hari: target harian, progres, streak, milestone,
/// saran hemat, riwayat. Data prefs lokal + transaksi org aktif.
class Save30Screen extends StatefulWidget {
  const Save30Screen({super.key});
  @override
  State<Save30Screen> createState() => Save30ScreenState();
}

class Save30ScreenState extends State<Save30Screen> {
  Save30Active? active;
  Save30Progress? progress;
  Map<String, double> spentByCat = {};
  List<String> cuts = [];
  List<Save30Entry> history = [];
  bool noOrg = false;
  bool loading = true;
  String? err;
  final _targetC = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _targetC.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      err = null;
    });
    try {
      final orgId = await activeOrgId();
      if (!mounted) return;
      if (orgId.isEmpty) {
        setState(() {
          noOrg = true;
          loading = false;
        });
        return;
      }
      final a = await loadSave30Active();
      final hist = await loadSave30History();
      Save30Progress? prog;
      var byCat = <String, double>{};
      var cutNames = <String>[];
      if (a != null) {
        try {
          final txs = await TransactionService().listRange(
            orgId,
            a.startYmd,
            _plus1(_ymd(DateTime.now())),
            limit: 500,
          );
          final days = <SaveDay>[];
          for (final t in txs) {
            if (t.type != 'out') continue;
            if (isSavingCategory(t.category)) continue;
            final raw = t.date ?? '';
            if (raw.length < 10) continue;
            days.add(SaveDay(raw.substring(0, 10), t.amount));
            final c = topOf(t.category);
            byCat[c] = (byCat[c] ?? 0) + t.amount;
          }
          prog = evalSave30(
            startYmd: a.startYmd,
            dailyTarget: a.dailyTarget,
            days: days,
            today: DateTime.now(),
          );
          cutNames = suggestCuts(byCat);
        } catch (_) {}
      }
      if (!mounted) return;
      setState(() {
        noOrg = false;
        active = a;
        history = hist;
        progress = prog;
        spentByCat = byCat;
        cuts = cutNames;
        loading = false;
      });
      if (a != null && prog != null) await _celebrate(a, prog);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        loading = false;
        err = tr('beranda_err');
      });
    }
  }

  /// Rayakan milestone baru + finalisasi bila 30 hari habis.
  Future<void> _celebrate(Save30Active a, Save30Progress p) async {
    final fresh = newMilestones(a.celebrated, p.milestonesHit);
    if (fresh.isNotEmpty) {
      await saveSave30Active(
        Save30Active(
          startYmd: a.startYmd,
          dailyTarget: a.dailyTarget,
          celebrated: [...a.celebrated, ...fresh],
        ),
      );
      for (final m in fresh) {
        unawaited(Save30Notify.celebrate(m));
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              tr('sv30_mile').replaceFirst('{n}', '${fresh.last}'),
            ),
          ),
        );
      }
    }
    if (p.finished) {
      await addSave30History(
        Save30Entry(
          startYmd: a.startYmd,
          target: a.dailyTarget,
          spent: p.totalSpent,
          good: p.goodDays,
          success: p.success,
        ),
      );
      await saveSave30Active(null);
      await Save30Notify.reschedule(active: false);
      if (!mounted) return;
      setState(() {
        active = null;
        progress = null;
      });
      await _reloadHistory();
    }
  }

  Future<void> _reloadHistory() async {
    try {
      final hist = await loadSave30History();
      if (!mounted) return;
      setState(() => history = hist);
    } catch (_) {}
  }

  Future<void> _start() async {
    final target = double.tryParse(
      _targetC.text.replaceAll(RegExp(r'[^0-9]'), ''),
    );
    if (target == null || target <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('b_err_limit'))),
      );
      return;
    }
    final a = Save30Active(
      startYmd: _ymd(DateTime.now()),
      dailyTarget: target,
    );
    await saveSave30Active(a);
    await Save30Notify.reschedule(active: true, startYmd: a.startYmd);
    await _load();
  }

  Future<void> _stop() async {
    final a = active;
    if (a == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('sv30_stop')),
        content: Text(tr('sv30_stop_body')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(tr('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(tr('sv30_stop')),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final p = progress;
    await addSave30History(
      Save30Entry(
        startYmd: a.startYmd,
        target: a.dailyTarget,
        spent: p?.totalSpent ?? 0,
        good: p?.goodDays ?? 0,
        success: p == null
            ? false
            : save30ProRata(p.totalSpent, a.dailyTarget, p.dayN),
      ),
    );
    await saveSave30Active(null);
    await Save30Notify.reschedule(active: false);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('sv30_title'))),
      body: _body(),
    );
  }

  Widget _body() {
    if (noOrg) {
      return EmptyView(
        icon: AppIcons.success,
        title: tr('tx_no_org_t'),
        subtitle: tr('tx_no_org_s'),
        actionLabel: tr('reload'),
        onAction: _load,
      );
    }
    if (loading) return const TxListSkeleton();
    if (err != null) return ErrorView(message: err!, onRetry: _load);
    final a = active;
    final p = progress;
    return ListView(
      padding: const EdgeInsets.all(SsrSpace.lg),
      children: [
        if (a == null || p == null) ...[
          _StartCard(controller: _targetC, onStart: _start),
        ] else ...[
          _ProgressCard(
            active: a,
            progress: p,
            onStop: _stop,
          ),
          const SizedBox(height: SsrSpace.md),
          _SuggestCard(cuts: cuts, amounts: spentByCat),
        ],
        const SizedBox(height: SsrSpace.md),
        _HistoryCard(history: history),
      ],
    );
  }
}

/// Form mulai: target harian + tombol.
class _StartCard extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onStart;

  const _StartCard({required this.controller, required this.onStart});

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tr('sv30_empty_t'), style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: SsrSpace.xs),
          Text(tr('sv30_empty_s'), style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: SsrSpace.md),
          TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              hintText: tr('sv30_target'),
              border: const OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: SsrSpace.sm),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onStart,
              child: Text(tr('sv30_start')),
            ),
          ),
        ],
      ),
    );
  }
}

/// Kartu progres: bar N/30 + streak + milestone + pemakaian.
class _ProgressCard extends StatelessWidget {
  final Save30Active active;
  final Save30Progress progress;
  final VoidCallback onStop;

  const _ProgressCard({
    required this.active,
    required this.progress,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final p = progress;
    final frac = (p.goodDays / 30).clamp(0.0, 1.0);
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  tr('sv30_day').replaceFirst('{n}', '${p.dayN > 30 ? 30 : p.dayN}'),
                  style: theme.textTheme.titleMedium,
                ),
              ),
              StatusChip(
                label: tr('sv30_streak').replaceFirst('{n}', '${p.streak}'),
                tone: StatusTone.accent,
              ),
            ],
          ),
          const SizedBox(height: SsrSpace.sm),
          SizedBox(
            height: 10,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ColoredBox(
                      color: scheme.outline.withValues(alpha: 0.35),
                    ),
                  ),
                  FractionallySizedBox(
                    widthFactor: frac,
                    heightFactor: 1,
                    alignment: Alignment.centerLeft,
                    child: ColoredBox(color: scheme.primary),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: SsrSpace.xs),
          Text(
            tr('sv30_good').replaceFirst('{n}', '${p.goodDays}'),
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: SsrSpace.sm),
          Text(
            tr('sv30_spent')
                .replaceFirst('{m}', amt(p.totalSpent))
                .replaceFirst('{t}', amt(p.targetTotal)),
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: SsrSpace.sm),
          Wrap(
            spacing: SsrSpace.sm,
            children: [
              for (final m in save30Milestones)
                StatusChip(
                  label: '$m',
                  tone: p.milestonesHit.contains(m)
                      ? StatusTone.accent
                      : StatusTone.neutral,
                ),
            ],
          ),
          const SizedBox(height: SsrSpace.sm),
          TextButton(
            onPressed: onStop,
            child: Text(tr('sv30_stop')),
          ),
        ],
      ),
    );
  }
}

/// Saran kategori yang bisa dihemat (top belanja non-tabungan).
class _SuggestCard extends StatelessWidget {
  final List<String> cuts;
  final Map<String, double> amounts;

  const _SuggestCard({required this.cuts, required this.amounts});

  @override
  Widget build(BuildContext context) {
    if (cuts.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tr('sv30_suggest'), style: theme.textTheme.titleSmall),
          const SizedBox(height: SsrSpace.sm),
          for (final c in cuts)
            Padding(
              padding: const EdgeInsets.only(bottom: SsrSpace.xs),
              child: Row(
                children: [
                  Expanded(child: Text(c, style: theme.textTheme.bodyMedium)),
                  Text(
                    amt(amounts[c] ?? 0),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Riwayat tantangan (maks 12, terbaru dulu).
class _HistoryCard extends StatelessWidget {
  final List<Save30Entry> history;

  const _HistoryCard({required this.history});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tr('sv30_history'), style: theme.textTheme.titleSmall),
          const SizedBox(height: SsrSpace.sm),
          if (history.isEmpty)
            Text(tr('sv30_empty_s'), style: theme.textTheme.bodySmall)
          else
            for (final h in history)
              Padding(
                padding: const EdgeInsets.only(bottom: SsrSpace.xs),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${h.startYmd} · ${h.good}/30',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                    StatusChip(
                      label: tr(h.success ? 'sv30_success' : 'sv30_failed'),
                      tone: h.success
                          ? StatusTone.accent
                          : StatusTone.neutral,
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}
