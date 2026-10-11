import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ssr_space/services/month.dart';
import 'package:ssr_space/services/recurring_bills.dart';
import 'package:ssr_space/services/subscription_detect.dart';
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

/// Kunci prefs daftar abaikan (kunci grup subGroupKey, maks 100).
const _kIgnored = 'subscription_ignored';
const _maxIgnored = 100;

/// Bulan yang dipindai (berjalan + 3 sebelumnya): cukup untuk 3x bayar.
const _scanMonths = 4;

/// Layar pelacak langganan: pola bayar berulang dari riwayat, dihitung
/// lokal via subscription_detect. Tanpa migration, tanpa dep baru.
class SubscriptionsScreen extends StatefulWidget {
  const SubscriptionsScreen({super.key});

  @override
  State<SubscriptionsScreen> createState() => SubscriptionsScreenState();
}

class SubscriptionsScreenState extends State<SubscriptionsScreen> {
  bool loading = true;
  bool loadFailed = false;
  bool noOrg = false;
  List<SubscriptionCandidate> cands = [];
  List<String> knownLabels = [];
  Set<String> ignored = {};
  bool showIgnored = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _labelOf(String? category, String? note, String? pkg) {
    final c = (category ?? '').trim();
    if (c.isNotEmpty) return c;
    final n = (note ?? '').trim();
    if (n.isNotEmpty) return n;
    final s = (pkg ?? '').trim();
    if (s.isNotEmpty) return s;
    return 'Lainnya';
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      loadFailed = false;
      noOrg = false;
    });
    final orgId = await activeOrgId();
    if (orgId.isEmpty) {
      if (!mounted) return;
      setState(() {
        loading = false;
        noOrg = true;
      });
      return;
    }
    final svc = TransactionService();
    final pays = <SubPayment>[];
    var months = currentMonth();
    var anyOk = false;
    for (var i = 0; i < _scanMonths; i++) {
      try {
        final txs = await svc.listMonth(orgId, months);
        anyOk = true;
        for (final t in txs) {
          final pkg = t.sourcePackage ?? '';
          pays.add(
            SubPayment(
              date: t.date ?? '',
              amount: t.amount,
              label: _labelOf(t.category, t.note, pkg),
              type: t.type,
              auto: pkg.isNotEmpty,
              walletId: t.walletId ?? '',
              category: (t.category ?? '').trim(),
            ),
          );
        }
      } catch (_) {
        // Fail-open per bulan: bulan gagal dilewati, yang lain tetap jalan.
      }
      months = prevMonth(months);
    }
    var known = <String>[];
    try {
      known = (await loadBills()).map((b) => b.label).toList();
    } catch (_) {}
    var ign = <String>{};
    try {
      final p = await SharedPreferences.getInstance();
      ign = (p.getStringList(_kIgnored) ?? []).toSet();
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      loading = false;
      loadFailed = !anyOk && pays.isEmpty;
      cands = detectSubscriptions(pays);
      knownLabels = known;
      ignored = ign;
    });
  }

  List<SubscriptionCandidate> get _visible =>
      cands.where((c) => !ignored.contains(c.key)).toList();

  List<SubscriptionCandidate> get _hidden =>
      cands.where((c) => ignored.contains(c.key)).toList();

  Future<void> _saveIgnored(Set<String> next) async {
    setState(() => ignored = next);
    try {
      final p = await SharedPreferences.getInstance();
      await p.setStringList(_kIgnored, next.take(_maxIgnored).toList());
    } catch (_) {}
  }

  Future<void> _makeBill(SubscriptionCandidate c) async {
    if (c.walletId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(tr('st_need_wallet'))));
      return;
    }
    List<RecurringBill> bills;
    try {
      bills = await loadBills();
    } catch (_) {
      bills = [];
    }
    if (bills.length >= maxBills) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(tr('sub_full'))));
      return;
    }
    final day = (int.tryParse(c.lastDate.substring(8, 10)) ?? 1).clamp(1, 31);
    final y = int.tryParse(c.lastDate.substring(0, 4)) ?? DateTime.now().year;
    final m = int.tryParse(c.lastDate.substring(5, 7)) ?? DateTime.now().month;
    final due = monthlyDue(m == 12 ? y + 1 : y, m == 12 ? 1 : m + 1, day);
    final dueStr =
        '${due.year.toString().padLeft(4, '0')}-'
        '${due.month.toString().padLeft(2, '0')}-'
        '${due.day.toString().padLeft(2, '0')}';
    bills.add(
      RecurringBill(
        id: newBillId(),
        label: c.label,
        amount: c.amount,
        category: c.category,
        walletId: c.walletId,
        period: 'monthly',
        anchorDay: day,
        nextDue: dueStr,
        active: true,
      ),
    );
    await saveBills(bills);
    if (!mounted) return;
    setState(() => knownLabels = [...knownLabels, c.label]);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(tr('sub_made'))));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('sub_title'))),
      body: _body(),
    );
  }

  Widget _body() {
    if (loading) return const TxListSkeleton();
    if (noOrg) {
      return EmptyView(
        icon: AppIcons.workspace,
        title: tr('tx_no_org_t'),
        subtitle: tr('tx_no_org_s'),
        actionLabel: tr('reload'),
        onAction: _load,
      );
    }
    if (loadFailed) {
      return ErrorView(message: tr('tx_err_load'), onRetry: _load);
    }
    final rows = _visible;
    if (rows.isEmpty && _hidden.isEmpty) {
      return EmptyView(
        icon: AppIcons.calendar,
        title: tr('sub_empty_t'),
        subtitle: tr('sub_empty_s'),
        actionLabel: tr('reload'),
        onAction: _load,
      );
    }
    return _SubList(
      rows: rows,
      hidden: showIgnored ? _hidden : const [],
      hiddenCount: _hidden.length,
      showingIgnored: showIgnored,
      knownLabels: knownLabels,
      onMake: _makeBill,
      onIgnore: (c) => _saveIgnored({...ignored, c.key}),
      onUnignore: (c) => _saveIgnored({...ignored}..remove(c.key)),
      onToggleIgnored: () => setState(() => showIgnored = !showIgnored),
    );
  }
}

/// Daftar kandidat + total/bulan + seksi abaikan (stateless, data dari state).
class _SubList extends StatelessWidget {
  final List<SubscriptionCandidate> rows;
  final List<SubscriptionCandidate> hidden;
  final int hiddenCount;
  final bool showingIgnored;
  final List<String> knownLabels;
  final ValueChanged<SubscriptionCandidate> onMake;
  final ValueChanged<SubscriptionCandidate> onIgnore;
  final ValueChanged<SubscriptionCandidate> onUnignore;
  final VoidCallback onToggleIgnored;

  const _SubList({
    required this.rows,
    required this.hidden,
    required this.hiddenCount,
    required this.showingIgnored,
    required this.knownLabels,
    required this.onMake,
    required this.onIgnore,
    required this.onUnignore,
    required this.onToggleIgnored,
  });

  @override
  Widget build(BuildContext context) {
    final total = subscriptionMonthlyTotal(rows);
    return ListView(
      padding: const EdgeInsets.all(SsrSpace.lg),
      children: [
        _TotalCard(total: total, count: rows.length),
        for (final c in rows) ...[
          _CandTile(
            cand: c,
            known: isKnownLabel(c.label, knownLabels),
            action: _CandAction.make,
            onTap: onMake,
            onAlt: onIgnore,
          ),
        ],
        if (hiddenCount > 0) _ignoredToggle(context),
        for (final c in hidden) ...[
          _CandTile(
            cand: c,
            known: isKnownLabel(c.label, knownLabels),
            action: _CandAction.unignore,
            onTap: onUnignore,
            onAlt: onUnignore,
          ),
        ],
      ],
    );
  }

  Widget _ignoredToggle(BuildContext context) {
    final label = showingIgnored
        ? tr('sub_hide_ignored')
        : tr('sub_show_ignored').replaceFirst('{n}', '$hiddenCount');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: SsrSpace.sm),
      child: Center(
        child: TextButton(onPressed: onToggleIgnored, child: Text(label)),
      ),
    );
  }
}

/// Kartu total beban langganan per bulan.
class _TotalCard extends StatelessWidget {
  final double total;
  final int count;

  const _TotalCard({required this.total, required this.count});

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      margin: const EdgeInsets.only(bottom: SsrSpace.md),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr('sub_total'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Text(
                  amt(total),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
          StatusChip(
            label: tr('sub_count').replaceFirst('{n}', '$count'),
            tone: StatusTone.accent,
          ),
        ],
      ),
    );
  }
}

enum _CandAction { make, unignore }

/// Satu baris kandidat: label, nominal, frekuensi, chips, aksi.
class _CandTile extends StatelessWidget {
  final SubscriptionCandidate cand;
  final bool known;
  final _CandAction action;
  final ValueChanged<SubscriptionCandidate> onTap;
  final ValueChanged<SubscriptionCandidate> onAlt;

  const _CandTile({
    required this.cand,
    required this.known,
    required this.action,
    required this.onTap,
    required this.onAlt,
  });

  @override
  Widget build(BuildContext context) {
    final every = tr('sub_every').replaceFirst('{n}', '${cand.avgIntervalDays}');
    final last = tr('sub_last').replaceFirst('{d}', cand.lastDate);
    return SectionCard(
      margin: const EdgeInsets.only(bottom: SsrSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  cand.label,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              Text(
                amt(cand.amount),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            '${tr('rb_paid').replaceFirst('{n}', '${cand.count}')} · $every · $last',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: SsrSpace.sm),
          _chipRow(),
          const SizedBox(height: SsrSpace.sm),
          _actionRow(context),
        ],
      ),
    );
  }

  Widget _chipRow() {
    return Wrap(
      spacing: SsrSpace.sm,
      children: [
        StatusChip(
          label: cand.probable ? tr('sub_sure') : tr('sub_maybe'),
          tone: cand.probable ? StatusTone.accent : StatusTone.neutral,
        ),
        if (!known)
          StatusChip(label: tr('sub_new'), tone: StatusTone.ink),
        if (cand.auto)
          StatusChip(
            label: tr('sub_auto'),
            tone: StatusTone.accent,
            icon: AppIcons.autoBadge,
          ),
      ],
    );
  }

  Widget _actionRow(BuildContext context) {
    if (action == _CandAction.unignore) {
      return TextButton(
        onPressed: () => onTap(cand),
        child: Text(tr('sub_unignore')),
      );
    }
    return Row(
      children: [
        TextButton(
          onPressed: () => onTap(cand),
          child: Text(tr('sub_make')),
        ),
        const Spacer(),
        IconButton(
          icon: const DuoIcon(AppIcons.close),
          tooltip: tr('sub_ignore'),
          onPressed: () => onAlt(cand),
        ),
      ],
    );
  }
}
