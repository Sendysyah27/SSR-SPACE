import 'package:flutter/material.dart';
import 'package:ssr_space/services/app_settings.dart';
import 'package:ssr_space/services/budget_service.dart';
import 'package:ssr_space/services/category_meta.dart';
import 'package:ssr_space/services/game_badges.dart';
import 'package:ssr_space/services/game_challenge.dart';
import 'package:ssr_space/services/game_level.dart';
import 'package:ssr_space/services/game_store.dart';
import 'package:ssr_space/services/goal_store.dart';
import 'package:ssr_space/services/calm_streak.dart';
import 'package:ssr_space/services/month.dart';
import 'package:ssr_space/services/saving.dart';
import 'package:ssr_space/services/save30_store.dart';
import 'package:ssr_space/services/transaction_service.dart';
import 'package:ssr_space/screens/lainnya/save30_screen.dart';
import 'package:ssr_space/services/weekly_insight.dart';
import 'package:ssr_space/theme/app_icons.dart';
import 'package:ssr_space/theme/app_theme.dart';
import 'package:ssr_space/utils/mask.dart';
import 'package:ssr_space/utils/org_prefs.dart';
import 'package:ssr_space/utils/strings.dart';
import 'package:ssr_space/widgets/section_card.dart';
import 'package:ssr_space/widgets/skeletons.dart';
import 'package:ssr_space/widgets/state_views.dart';
import 'package:ssr_space/widgets/status_chip.dart';

/// Layar Pencapaian: level + koleksi badge + tantangan mingguan.
/// Semua angka dari data lokal, fail-open per sumber (kartu sembunyi
/// bila sumbernya gagal, bukan error se-layar).
class ArcadeScreen extends StatefulWidget {
  const ArcadeScreen({super.key});
  @override
  State<ArcadeScreen> createState() => ArcadeScreenState();
}

class ArcadeScreenState extends State<ArcadeScreen> {
  GameStats stats = const GameStats();
  List<String> fresh = [];
  int xp = 0;
  Map<String, ChallengeState> evals = {};
  Map<String, int> stored = {};
  String week = '';
  bool loading = true;
  String? err;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> reload() => _load();

  Future<void> _load() async {
    setState(() {
      loading = true;
      err = null;
    });
    try {
      final orgId = await activeOrgId();
      final now = DateTime.now();
      final wk = weekKey(weekMonday(now, weekStart.value));
      var st = const GameStats();
      var evalMap = <String, ChallengeState>{};
      var storedMap = <String, int>{};
      if (orgId.isNotEmpty) {
        // Streak (ringan).
        var streakDays = 0;
        try {
          final dates = await TransactionService().listDates(orgId);
          streakDays = dailyStreak(dates, now).days;
        } catch (_) {}
        // Riwayat 12 bulan (hemat, tabungan, goals).
        var saved = 0.0;
        var goalsHit = 0;
        try {
          final start = DateTime(now.year, now.month - 11, 1);
          final end = now.add(const Duration(days: 1));
          final hist = await TransactionService().listRange(
            orgId,
            _ymd(start),
            _ymd(end),
            limit: 500,
          );
          for (final t in hist) {
            if (t.type != 'out') continue;
            if (isSavingCategory(t.category)) saved += t.amount;
          }
          final gs = await loadGoals();
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
            if (g.remaining(sum) <= 0) goalsHit++;
          }
        } catch (_) {}
        // Jumlah transaksi (cap 100 baris = label 100+).
        var txN = 0;
        var capped = false;
        try {
          final recent = await TransactionService().list(orgId);
          txN = recent.length;
          capped = recent.length >= 100;
        } catch (_) {}
        // Bulan bersih: tanpa kategori over.
        var clean = false;
        try {
          final limits = await fetchBudgetLimits(orgId);
          final cur = await TransactionService()
              .listMonth(orgId, currentMonth());
          final spent = <String, double>{};
          for (final t in cur) {
            if (t.type != 'out') continue;
            if (isSavingCategory(t.category)) continue;
            final top = topOf(t.category);
            final k = top.isEmpty ? tr('cat_other') : top;
            spent[k] = (spent[k] ?? 0) + t.amount;
          }
          clean = limits.isNotEmpty &&
              limits.every(
                (b) =>
                    isSavingCategory(b.category) ||
                    (spent[b.category] ?? 0) <= b.limit,
              );
        } catch (_) {}
        // Darurat aman: butuh WalletService? tidak, pakai tabungan vs
        // belanja dari hist sudah dihitung? Sederhana: aman bila saved
        // >= 6x rata-rata belanja 3 bulan terakhir.
        var emSafe = false;
        try {
          final start = DateTime(now.year, now.month - 3, 1);
          final end = now.add(const Duration(days: 1));
          final win = await TransactionService().listRange(
            orgId,
            _ymd(start),
            _ymd(end),
            limit: 300,
          );
          final perMonth = <String, double>{};
          for (final t in win) {
            if (t.type != 'out') continue;
            if (isSavingCategory(t.category)) continue;
            final raw = t.date ?? '';
            if (raw.length < 7) continue;
            final k = raw.substring(0, 7);
            perMonth[k] = (perMonth[k] ?? 0) + t.amount;
          }
          final act =
              perMonth.values.where((v) => v > 0).toList();
          if (act.isNotEmpty) {
            final avg =
                act.fold<double>(0, (s, v) => s + v) / act.length;
            emSafe = saved >= avg * 6;
          }
        } catch (_) {}
        // Tantangan tersimpan + evaluasi minggu berjalan.
        var doneCount = 0;
        var save30Wins = 0;
        try {
          final stored = await loadChallenges();
          final weekTxs = await _weekTxs(orgId, now);
          for (final s in stored) {
            if (s.status == 1) doneCount++;
          }
          try {
            final hist30 = await loadSave30History();
            save30Wins = hist30.where((e) => e.success).length;
            doneCount += save30Wins;
          } catch (_) {}
          evalMap = {
            for (final t in challengeTemplates)
              t: evalChallenge(
                  templateId: t, txs: weekTxs, now: now),
          };
          storedMap = {for (final s in stored) s.template: s.status};
          // Sinkron status aktif minggu ini.
          var changed = false;
          final synced = <StoredChallenge>[];
          for (final s in stored) {
            if (s.week == wk && s.status == 0) {
              final ev = evalMap[s.template];
              if (ev != null && ev.status != 0) {
                synced.add(StoredChallenge(
                    template: s.template, week: s.week, status: ev.status));
                changed = true;
                continue;
              }
            }
            synced.add(s);
          }
          if (changed) {
            await saveChallenges(synced);
            storedMap = {for (final s in synced) s.template: s.status};
          }
        } catch (_) {}
        st = GameStats(
          streakDays: streakDays,
          totalSaved: saved,
          txCount: txN,
          txCapped: capped,
          cleanMonth: clean,
          goalsReached: goalsHit,
          emergencySafe: emSafe,
          challengesDone: doneCount,
          save30Done: save30Wins,
        );
      }
      // Tandai badge terlihat (chip Baru hanya sekali).
      var seen = <String>{};
      try {
        seen = await loadSeenBadges();
      } catch (_) {}
      final freshIds = newBadges(st, seen);
      try {
        await saveSeenBadges({...seen, ...unlockedBadges(st)});
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        stats = st;
        fresh = freshIds;
        xp = calcXp(
          txCount: st.txCount,
          streakDays: st.streakDays,
          challengesDone: st.challengesDone,
          goalsReached: st.goalsReached,
        );
        evals = evalMap;
        stored = storedMap;
        week = wk;
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

  static String _ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  /// Transaksi minggu berjalan untuk evaluasi tantangan.
  Future<List<WeekTx>> _weekTxs(String orgId, DateTime now) async {
    final mon = challengeWeekStart(now, weekStart.value);
    final end = now.add(const Duration(days: 1));
    final rows =
        await TransactionService().listRange(orgId, _ymd(mon), _ymd(end));
    return [
      for (final t in rows)
        WeekTx(
          date: DateTime.tryParse(t.date ?? '') ?? now,
          amount: t.amount,
          category: topOf(t.category),
          isOut: t.type == 'out',
        ),
    ];
  }

  Future<void> _join(String template) async {
    final cur = await loadChallenges();
    final next = [
      StoredChallenge(template: template, week: week, status: 0),
      for (final c in cur)
        if (!(c.template == template && c.week == week)) c,
    ];
    await saveChallenges(next);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Scaffold(
        appBar: AppBar(title: Text(tr('game_title'))),
        body: const BudgetListSkeleton(),
      );
    }
    if (err != null) {
      return Scaffold(
        appBar: AppBar(title: Text(tr('game_title'))),
        body: ErrorView(message: err!, onRetry: _load),
      );
    }
    final lv = levelFor(xp);
    final unlocked = unlockedBadges(stats).toSet();
    return Scaffold(
      appBar: AppBar(title: Text(tr('game_title'))),
      body: ListView(
        padding: const EdgeInsets.all(SsrSpace.lg),
        children: [
          _LevelCard(xp: xp, level: lv),
          const SizedBox(height: SsrSpace.md),
          _BadgesCard(unlocked: unlocked, fresh: fresh.toSet()),
          const SizedBox(height: SsrSpace.md),
          _ChallengesCard(
            evals: evals,
            stored: stored,
            onJoin: _join,
          ),
          const SizedBox(height: SsrSpace.md),
          const _Save30Link(),
        ],
      ),
    );
  }
}

/// Header level: Lv + judul + bar + sisa XP.
class _LevelCard extends StatelessWidget {
  final int xp;
  final int level;

  const _LevelCard({required this.xp, required this.level});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final left = xpToNext(xp);
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr('game_level')
                .replaceFirst('{n}', '$level')
                .replaceFirst('{t}', tr('lvl_$level')),
            style: theme.textTheme.titleMedium,
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
                    widthFactor: levelProgress(xp),
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
            left <= 0
                ? tr('game_max')
                : tr('game_xp_left')
                    .replaceFirst('{n}', '$left')
                    .replaceFirst('{t}', tr('lvl_${level + 1}')),
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

/// Koleksi badge: grid 2 kolom, terkunci redup + syarat tampil.
class _BadgesCard extends StatelessWidget {
  final Set<String> unlocked;
  final Set<String> fresh;

  const _BadgesCard({required this.unlocked, required this.fresh});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tr('game_badges'), style: theme.textTheme.titleSmall),
          const SizedBox(height: SsrSpace.sm),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: SsrSpace.sm,
            crossAxisSpacing: SsrSpace.sm,
            childAspectRatio: 1.6,
            children: [
              for (final b in allBadges)
                _BadgeTile(
                  id: b.id,
                  open: unlocked.contains(b.id),
                  isNew: fresh.contains(b.id),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BadgeTile extends StatelessWidget {
  final String id;
  final bool open;
  final bool isNew;

  const _BadgeTile({
    required this.id,
    required this.open,
    required this.isNew,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Opacity(
      opacity: open ? 1 : 0.45,
      child: Container(
        padding: const EdgeInsets.all(SsrSpace.sm),
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.outline),
          borderRadius: BorderRadius.circular(SsrRadius.tile),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    tr('b_${id}_t'),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isNew)
                  StatusChip(label: tr('game_new'), tone: StatusTone.accent),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              tr('b_${id}_d'),
              style: theme.textTheme.bodySmall,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

/// Tantangan minggu ini: ikut + progres + hasil.
class _ChallengesCard extends StatelessWidget {
  final Map<String, ChallengeState> evals;
  final Map<String, int> stored;
  final ValueChanged<String> onJoin;

  const _ChallengesCard({
    required this.evals,
    required this.stored,
    required this.onJoin,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tr('game_challenges'), style: theme.textTheme.titleSmall),
          const SizedBox(height: SsrSpace.sm),
          for (final t in challengeTemplates) ...[
            _ChallengeRow(
              template: t,
              eval: evals[t],
              status: stored[t],
              onJoin: () => onJoin(t),
            ),
            if (t != challengeTemplates.last)
              const Divider(height: SsrSpace.md),
          ],
        ],
      ),
    );
  }
}

class _ChallengeRow extends StatelessWidget {
  final String template;
  final ChallengeState? eval;
  final int? status;
  final VoidCallback onJoin;

  const _ChallengeRow({
    required this.template,
    required this.eval,
    required this.status,
    required this.onJoin,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final joined = status != null;
    final done = status == 1 || (joined && eval?.status == 1);
    final failed = status == 2 || (joined && eval?.status == 2);
    final ev = eval;
    final frac = ev == null || ev.target <= 0
        ? 0.0
        : (ev.progress / ev.target).clamp(0.0, 1.0).toDouble();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                tr('ch_${template}_t'),
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (!joined)
              FilledButton.tonal(
                onPressed: onJoin,
                child: Text(tr('ch_take')),
              )
            else if (done)
              StatusChip(label: tr('ch_done'), tone: StatusTone.accent)
            else if (failed)
              StatusChip(label: tr('ch_failed'), tone: StatusTone.danger),
          ],
        ),
        Text(
          tr('ch_${template}_d'),
          style: theme.textTheme.bodySmall,
        ),
        if (joined && ev != null && !done && !failed) ...[
          const SizedBox(height: 4),
          Text(
            tr('ch_progress')
                .replaceFirst('{p}', _fmtNum(ev.progress))
                .replaceFirst('{t}', _fmtNum(ev.target)),
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: 6,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ColoredBox(
                      color: theme.colorScheme.outline
                          .withValues(alpha: 0.35),
                    ),
                  ),
                  FractionallySizedBox(
                    widthFactor: frac,
                    heightFactor: 1,
                    alignment: Alignment.centerLeft,
                    child:
                        ColoredBox(color: theme.colorScheme.primary),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  /// Angka progres: rupiah dipadatkan, hari tampil bulat.
  String _fmtNum(double v) {
    if (v >= 1000) return amt(v);
    return v % 1 == 0 ? v.toInt().toString() : v.toString();
  }
}

/// Pintu tantangan hemat 30 hari dari Arcade.
class _Save30Link extends StatelessWidget {
  const _Save30Link();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SectionCard(
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const Save30Screen()),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: SsrSpace.sm),
          child: Row(
            children: [
              DuoIcon(AppIcons.success, color: theme.colorScheme.primary),
              const SizedBox(width: SsrSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr('sv30_title'),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      tr('sv30_sub'),
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
