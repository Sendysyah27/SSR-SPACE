import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:ssr_space/services/debt_track.dart';
import 'package:ssr_space/services/month.dart';
import 'package:ssr_space/services/month_figures.dart';
import 'package:ssr_space/services/networth.dart';
import 'package:ssr_space/services/transaction_service.dart';
import 'package:ssr_space/services/wallet_composition.dart';
import 'package:ssr_space/services/wallet_service.dart';
import 'package:ssr_space/theme/app_icons.dart';
import 'package:ssr_space/theme/app_theme.dart';
import 'package:ssr_space/utils/mask.dart';
import 'package:ssr_space/utils/org_prefs.dart';
import 'package:ssr_space/utils/strings.dart';
import 'package:ssr_space/widgets/section_card.dart';
import 'package:ssr_space/widgets/skeletons.dart';
import 'package:ssr_space/widgets/state_views.dart';

/// Layar kekayaan bersih: total + breakdown + tren estimasi 6 bulan.
/// Muat sendiri (kartu dashboard hanya ringkas). Fail-open per bulan.
class NetWorthScreen extends StatefulWidget {
  const NetWorthScreen({super.key});

  @override
  State<NetWorthScreen> createState() => NetWorthScreenState();
}

class NetWorthScreenState extends State<NetWorthScreen> {
  bool loading = true;
  String? err;
  NetWorth? worth;
  List<double> trend = [];
  List<String> trendLabels = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      err = null;
    });
    try {
      final orgId = await activeOrgId();
      if (!mounted) return;
      if (orgId.isEmpty) throw StateError('no org');
      final ws = await WalletService().list(orgId);
      final bals = await WalletService().balances(orgId);
      final debts = await loadDebts();
      final comp = composeComposition(
        {for (final b in bals) b.walletId: b.balance},
        {for (final w in ws) w.id: w.type},
      );
      final t = debtTotals(debts);
      final now = netWorth(
        liquid: comp.liquid,
        savings: comp.savings,
        investments: comp.investments,
        receivable: t.receivable,
        debt: t.debt,
      );
      // Tren: net 5 bulan lampau + kini (gagal per bulan = lewati).
      var m = currentMonth();
      final months = <String>[];
      for (var i = 0; i < 5; i++) {
        m = prevMonth(m);
        months.insert(0, m);
      }
      final nets = <double>[];
      final labels = <String>[];
      for (final mm in months) {
        try {
          final mix = await TransactionService().monthMix(orgId, mm);
          final f = foldMonthMix(
            mix.rows,
            otherLabel: tr('cat_other'),
            totalN: mix.totalN,
          );
          nets.add(f.totalIn - f.totalOut);
          labels.add(_shortMonth(mm));
        } catch (_) {}
      }
      if (!mounted) return;
      setState(() {
        loading = false;
        worth = now;
        trend = [...walkBackEstimates(currentNet: now.net, pastMonthlyNets: nets), now.net];
        trendLabels = [...labels, _shortMonth(currentMonth())];
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        loading = false;
        err = tr('tx_err_load');
      });
    }
  }

  String _shortMonth(String m) {
    // '2026-10' -> 'Okt' (3 huruf pertama nama bulan dua bahasa).
    final label = monthLabel(m);
    final name = label.split(' ').first;
    return name.length <= 3 ? name : name.substring(0, 3);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('nw_title'))),
      body: _body(),
    );
  }

  Widget _body() {
    if (loading) return const TxListSkeleton();
    if (err != null) {
      return ErrorView(message: err!, onRetry: _load);
    }
    final w = worth;
    if (w == null || !w.hasData) {
      return EmptyView(
        icon: AppIcons.billing,
        title: tr('tx_empty_t'),
        actionLabel: tr('reload'),
        onAction: _load,
      );
    }
    return ListView(
      padding: const EdgeInsets.all(SsrSpace.lg),
      children: [
        _TotalCard(worth: w),
        const SizedBox(height: SsrSpace.md),
        _BreakdownCard(worth: w),
        if (trend.length > 1) ...[
          const SizedBox(height: SsrSpace.md),
          _TrendCard(points: trend, labels: trendLabels),
        ],
      ],
    );
  }
}

/// Total bersih + aset vs utang.
class _TotalCard extends StatelessWidget {
  final NetWorth worth;

  const _TotalCard({required this.worth});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tr('nw_title'), style: theme.textTheme.bodySmall),
          Text(
            amt(worth.net),
            style: theme.textTheme.headlineSmall?.copyWith(
              color: worth.net < 0 ? theme.colorScheme.error : null,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: SsrSpace.sm),
          Row(
            children: [
              Expanded(
                child: _cell(
                  context,
                  tr('nw_assets'),
                  amt(worth.assets),
                  theme.colorScheme.primary,
                ),
              ),
              Expanded(
                child: _cell(
                  context,
                  tr('nw_debt'),
                  amt(worth.debt),
                  theme.colorScheme.error,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _cell(BuildContext context, String label, String value, Color c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        Text(
          value,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: c,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

/// Rincian per kategori aset + utang (bar proporsional).
class _BreakdownCard extends StatelessWidget {
  final NetWorth worth;

  const _BreakdownCard({required this.worth});

  @override
  Widget build(BuildContext context) {
    final rows = [
      (tr('nw_liquid'), worth.liquid),
      (tr('nw_savings'), worth.savings),
      (tr('nw_invest'), worth.investments),
      (tr('nw_rec'), worth.receivable),
      (tr('nw_debt'), worth.debt),
    ];
    final max = rows.fold<double>(
      0,
      (a, e) => e.$2.abs() > a ? e.$2.abs() : a,
    );
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final e in rows) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    e.$1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                Text(
                  amt(e.$2),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
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
                        color: Theme.of(context)
                            .colorScheme
                            .outline
                            .withValues(alpha: 0.35),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: max <= 0 ? 0 : (e.$2.abs() / max).clamp(0.0, 1.0).toDouble(),
                      heightFactor: 1,
                      alignment: Alignment.centerLeft,
                      child: ColoredBox(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: SsrSpace.sm),
          ],
        ],
      ),
    );
  }
}

/// Grafik tren estimasi + footnote asumsi.
class _TrendCard extends StatelessWidget {
  final List<double> points;
  final List<String> labels;

  const _TrendCard({required this.points, required this.labels});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    var lo = points.first;
    var hi = points.first;
    for (final v in points) {
      if (v < lo) lo = v;
      if (v > hi) hi = v;
    }
    if ((hi - lo).abs() < 1) {
      hi += 1;
      lo -= 1;
    }
    final pad = (hi - lo) * 0.1;
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tr('nw_trend'), style: theme.textTheme.titleSmall),
          const SizedBox(height: SsrSpace.sm),
          SizedBox(
            height: 160,
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: (points.length - 1).toDouble(),
                minY: lo - pad,
                maxY: hi + pad,
                lineTouchData: const LineTouchData(enabled: false),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTilesSafe.bottom(labels),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                borderData: FlBorderData(show: false),                lineBarsData: [
                  LineChartBarData(
                    spots: [
                      for (var i = 0; i < points.length; i++)
                        FlSpot(i.toDouble(), points[i]),
                    ],
                    isCurved: true,
                    color: scheme.primary,
                    barWidth: 2.5,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: scheme.primary.withValues(alpha: 0.15),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: SsrSpace.sm),
          Text(tr('nw_est'), style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

/// Label sumbu-X aman (indeks di luar label = kosong).
class SideTilesSafe {
  static SideTitles bottom(List<String> labels) => SideTitles(
        showTitles: true,
        interval: 1,
        getTitlesWidget: (v, _) {
          final i = v.toInt();
          if (i < 0 || i >= labels.length) return const SizedBox.shrink();
          return Text(labels[i], style: const TextStyle(fontSize: 10));
        },
      );
}
