import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ssr_space/utils/datetime.dart';
import 'package:ssr_space/utils/mask.dart';
import 'package:ssr_space/services/month.dart';
import 'package:ssr_space/services/transaction_service.dart';
import 'package:ssr_space/theme/app_icons.dart';
import 'package:ssr_space/theme/app_theme.dart';
import 'package:ssr_space/theme/app_typography.dart';
import 'package:ssr_space/utils/strings.dart';
import 'package:ssr_space/services/app_settings.dart';
import 'package:ssr_space/models/transaction.dart';
import 'package:ssr_space/screens/budget/budgets_screen.dart';
import 'package:ssr_space/screens/laporan/reports_screen.dart';
import 'package:ssr_space/screens/transaksi/transactions_screen.dart';
import 'package:ssr_space/widgets/mask_toggle.dart';
import 'package:ssr_space/widgets/month_picker.dart';
import 'package:ssr_space/widgets/primary_button.dart';
import 'package:ssr_space/widgets/skeletons.dart';
import 'package:ssr_space/widgets/state_views.dart';
import 'package:ssr_space/widgets/status_chip.dart';
import 'package:ssr_space/widgets/tx_row.dart';

class BerandaScreen extends StatefulWidget {
  final VoidCallback? onCatat;
  final VoidCallback? onBudget;
  final VoidCallback? onLaporan;

  const BerandaScreen({super.key, this.onCatat, this.onBudget, this.onLaporan});

  @override
  State<BerandaScreen> createState() => BerandaScreenState();
}

class BerandaScreenState extends State<BerandaScreen> {
  String month = currentMonth();
  String orgName = '-';
  List<SaasTransaction> items = [];
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
      final prefs = await SharedPreferences.getInstance();
      final orgId = prefs.getString('active_org_id') ?? '';
      if (orgId.isEmpty) {
        setState(() {
          loading = false;
          items = [];
        });
        return;
      }
      final txs = await TransactionService().listMonth(orgId, month);
      if (!mounted) return;
      setState(() {
        orgName = prefs.getString('active_org_name') ?? '-';
        items = txs;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('nav_beranda')),
        actions: const [MaskToggle()],
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
    final groups = <String, List<SaasTransaction>>{};
    for (final t in items) {
      final d = (t.date ?? '').isEmpty ? '-' : t.date!;
      groups.putIfAbsent(d, () => []).add(t);
    }
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
                decoration: const BoxDecoration(
                  color: SsrColors.accent,
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
          for (final d in groups.keys.take(7)) ...[
            Padding(
              padding: const EdgeInsets.only(
                top: SsrSpace.md,
                bottom: SsrSpace.xs,
              ),
              child: Text(dayLabel(d), style: theme.textTheme.bodySmall),
            ),
            for (final t in groups[d]!.take(5)) ...[
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
    return Container(
      padding: const EdgeInsets.all(SsrSpace.xl),
      decoration: BoxDecoration(
        color: SsrColors.ink,
        borderRadius: const BorderRadius.all(Radius.circular(SsrRadius.hero)),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: SsrColors.ink.withValues(alpha: 0.18),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          const Positioned(
            top: -70,
            right: -50,
            child: SizedBox(
              width: 180,
              height: 180,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0x14FFFFFF),
                ),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: StatusChip(
                  label: positive
                      ? tr('beranda_surplus')
                      : tr('beranda_defisit'),
                  tone: positive ? StatusTone.accent : StatusTone.danger,
                ),
              ),
              const SizedBox(height: SsrSpace.md),
              Text(amt(surplus), style: SsrType.heroMoney),
              const SizedBox(height: SsrSpace.xs),
              Text(
                tr('beranda_diff').replaceFirst('{m}', _monthLower()),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 13,
                ),
              ),
              if (pctOut != null) ...[
                const SizedBox(height: SsrSpace.sm),
                Text(
                  tr('beranda_vs_out')
                      .replaceFirst('{p}', '${pctOut >= 0 ? '+' : ''}$pctOut'),
                  style: const TextStyle(color: Colors.white, fontSize: 13),
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
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          amt(totalIn),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
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
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          amt(totalOut),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
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
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
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
                                  color: SsrColors.accent,
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
        ],
      ),
    );
  }
}
