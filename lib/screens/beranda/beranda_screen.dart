import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ssr_space/utils/mask.dart';
import 'package:ssr_space/services/pin_debug_log.dart';
import 'package:ssr_space/utils/datetime.dart';
import 'package:ssr_space/services/budget_pace.dart';
import 'package:ssr_space/services/budget_service.dart';
import 'package:ssr_space/services/calm_streak.dart';
import 'package:ssr_space/services/category_meta.dart';
import 'package:ssr_space/services/health_score.dart';
import 'package:ssr_space/services/month.dart';
import 'package:ssr_space/services/saving.dart';
import 'package:ssr_space/services/weekly_insight.dart';
import 'package:ssr_space/services/savings_goal.dart';
import 'package:ssr_space/services/goal_forecast.dart';
import 'package:ssr_space/services/goal_store.dart';
import 'package:ssr_space/services/game_level.dart';
import 'package:ssr_space/services/game_store.dart';
import 'package:ssr_space/screens/lainnya/arcade_screen.dart';
import 'package:ssr_space/screens/lainnya/goals_screen.dart';
import 'package:ssr_space/screens/lainnya/settings_screen.dart';
import 'package:ssr_space/services/recurring_bills.dart';
import 'package:ssr_space/services/today_widget.dart';
import 'package:ssr_space/services/transaction_service.dart';
import 'package:ssr_space/services/tx_day_group.dart';
import 'package:ssr_space/theme/app_icons.dart';
import 'package:ssr_space/theme/app_theme.dart';
import 'package:ssr_space/theme/app_typography.dart';
import 'package:ssr_space/utils/strings.dart';
import 'package:ssr_space/services/app_settings.dart';
import 'package:ssr_space/models/transaction.dart';
import 'package:ssr_space/screens/budget/budgets_screen.dart';
import 'package:ssr_space/screens/laporan/reports_screen.dart';
import 'package:ssr_space/screens/transaksi/transactions_screen.dart';
import 'package:ssr_space/widgets/day_header.dart';
import 'package:ssr_space/widgets/mask_toggle.dart';
import 'package:ssr_space/widgets/month_picker.dart';
import 'package:ssr_space/widgets/primary_button.dart';
import 'package:ssr_space/widgets/section_card.dart';
import 'package:ssr_space/widgets/skeletons.dart';
import 'package:ssr_space/widgets/tx_input_sheet.dart';
import 'package:ssr_space/widgets/state_views.dart';
import 'package:ssr_space/widgets/status_chip.dart';
import 'package:ssr_space/widgets/tx_row.dart';

class BerandaScreen extends StatefulWidget {
  final VoidCallback? onCatat;
  final VoidCallback? onBudget;
  final VoidCallback? onLaporan;
  final VoidCallback? onProfil;

  const BerandaScreen({
    super.key,
    this.onCatat,
    this.onBudget,
    this.onLaporan,
    this.onProfil,
  });

  @override
  State<BerandaScreen> createState() => BerandaScreenState();
}

class BerandaScreenState extends State<BerandaScreen> {
  String month = currentMonth();
  String orgName = '-';
  List<SaasTransaction> items = [];
  List<RecurringBill> billsDue = [];
  bool loading = true;
  String? err;
  DailyStreak? streak;
  HealthBreakdown? health;
  int? healthDelta;
  int paceWarn = 0;
  int paceDanger = 0;
  List<MapEntry<String, BudgetPace>> paceNotes = [];
  WeeklyInsight? insight;
  String? insightDismissKey;
  EmergencyStatus? emergency;
  SavingsGoal? nearGoal;
  double nearAuto = 0;
  int gameXp = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> reload() => _load();

  void _openGoals() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const GoalsScreen()),
    );
  }

  void _openArcade() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ArcadeScreen()),
    );
  }

  /// Pintu pengaturan langsung (gear AppBar): settings terkubur di hub,
  /// satu ketuk dari layar utama tanpa lewat avatar dulu.
  void _openSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
  }

  /// Tutup kartu insight minggu ini (prefs saja, tanpa server).
  Future<void> _dismissInsight() async {
    final key = insightDismissKey;
    if (key != null) {
      try {
        await (await SharedPreferences.getInstance()).setBool(key, true);
      } catch (_) {
        // Fail-open: kartu sekadar muncul lagi besok.
      }
    }
    if (mounted) {
      setState(() {
        insight = null;
        insightDismissKey = null;
      });
    }
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      err = null;
    });
    try {
      await pinLog('beranda load start month=$month');
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      final orgId = prefs.getString('active_org_id') ?? '';
      if (orgId.isEmpty) {
        setState(() {
          loading = false;
          items = [];
          billsDue = [];
        });
        return;
      }
      final txs = await TransactionService().listMonth(orgId, month);
      final allBills = await loadBills();
      final now = DateTime.now();
      // Streak: tanggal ringan lintas bulan, fail-open (kartu sembunyi).
      DailyStreak? st;
      try {
        st = dailyStreak(await TransactionService().listDates(orgId), now);
      } catch (_) {
        st = null;
      }
      // Health + pace: hanya bulan berjalan (limit budget milik bulan
      // berjalan). Bulan lampau tak dihitung, kartu sembunyi.
      HealthBreakdown? hb;
      int? delta;
      var w = 0;
      var dgr = 0;
      var notes = <MapEntry<String, BudgetPace>>[];
      if (month == currentMonth()) {
        try {
          final prev =
              await TransactionService().listMonth(orgId, prevMonth(month));
          final spent = <String, double>{};
          var totalIn = 0.0;
          var curOut = 0.0;
          for (final t in txs) {
            if (t.type == 'in') totalIn += t.amount;
            if (t.type != 'out') continue;
            if (isSavingCategory(t.category)) continue;
            if (!((t.date ?? '').startsWith(month))) continue;
            curOut += t.amount;
            final top = topOf(t.category);
            final k = top.isEmpty ? tr('cat_other') : top;
            spent[k] = (spent[k] ?? 0) + t.amount;
          }
          var prevOut = 0.0;
          for (final t in prev) {
            if (t.type != 'out') continue;
            if (isSavingCategory(t.category)) continue;
            prevOut += t.amount;
          }
          final limits = await fetchBudgetLimits(orgId);
          final hbInputs = [
            for (final b in limits)
              if (!isSavingCategory(b.category) && b.limit > 0)
                HealthBudget(
                  limit: b.limit,
                  spent: spent[b.category] ?? 0,
                ),
          ];
          hb = computeHealth(
            totalIn: totalIn,
            budgets: hbInputs,
            savingOut: savingOutOf(txs, month: month),
            curOut: curOut,
            prevOut: prevOut,
            streakDays: st?.days ?? 0,
          );
          final key = 'health_prev_$orgId';
          final prevScore = prefs.getInt(key);
          if (prevScore != null) delta = hb.total - prevScore;
          await prefs.setInt(key, hb.total);
          notes = <MapEntry<String, BudgetPace>>[];
          for (final b in limits) {
            if (isSavingCategory(b.category) || b.limit <= 0) continue;
            final pace = budgetPace(
              spent: spent[b.category] ?? 0,
              limit: b.limit,
              today: now,
            );
            if (pace.state == PaceState.warn) w++;
            if (pace.state == PaceState.danger) dgr++;
            if (pace.state != PaceState.safe &&
                pace.depletedDate != null) {
              notes.add(MapEntry(b.category, pace));
            }
          }
          notes.sort((a, b) {
            final da = a.value.depletedDate!;
            final db = b.value.depletedDate!;
            final sa = a.value.state == PaceState.danger ? 0 : 1;
            final sb = b.value.state == PaceState.danger ? 0 : 1;
            if (sa != sb) return sa - sb;
            return da.compareTo(db);
          });
        } catch (_) {
          hb = null;
          notes = <MapEntry<String, BudgetPace>>[];
        }
      }
      // Riwayat 12 bulan (1 query, dipakai insight + darurat + goal).
      // Tak tergantung bulan tampil. Fail-open: kartu sembunyi.
      final histStart = DateTime(now.year, now.month - 11, 1);
      final histEnd = now.add(const Duration(days: 1));
      var hist = <SaasTransaction>[];
      try {
        hist = await TransactionService().listRange(
          orgId,
          _ymd(histStart),
          _ymd(histEnd),
          limit: 500,
        );
      } catch (_) {
        hist = <SaasTransaction>[];
      }
      // Insight mingguan dari potongan 5 minggu terakhir.
      WeeklyInsight? wi;
      String? wiKey;
      try {
        final thisMon = weekMonday(now, weekStart.value);
        final lastMon = thisMon.subtract(const Duration(days: 7));
        final dismissKey =
            'insight_seen_${weekKey(lastMon)}_$orgId';
        if (prefs.getBool(dismissKey) != true) {
          final range = hist;
          final wtxs = <WeeklyTx>[];
          for (final t in range) {
            if (t.type != 'out') continue;
            if (isSavingCategory(t.category)) continue;
            final parsed = DateTime.tryParse(t.date ?? '');
            if (parsed == null) continue;
            final top = topOf(t.category);
            wtxs.add(WeeklyTx(
              date: parsed,
              amount: t.amount,
              category: top.isEmpty ? tr('cat_other') : top,
            ));
          }
          wi = buildWeeklyInsight(txs: wtxs, now: now);
          if (wi != null) wiKey = dismissKey;
        } else {
          wiKey = null;
        }
      } catch (_) {
        wi = null;
        wiKey = null;
      }
      // Dana darurat + goal terdekat dari riwayat yang sama.
      EmergencyStatus? em;
      SavingsGoal? near;
      var nearSum = 0.0;
      try {
        final cur = currentMonth();
        var mk = prevMonth(cur);
        final outs = <String, double>{};
        for (var i = 0; i < 3; i++) {
          outs[mk] = 0;
          mk = prevMonth(mk);
        }
        var saved = 0.0;
        for (final t in hist) {
          if (t.type != 'out') continue;
          if (isSavingCategory(t.category)) {
            saved += t.amount;
            continue;
          }
          final rawDate = t.date ?? '';
          final key = rawDate.length >= 7 ? rawDate.substring(0, 7) : '';
          if (outs.containsKey(key)) outs[key] = outs[key]! + t.amount;
        }
        final active =
            outs.values.where((v) => v > 0).toList();
        if (active.isNotEmpty) {
          final avg =
              active.fold<double>(0, (s, v) => s + v) / active.length;
          em = emergencyFund(monthlyExpense: avg, saved: saved);
        }
        final gs = await loadGoals();
        final open = <SavingsGoal>[];
        final sums = <String, double>{};
        for (final g in gs) {
          var sum = 0.0;
          if (g.auto) {
            for (final t in hist) {
              if (t.type != 'out') continue;
              if (topOf(t.category) != g.linkCategory) continue;
              final dd = DateTime.tryParse(t.date ?? '');
              if (dd == null) continue;
              if (g.since.isNotEmpty) {
                final s = DateTime.tryParse(g.since);
                if (s != null && dd.isBefore(s)) continue;
              }
              sum += t.amount;
            }
          }
          sums[g.id] = sum;
          if (g.remaining(sum) > 0) open.add(g);
        }
        open.sort((a, b) {
          if (a.deadline == null && b.deadline == null) return 0;
          if (a.deadline == null) return 1;
          if (b.deadline == null) return -1;
          return a.deadline!.compareTo(b.deadline!);
        });
        if (open.isNotEmpty) {
          near = open.first;
          nearSum = sums[near.id] ?? 0;
        }
        var doneCh = 0;
        try {
          final storedCh = await loadChallenges();
          for (final c in storedCh) {
            if (c.status == 1) doneCh++;
          }
        } catch (_) {}
        var goalsHit = 0;
        for (final g in gs) {
          if (g.remaining(sums[g.id] ?? 0) <= 0) goalsHit++;
        }
        gameXp = calcXp(
          txCount: hist.length,
          streakDays: st?.days ?? 0,
          challengesDone: doneCh,
          goalsReached: goalsHit,
        );
      } catch (_) {
        em = null;
        near = null;
        gameXp = 0;
      }
      if (!mounted) return;
      setState(() {
        orgName = prefs.getString('active_org_name') ?? '-';
        items = txs;
        billsDue = dueBills(allBills, now);
        streak = st;
        health = hb;
        healthDelta = delta;
        paceWarn = w;
        paceDanger = dgr;
        paceNotes = notes;
        insight = wi;
        insightDismissKey = wiKey;
        emergency = em;
        nearGoal = near;
        nearAuto = nearSum;
        loading = false;
      });
      _pushTodaySnapshot(txs);
      await pinLog('beranda load ok n=${txs.length}');
    } catch (e, st) {
      await pinLogError('beranda load', e, st);
      if (!mounted) return;
      setState(() {
        loading = false;
        err = tr('beranda_err');
      });
    }
  }

  void _goCatat() {
    final cb = widget.onCatat;
    if (cb != null) {
      cb();
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const TransactionsScreen()),
    );
  }

  void _goBudget() {
    final cb = widget.onBudget;
    if (cb != null) {
      cb();
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const BudgetsScreen()),
    );
  }

  void _goLaporan() {
    final cb = widget.onLaporan;
    if (cb != null) {
      cb();
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ReportsScreen()),
    );
  }

  void _openMonthTx() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TransactionsScreen(initialMonth: month),
      ),
    );
  }

  /// Snapshot widget hari ini: surplus tanggal berjalan saja (bukan
  /// sebulan), ditulis fire-and-forget agar UI tak menunggu IO prefs.
  void _pushTodaySnapshot(List<SaasTransaction> txs) {
    final now = DateTime.now();
    final today =
        '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
    var tIn = 0.0;
    var tOut = 0.0;
    for (final t in txs) {
      if (t.date != today) continue;
      if (t.type == 'in') {
        tIn += t.amount;
      } else if (t.type == 'out') {
        tOut += t.amount;
      }
    }
    unawaited(refreshTodayWidget(date: today, surplus: tIn - tOut));
  }

  /// Lewati: majukan nextDue satu periode tanpa insert.
  Future<void> _skipBill(RecurringBill bill) async {
    final all = await loadBills();
    final from =
        DateTime.tryParse(bill.nextDue) ?? DateTime.now();
    final next = [
      for (final b in all)
        if (b.id == bill.id)
          b.copyWith(
            nextDue: _ymd(advanceBill(b, from)),
          )
        else
          b,
    ];
    await saveBills(next);
    await _load();
  }

  /// Catat: buka sheet prefill, bila tersimpan rekam riwayat bayar
  /// (nominal master tagihan; nominal asli ada di baris transaksi)
  /// lalu majukan periode.
  Future<void> _recordBill(RecurringBill bill) async {
    final ok = await openTxInputSheet(
      context,
      initialType: 'out',
      initialAmountIdr: bill.amount,
      initialCategory: bill.category.isEmpty ? null : bill.category,
      initialWalletId: bill.walletId,
      initialNote: bill.label,
    );
    if (!ok) return;
    final all = await loadBills();
    final idx = all.indexWhere((b) => b.id == bill.id);
    if (idx < 0) return;
    final rec = recordPayment(all[idx], all[idx].nextDue, bill.amount, DateTime.now());
    all[idx] = rec.bill;
    await saveBills(all);
    final pays = await loadPayments();
    await savePayments([rec.entry, ...pays]);
    await _load();
  }

  static String _ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final initial = orgName.trim().isEmpty || orgName == '-'
        ? '?'
        : orgName.trim()[0].toUpperCase();
    return Scaffold(
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: widget.onProfil,
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: CircleAvatar(
                backgroundColor: scheme.primaryContainer,
                child: Text(
                  initial,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: scheme.onPrimaryContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ),
        title: Text(tr('nav_beranda')),
        actions: [
          IconButton(
            icon: const DuoIcon(AppIcons.settings, size: 22),
            tooltip: tr('st_title'),
            onPressed: _openSettings,
          ),
          const MaskToggle(),
        ],
      ),
      body: AnimatedSwitcher(
        duration: SsrMotion.base,
        switchInCurve: SsrMotion.curve,
        switchOutCurve: SsrMotion.curve,
        child: _body(),
      ),
    );
  }

  String _monthLower() {
    final m = monthLabel(month);
    return localeCode.value == 'en' ? m : m.toLowerCase();
  }

  Widget _body() {
    if (loading) {
      return const BerandaSkeleton(key: ValueKey('beranda-loading'));
    }
    if (err != null) {
      return ErrorView(
        key: const ValueKey('beranda-error'),
        message: err!,
        onRetry: _load,
      );
    }
    return _content(key: const ValueKey('beranda-content'));
  }

  Widget _content({Key? key}) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final totalIn = items
        .where((t) => t.type == 'in')
        .fold<double>(0, (s, t) => s + t.amount);
    final totalOut = items
        .where((t) => t.type == 'out')
        .fold<double>(0, (s, t) => s + t.amount);
    final surplus = totalIn - totalOut;
    final denom = totalIn + totalOut;
    final inShare = denom <= 0 ? 0.0 : totalIn / denom;
    final pctOut = totalOut <= 0 ? null : (surplus / totalOut * 100).round();
    final buckets = groupDayBuckets(items);
    final calmDates = [
      for (final t in items) DateTime.tryParse(t.date ?? ''),
    ].whereType<DateTime>().toList();
    final calm = calmWeeks(calmDates, DateTime.now());
    return ListView(
      key: key,
      padding: const EdgeInsets.fromLTRB(
        SsrSpace.lg,
        SsrSpace.lg,
        SsrSpace.lg,
        96,
      ),
      children: [
        if (orgName.isNotEmpty && orgName != '-') ...[
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: scheme.primary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: SsrSpace.sm),
              Expanded(
                child: Text(
                  orgName,
                  style: theme.textTheme.titleMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: SsrSpace.md),
        ],
        MonthPicker(
          month: month,
          onChanged: (m) {
            setState(() => month = m);
            _load();
          },
        ),
        const SizedBox(height: SsrSpace.sm),
        _surplusCard(totalIn, totalOut, surplus, inShare, pctOut),
        if (streak != null) ...[
          const SizedBox(height: SsrSpace.md),
          _StreakCard(streak: streak!),
        ],
        if (health != null) ...[
          const SizedBox(height: SsrSpace.md),
          _HealthCard(health: health!, delta: healthDelta),
        ],
        if (paceWarn + paceDanger > 0) ...[
          const SizedBox(height: SsrSpace.md),
          _PaceBanner(warn: paceWarn, danger: paceDanger, onTap: _goBudget),
        ],
        for (final n in paceNotes.take(2)) ...[
          const SizedBox(height: SsrSpace.md),
          _NudgeCard(cat: n.key, pace: n.value),
        ],
        if (insight != null) ...[
          const SizedBox(height: SsrSpace.md),
          _InsightCard(insight: insight!, onDismiss: _dismissInsight),
        ],
        if (emergency != null || nearGoal != null) ...[
          const SizedBox(height: SsrSpace.md),
          _DreamCard(
            emergency: emergency,
            goal: nearGoal,
            goalAuto: nearAuto,
            onTap: _openGoals,
          ),
        ],
        const SizedBox(height: SsrSpace.md),
        _LevelRow(xp: gameXp, onTap: _openArcade),
        if (calm.any((b) => b)) ...[
          const SizedBox(height: SsrSpace.md),
          _CalmWeeks(weeks: calm),
        ],
        const SizedBox(height: SsrSpace.xl),
        PrimaryButton(label: tr('act_catat'), onPressed: _goCatat),
        const SizedBox(height: SsrSpace.sm),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _goBudget,
                child: Text(tr('nav_budget')),
              ),
            ),
            const SizedBox(width: SsrSpace.sm),
            Expanded(
              child: OutlinedButton(
                onPressed: _goLaporan,
                child: Text(tr('nav_laporan')),
              ),
            ),
          ],
        ),
        const SizedBox(height: SsrSpace.xl),
        if (billsDue.isNotEmpty) ...[
          _BillsSuggest(
            bills: billsDue,
            onRecord: _recordBill,
            onSkip: _skipBill,
          ),
          const SizedBox(height: SsrSpace.xl),
        ],
        Text(tr('beranda_recent'), style: theme.textTheme.titleMedium),
        if (items.isNotEmpty) ...[
          const SizedBox(height: SsrSpace.xs),
          InkWell(
            onTap: _openMonthTx,
            borderRadius: BorderRadius.circular(SsrRadius.chip),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                tr('beranda_tx_line')
                    .replaceFirst('{n}', '${items.length}')
                    .replaceFirst('{m}', _monthLower()),
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
        if (items.isEmpty)
          SizedBox(
            height: 280,
            child: EmptyView(
              icon: AppIcons.transactions,
              illustration: 'assets/illustrations/empty_transaksi.svg',
              title: tr('beranda_empty_t'),
              subtitle: tr('beranda_empty_s'),
              actionLabel: tr('beranda_empty_a'),
              onAction: _goCatat,
            ),
          )
        else
          for (final b in buckets.take(7)) ...[
            DayHeader(dateKey: b.key, count: b.items.length),
            for (final t in b.items.take(5)) ...[
              TxRow(tx: t),
              const Divider(height: 1),
            ],
          ],
      ],
    );
  }

  Widget _surplusCard(
    double totalIn,
    double totalOut,
    double surplus,
    double inShare,
    int? pctOut,
  ) {
    final positive = surplus >= 0;
    // Teks hero: cream di light, inkDark di dark, keduanya di atas
    // emeraldDeep. Ikut brightness tema aplikasi, bukan platform.
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final onHero = dark ? scheme.onSurface : scheme.onPrimary;
    final heroLabel = TextStyle(
      color: onHero.withValues(alpha: 0.7),
      fontSize: 12,
    );
    final heroValue = TextStyle(
      fontFamily: SsrFonts.numeric,
      color: onHero,
      fontWeight: FontWeight.w600,
      fontSize: 14,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return Container(
      padding: const EdgeInsets.all(SsrSpace.xl),
      decoration: const BoxDecoration(
        color: AppColors.emeraldDeep,
        borderRadius: BorderRadius.all(Radius.circular(SsrRadius.hero)),
      ),
      child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: StatusChip(
                  label: positive
                      ? tr('beranda_surplus')
                      : tr('beranda_defisit'),
                  tone: positive ? StatusTone.ink : StatusTone.danger,
                ),
              ),
              const SizedBox(height: SsrSpace.md),
              Text(
                amt(surplus),
                style: SsrType.heroMoney.copyWith(color: onHero),
              ),
              const SizedBox(height: SsrSpace.xs),
              Text(
                tr('beranda_diff').replaceFirst('{m}', _monthLower()),
                style: TextStyle(
                  color: onHero.withValues(alpha: 0.7),
                  fontSize: 13,
                ),
              ),
              if (pctOut != null) ...[
                const SizedBox(height: SsrSpace.sm),
                Text(
                  tr('beranda_vs_out')
                      .replaceFirst('{p}', '${pctOut >= 0 ? '+' : ''}$pctOut'),
                  style: TextStyle(
                    color: onHero,
                    fontSize: 13,
                  ),
                ),
              ],
              const SizedBox(height: SsrSpace.lg),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tr('tx_in'),
                          style: heroLabel,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          amt(totalIn),
                          style: heroValue,
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          tr('tx_out'),
                          style: heroLabel,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          amt(totalOut),
                          style: heroValue,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: SsrSpace.md),
              SizedBox(
                height: 8,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: onHero.withValues(alpha: 0.25),
                          borderRadius:
                              const BorderRadius.all(Radius.circular(4)),
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(
                          begin: 0,
                          end: inShare < 0
                              ? 0.0
                              : (inShare > 1 ? 1.0 : inShare),
                        ),
                        duration: SsrMotion.base,
                        curve: SsrMotion.curve,
                        builder: (context, value, _) {
                          return Align(
                            alignment: Alignment.centerLeft,
                            child: FractionallySizedBox(
                              widthFactor: value,
                              heightFactor: 1,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: onHero,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                          );
                        },
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

/// Kartu calm streak: 8 dot minggu, tanpa angka tanpa api.
class _CalmWeeks extends StatelessWidget {
  final List<bool> weeks;

  const _CalmWeeks({required this.weeks});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tr('calm_title'), style: theme.textTheme.titleSmall),
          const SizedBox(height: SsrSpace.sm),
          Row(
            children: [
              for (final filled in weeks) ...[
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: filled ? scheme.primary : Colors.transparent,
                    border: Border.all(
                      color: filled
                          ? scheme.primary
                          : theme.colorScheme.outline,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
          const SizedBox(height: SsrSpace.xs),
          Text(tr('calm_sub'), style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

/// Kartu streak harian: angka besar + satu kalimat jujur sesuai kondisi.
/// Tanpa ikon dekorasi, tanpa klaim. Ketuk tak ke mana (bukan tombol).
class _StreakCard extends StatelessWidget {
  final DailyStreak streak;

  const _StreakCard({required this.streak});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = streak;
    final String sub;
    if (s.days <= 0) {
      sub = tr('streak_empty');
    } else if (isMilestone(s.days)) {
      sub = tr('streak_hit').replaceFirst('{m}', '${s.days}');
    } else if (s.graceUsed) {
      sub = tr('streak_grace');
    } else if (s.todayDone) {
      sub = tr('streak_today');
    } else {
      sub = tr('streak_empty');
    }
    final next = nextMilestone(s.days);
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  tr('streak_title'),
                  style: theme.textTheme.titleSmall,
                ),
              ),
              if (isMilestone(s.days))
                StatusChip(
                  label: '${s.days}',
                  tone: StatusTone.accent,
                ),
            ],
          ),
          const SizedBox(height: SsrSpace.xs),
          Text(
            tr('streak_days').replaceFirst('{n}', '${s.days}'),
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: SsrSpace.xs),
          Text(sub, style: theme.textTheme.bodySmall),
          if (next != null && s.days > 0 && !isMilestone(s.days)) ...[
            const SizedBox(height: SsrSpace.xs),
            Text(
              tr('streak_next')
                  .replaceFirst('{n}', '${next - s.days}')
                  .replaceFirst('{m}', '$next'),
              style: theme.textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

/// Kartu skor keuangan 0-100: angka besar + delta vs kemarin +
/// tombol rincian (dialog 4 komponen + bobotnya).
class _HealthCard extends StatelessWidget {
  final HealthBreakdown health;
  final int? delta;

  const _HealthCard({required this.health, required this.delta});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final h = health;
    final d = delta;
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  tr('health_title'),
                  style: theme.textTheme.titleSmall,
                ),
              ),
              if (d != null && d != 0)
                StatusChip(
                  label: tr('health_vs')
                      .replaceFirst('{p}', '${d > 0 ? '+' : ''}$d'),
                  tone: d > 0 ? StatusTone.accent : StatusTone.danger,
                ),
            ],
          ),
          const SizedBox(height: SsrSpace.xs),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '${h.total}',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              Text('/100', style: theme.textTheme.bodySmall),
            ],
          ),
          const SizedBox(height: SsrSpace.xs),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => _openBreakdown(context, h),
              child: Text(tr('health_detail')),
            ),
          ),
        ],
      ),
    );
  }

  void _openBreakdown(BuildContext context, HealthBreakdown h) {
    // Bobot cerminan computeHealth: 40/30/20/10.
    final rows = [
      (tr('health_c_budget'), h.budget, '40%'),
      (tr('health_c_saving'), h.saving, '30%'),
      (tr('health_c_trend'), h.trend, '20%'),
      (tr('health_c_streak'), h.streak, '10%'),
    ];
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('health_title')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (label, score, weight) in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(child: Text('$label ($weight)')),
                    Text(
                      '$score',
                      style: const TextStyle(
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(tr('close')),
          ),
        ],
      ),
    );
  }
}

/// Ringkasan pace: hanya muncul bila ada waspada/bahaya. Ketuk = buka
/// layar Budget. Merah bila ada bahaya, emas bila waspada saja.
class _PaceBanner extends StatelessWidget {
  final int warn;
  final int danger;
  final VoidCallback onTap;

  const _PaceBanner({
    required this.warn,
    required this.danger,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bad = danger > 0;
    final tint = bad ? scheme.error : AppColors.gold;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(SsrSpace.md),
        decoration: BoxDecoration(
          color: tint.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(SsrRadius.tile),
          border: Border.all(color: tint.withValues(alpha: 0.45)),
        ),
        child: Text(
          tr('pace_summary')
              .replaceFirst('{w}', '$warn')
              .replaceFirst('{b}', '$danger'),
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    );
  }
}

/// Nudge satu kategori yang ngebut: chip status + kalimat casual yang
/// tidak menghakimi. Bukan tombol (tak ada onTap).
class _NudgeCard extends StatelessWidget {
  final String cat;
  final BudgetPace pace;

  const _NudgeCard({required this.cat, required this.pace});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bad = pace.state == PaceState.danger;
    final dd = pace.depletedDate!;
    final ymd =
        '${dd.year.toString().padLeft(4, '0')}-'
        '${dd.month.toString().padLeft(2, '0')}-'
        '${dd.day.toString().padLeft(2, '0')}';
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  tr('nudge_title'),
                  style: theme.textTheme.titleSmall,
                ),
              ),
              StatusChip(
                label: cat,
                tone: bad ? StatusTone.danger : StatusTone.accent,
              ),
            ],
          ),
          const SizedBox(height: SsrSpace.xs),
          Text(
            tr('nudge_line')
                .replaceFirst('{c}', cat)
                .replaceFirst('{d}', dayLabel(ymd)),
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

/// Kartu kilasan minggu lalu: total, banding rata-rata, kategori paling
/// naik, satu saran nominal konkret. Dismiss via tombol tutup.
class _InsightCard extends StatelessWidget {
  final WeeklyInsight insight;
  final VoidCallback onDismiss;

  const _InsightCard({required this.insight, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ins = insight;
    final signed =
        '${ins.totalPct >= 0 ? '+' : ''}${ins.totalPct.round()}';
    final String topLine;
    if (ins.topPct != null) {
      topLine = tr('ins_top')
          .replaceFirst('{c}', ins.topCategory)
          .replaceFirst('{p}', '${ins.topPct!.round()}');
    } else {
      topLine = tr('ins_new')
          .replaceFirst('{c}', ins.topCategory)
          .replaceFirst('{m}', amt(ins.topTotal));
    }
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  tr('ins_title'),
                  style: theme.textTheme.titleSmall,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                tooltip: tr('close'),
                onPressed: onDismiss,
              ),
            ],
          ),
          Text(
            tr('ins_total').replaceFirst('{m}', amt(ins.lastTotal)),
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: SsrSpace.xs),
          Text(
            ins.hasAvg
                ? tr('ins_vs').replaceFirst('{p}', signed)
                : tr('ins_avg').replaceFirst('{a}', amt(ins.avgWeekly)),
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: SsrSpace.xs),
          Text(topLine, style: theme.textTheme.bodySmall),
          const SizedBox(height: SsrSpace.xs),
          Text(
            tr('ins_tip')
                .replaceFirst('{c}', ins.topCategory)
                .replaceFirst('{w}', amt(ins.saveWeekly))
                .replaceFirst('{m}', amt(ins.saveMonthly)),
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Kartu mimpi: status dana darurat + goal terdekat. Ketuk = buka Goals.
class _DreamCard extends StatelessWidget {
  final EmergencyStatus? emergency;
  final SavingsGoal? goal;
  final double goalAuto;
  final VoidCallback onTap;

  const _DreamCard({
    required this.emergency,
    required this.goal,
    required this.goalAuto,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final em = emergency;
    final g = goal;
    final String emLabel;
    final StatusTone emTone;
    if (em == null) {
      emLabel = '';
      emTone = StatusTone.accent;
    } else if (em.level >= 2) {
      emLabel = tr('em_safe');
      emTone = StatusTone.accent;
    } else if (em.level == 1) {
      emLabel = tr('em_progress');
      emTone = StatusTone.accent;
    } else {
      emLabel = tr('em_unsafe');
      emTone = StatusTone.danger;
    }
    return GestureDetector(
      onTap: onTap,
      child: SectionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    tr('goal_title'),
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                if (em != null) StatusChip(label: emLabel, tone: emTone),
              ],
            ),
            if (em != null) ...[
              const SizedBox(height: SsrSpace.xs),
              Text(
                tr('em_range')
                    .replaceFirst('{a}', amt(em.target3))
                    .replaceFirst('{b}', amt(em.target6)),
                style: theme.textTheme.bodySmall,
              ),
            ],
            if (g != null) ...[
              const SizedBox(height: SsrSpace.xs),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      g.name,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                  Text(
                    '${(g.progress(goalAuto) * 100).round()}%',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontFeatures: const [
                        FontFeature.tabularFigures(),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Baris level ringkas: Lv + judul + bar mini. Ketuk = buka Arcade.
class _LevelRow extends StatelessWidget {
  final int xp;
  final VoidCallback onTap;

  const _LevelRow({required this.xp, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final lv = levelFor(xp);
    return GestureDetector(
      onTap: onTap,
      child: SectionCard(
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr('game_level')
                        .replaceFirst('{n}', '$lv')
                        .replaceFirst('{t}', tr('lvl_$lv')),
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    height: 6,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: ColoredBox(
                              color:
                                  scheme.outline.withValues(alpha: 0.35),
                            ),
                          ),
                          FractionallySizedBox(
                            widthFactor: levelProgress(xp),
                            heightFactor: 1,
                            alignment: Alignment.centerLeft,
                            child: ColoredBox(color: scheme.primary),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: SsrSpace.sm),
            Icon(
              Icons.chevron_right,
              size: 20,
              color: scheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

/// Kartu saran tagihan rutin: ketuk Catat untuk insert via sheet,
/// Lewati memajukan nextDue satu periode tanpa insert.
class _BillsSuggest extends StatelessWidget {
  final List<RecurringBill> bills;
  final ValueChanged<RecurringBill> onRecord;
  final ValueChanged<RecurringBill> onSkip;

  const _BillsSuggest({
    required this.bills,
    required this.onRecord,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${tr('rb_due_t')} (${bills.length})',
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: SsrSpace.sm),
          for (final b in bills) ...[
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(b.label, overflow: TextOverflow.ellipsis),
                      Text(
                        '${amt(b.amount)} · ${b.nextDue}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => onSkip(b),
                  child: Text(tr('rb_skip')),
                ),
                FilledButton.tonal(
                  onPressed: () => onRecord(b),
                  child: Text(tr('rb_record')),
                ),
              ],
            ),
            if (b != bills.last) const Divider(height: 1),
          ],
        ],
      ),
    );
  }
}
