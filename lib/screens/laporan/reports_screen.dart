import 'dart:io';

import 'package:csv/csv.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:ssr_space/utils/mask.dart';
import 'package:ssr_space/utils/org_prefs.dart';
import 'package:ssr_space/utils/datetime.dart';
import 'package:ssr_space/utils/strings.dart';
import 'package:ssr_space/services/app_settings.dart';
import 'package:ssr_space/services/billing_service.dart';
import 'package:ssr_space/services/category_meta.dart';
import 'package:ssr_space/services/month.dart';
import 'package:ssr_space/services/plan_limits.dart';
import 'package:ssr_space/services/report_pdf.dart';
import 'package:ssr_space/services/reports_topn.dart';
import 'package:ssr_space/services/saving.dart';
import 'package:ssr_space/services/transaction_service.dart';
import 'package:ssr_space/services/transfer_detect.dart';
import 'package:ssr_space/services/tx_day_group.dart';
import 'package:ssr_space/services/wallet_filter.dart';
import 'package:ssr_space/services/wallet_service.dart';
import 'package:ssr_space/theme/app_icons.dart';
import 'package:ssr_space/theme/app_theme.dart';
import 'package:ssr_space/theme/app_typography.dart';
import 'package:ssr_space/models/transaction.dart';
import 'package:ssr_space/widgets/day_header.dart';
import 'package:ssr_space/widgets/month_picker.dart';
import 'package:ssr_space/widgets/section_card.dart';
import 'package:ssr_space/widgets/skeletons.dart';
import 'package:ssr_space/widgets/state_views.dart';
import 'package:ssr_space/widgets/tx_row.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});
  @override
  State<ReportsScreen> createState() => ReportsScreenState();
}

class ReportsScreenState extends State<ReportsScreen> {
  late String month;
  List<SaasTransaction> items = [];
  Map<String, String> walletNames = {};
  String flowFilter = 'all';
  String? filterWallet;
  bool loading = true;
  bool exporting = false;
  bool reordering = false;
  String? err;

  @override
  void initState() {
    super.initState();
    month = currentMonth();
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
      if (orgId.isEmpty) {
        setState(() => loading = false);
        return;
      }
      final txs = await TransactionService().listMonth(orgId, month);
      final ws = await WalletService().list(orgId);
      if (!mounted) return;
      setState(() {
        items = txs;
        walletNames = {for (final w in ws) w.id: w.name};
        if (filterWallet != null && !walletNames.containsKey(filterWallet)) {
          filterWallet = null;
        }
        loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        loading = false;
        err = tr('r_err_load');
      });
    }
  }

  Future<void> _exportCsv() async {
    final rows = <List<dynamic>>[
      ['tanggal', 'jenis', 'nominal', 'kategori', 'catatan'],
      for (final t in items)
        [t.date ?? '', t.type, t.amount, t.category ?? '', t.note ?? ''],
    ];
    final dir = await getTemporaryDirectory();
    final f = File('${dir.path}/laporan-ssr-space.csv');
    await f.writeAsString(const ListToCsvConverter().convert(rows));
    await Share.shareXFiles([XFile(f.path)], text: tr('r_share_csv'));
  }

  Future<void> _exportPdf() async {
    final bytes = await buildReportPdf(
      orgName: await activeOrgName(),
      monthLabel: monthLabel(month),
      items: items,
    );
    final dir = await getTemporaryDirectory();
    final f = File('${dir.path}/laporan-ssr-space.pdf');
    await f.writeAsBytes(bytes);
    await Share.shareXFiles([XFile(f.path)], text: tr('r_share_pdf'));
  }

  Future<void> _runExport(Future<void> Function() run, String label) async {
    if (exporting) return;
    setState(() => exporting = true);
    try {
      await run();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('r_export_ok').replaceFirst('{l}', label))),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(tr('r_export_fail'))));
    } finally {
      if (mounted) setState(() => exporting = false);
    }
  }

  void _onMonthChanged(String m) {
    setState(() => month = m);
    _load();
  }

  Widget _summarySection(
    double totalIn,
    double totalOut,
    double spendOut,
    double savingOut,
    double net,
    bool hasItems,
  ) {
    final hasFlow = totalIn + spendOut + savingOut > 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (hasFlow) ...[
          _MonthFlowChart(
            totalIn: totalIn,
            spendOut: spendOut,
            savingOut: savingOut,
          ),
          const SizedBox(height: SsrSpace.md),
        ],
        _MonthlySummary(
          monthLabel: monthLabel(month),
          totalIn: totalIn,
          totalOut: totalOut,
          net: net,
          exporting: exporting,
          hasItems: hasItems,
          onExportCsv: () => _runExport(_exportCsv, 'CSV'),
          onExportPdf: () => _guardPdf(),
        ),
      ],
    );
  }

  Future<void> _guardPdf() async {
    final orgId = await activeOrgId();
    final plan = orgId.isEmpty ? 'free' : await currentPlan(orgId);
    if (!mounted) return;
    if (!canExportPdf(plan: plan)) {
      await requirePro(context, tr('q_pdf'));
      return;
    }
    _runExport(_exportPdf, 'PDF');
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const _ReportsScaffold(ReportSkeleton());
    }
    if (err != null) {
      return _ReportsScaffold(ErrorView(message: err!, onRetry: _load));
    }
    final filtered = filterByWallet(items, filterWallet);
    final totalIn = filtered
        .where((t) => t.type == 'in')
        .fold<double>(0, (s, t) => s + t.amount);
    final totalOut = filtered
        .where((t) => t.type == 'out')
        .fold<double>(0, (s, t) => s + t.amount);
    final net = totalIn - totalOut;
    // Iris tabungan: OUT berkategori Tabungan/Savings (sumber sama: filtered).
    final savingOut = savingOutOf(filtered);
    var spendOut = totalOut - savingOut;
    if (spendOut < 0) spendOut = 0;
    final catTotals = <String, double>{};
    for (final t in filtered) {
      if (t.type != 'out') continue;
      // Grup di lapis kategori (abaikan sub) agar konsisten dengan budget.
      final top = topOf(t.category);
      final name = top.isEmpty ? tr('cat_other') : top;
      catTotals[name] = (catTotals[name] ?? 0) + t.amount;
    }
    return _ReportsScaffold(
      Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              SsrSpace.lg,
              SsrSpace.lg,
              SsrSpace.lg,
              0,
            ),
            child: MonthPicker(month: month, onChanged: _onMonthChanged),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              SsrSpace.lg,
              SsrSpace.sm,
              SsrSpace.lg,
              0,
            ),
            child: _WalletFilterDropdown(
              value: filterWallet,
              names: walletNames,
              onChanged: (v) => setState(() => filterWallet = v),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => setState(() => reordering = !reordering),
              child: Text(
                tr(reordering ? 'r_arrange_done' : 'r_arrange'),
              ),
            ),
          ),
          Expanded(
            child: ListenableBuilder(
              listenable: Listenable.merge([
                reportSectionOrder,
                reportsTopN,
              ]),
              builder: (context, _) {
                final order = sanitizeSectionOrder(
                  reportSectionOrder.value,
                );
                final sections = <String, Widget>{
                  'summary': _summarySection(
                    totalIn,
                    totalOut,
                    spendOut,
                    savingOut,
                    net,
                    items.isNotEmpty,
                  ),
                  'recap': _CategoryRecap(
                    key: ValueKey('recap-$month'),
                    totals: catTotals,
                    topN: reportsTopN.value,
                  ),
                  'list': _listSection(filtered),
                };
                final kids = [
                  for (final id in order)
                    if (id == 'recap' && catTotals.isEmpty)
                      const SizedBox.shrink(key: ValueKey('recap-empty'))
                    else
                      Padding(
                        key: ValueKey('sec-$id'),
                        padding: const EdgeInsets.fromLTRB(
                          SsrSpace.lg,
                          0,
                          SsrSpace.lg,
                          SsrSpace.lg,
                        ),
                        child: sections[id]!,
                      ),
                ];
                if (!reordering) {
                  return ListView(children: kids);
                }
                return ReorderableListView(
                  onReorderItem: (oldI, newI) async {
                    final next = List<String>.of(order);
                    final moved = next.removeAt(oldI);
                    next.insert(newI, moved);
                    await setReportSectionOrder(next);
                  },
                  children: kids,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _walletName(String? id) => walletNames[id] ?? tr('tx_f_wallet');

  Widget _listSection(List<SaasTransaction> filtered) {
    final visible = filtered
        .where((t) => flowFilter == 'all' || t.type == flowFilter)
        .toList();
    final pairs = detectTransferPairs(filtered);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _FlowFilter(
          value: flowFilter,
          onChanged: (v) => setState(() => flowFilter = v),
        ),
        const SizedBox(height: SsrSpace.md),
        if (pairs.isNotEmpty) ...[
          _TransferHints(pairs: pairs, nameOf: _walletName),
          const SizedBox(height: SsrSpace.md),
        ],
        if (filtered.isEmpty)
          EmptyView(
            icon: AppIcons.reports,
            illustration: 'assets/illustrations/empty_laporan.svg',
            title: tr('r_empty_t'),
            subtitle: tr('r_empty_s'),
            actionLabel: tr('reload'),
            onAction: _load,
          )
        else if (visible.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: SsrSpace.xl),
            child: Text(tr('r_noflow'), textAlign: TextAlign.center),
          )
        else
          _TxListCard(items: visible),
      ],
    );
  }
}

/// Donut 3 iris bulan terpilih: zamrud (masuk), bata (belanja non-tabungan),
/// emas (tabungan). Persen masuk di tengah, legenda mask-aware di bawah.
class _MonthFlowChart extends StatelessWidget {
  final double totalIn;
  final double spendOut;
  final double savingOut;

  const _MonthFlowChart({
    required this.totalIn,
    required this.spendOut,
    required this.savingOut,
  });

  @override
  Widget build(BuildContext context) {
    final total = totalIn + spendOut + savingOut;
    final pctIn = total <= 0 ? 0 : (totalIn / total * 100).round();
    return SectionCard(
      child: Column(
        children: [
          _DonutDial(
            totalIn: totalIn,
            spendOut: spendOut,
            savingOut: savingOut,
            pctIn: pctIn,
          ),
          const SizedBox(height: SsrSpace.sm),
          Row(
            children: [
              Expanded(
                child: _FlowLegend(
                  color: SsrColors.accent,
                  label: tr('tx_in'),
                  value: totalIn,
                ),
              ),
              Expanded(
                child: _FlowLegend(
                  color: SsrColors.danger,
                  label: tr('tx_out'),
                  value: spendOut,
                ),
              ),
              Expanded(
                child: _FlowLegend(
                  color: SsrColors.saving,
                  label: tr('sv_label'),
                  value: savingOut,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Lingkaran donut + persen masuk di tengah.
/// Hanya iris bernilai > 0 yang dirender (fl_chart tak dapat section 0);
/// bila semua nol, satu lingkaran penuh warna muted sebagai placeholder.
class _DonutDial extends StatelessWidget {
  final double totalIn;
  final double spendOut;
  final double savingOut;
  final int pctIn;

  const _DonutDial({
    required this.totalIn,
    required this.spendOut,
    required this.savingOut,
    required this.pctIn,
  });

  @override
  Widget build(BuildContext context) {
    final sections = <PieChartSectionData>[
      if (totalIn > 0)
        PieChartSectionData(
          value: totalIn,
          color: SsrColors.accent,
          radius: 26,
          showTitle: false,
        ),
      if (spendOut > 0)
        PieChartSectionData(
          value: spendOut,
          color: SsrColors.danger,
          radius: 26,
          showTitle: false,
        ),
      if (savingOut > 0)
        PieChartSectionData(
          value: savingOut,
          color: SsrColors.saving,
          radius: 26,
          showTitle: false,
        ),
    ];
    return SizedBox(
      height: 180,
      child: Stack(
        children: [
          PieChart(
            PieChartData(
              pieTouchData: PieTouchData(enabled: false),
              sectionsSpace: 2,
              centerSpaceRadius: 52,
              startDegreeOffset: 270,
              sections: sections.isEmpty
                  ? [
                      PieChartSectionData(
                        value: 1,
                        color: SsrColors.surfaceMuted,
                        radius: 26,
                        showTitle: false,
                      ),
                    ]
                  : sections,
            ),
            duration: SsrMotion.base,
            curve: SsrMotion.curve,
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('$pctIn%', style: SsrTheme.money.copyWith(fontSize: 20)),
                Text(
                  tr('r_center'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Titik warna + "Label · Rp…" (lewat amt, ikut privacy mode).
class _FlowLegend extends StatelessWidget {
  final Color color;
  final String label;
  final double value;

  const _FlowLegend({
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: SsrSpace.sm),
        Expanded(
          child: Text(
            '$label · ${amt(value)}',
            style: Theme.of(context).textTheme.bodyMedium,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// Filter jenis arus di daftar Laporan: semua / masuk / keluar / transfer.
class _FlowFilter extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;

  const _FlowFilter({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<String>(
      segments: [
        ButtonSegment(value: 'all', label: Text(tr('r_flow_all'))),
        ButtonSegment(value: 'in', label: Text(tr('tx_in'))),
        ButtonSegment(value: 'out', label: Text(tr('tx_out'))),
        ButtonSegment(value: 'transfer', label: Text(tr('tx_transfer'))),
      ],
      selected: {value},
      showSelectedIcon: false,
      onSelectionChanged: (s) => onChanged(s.first),
    );
  }
}

/// Filter dompet di Laporan: Semua atau satu dompet.
/// Pilihan null berarti Semua; diterapkan sebelum grup hari.
class _WalletFilterDropdown extends StatelessWidget {
  final String? value;
  final Map<String, String> names;
  final ValueChanged<String?> onChanged;

  const _WalletFilterDropdown({
    required this.value,
    required this.names,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String?>(
      initialValue: value,
      decoration: InputDecoration(labelText: tr('r_filter_wallet')),
      items: [
        DropdownMenuItem<String?>(value: null, child: Text(tr('r_filter_all'))),
        for (final e in names.entries)
          DropdownMenuItem<String?>(value: e.key, child: Text(e.value)),
      ],
      onChanged: onChanged,
    );
  }
}

/// Saran pasangan kemungkinan transfer antar dompet (baca saja,
/// tak menggabung data): keluar + masuk nominal sama <=10 menit.
class _TransferHints extends StatelessWidget {
  final List<TransferPair> pairs;
  final String Function(String? id) nameOf;

  const _TransferHints({required this.pairs, required this.nameOf});

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr('r_hints').replaceFirst('{n}', '${pairs.length}'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: SsrSpace.xs),
          for (final p in pairs)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                '${nameOf(p.outTx.walletId)} → ${nameOf(p.inTx.walletId ?? p.inTx.toWalletId)}'
                ' · ${amt(p.amount)}'
                ' · ${txTime(p.outTx.createdAt)} → ${txTime(p.inTx.createdAt)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
        ],
      ),
    );
  }
}

/// Rekap kategori Top-8 plus Others (P2): saat toggle Top-N ON dan
/// kategori > 8, baris Others merangkum sisa dan ketuk untuk mengembang.
class _CategoryRecap extends StatefulWidget {
  final Map<String, double> totals;
  final bool topN;

  const _CategoryRecap({super.key, required this.totals, required this.topN});

  @override
  State<_CategoryRecap> createState() => _CategoryRecapState();
}

class _CategoryRecapState extends State<_CategoryRecap> {
  bool expanded = false;

  @override
  Widget build(BuildContext context) {
    if (widget.totals.isEmpty) return const SizedBox.shrink();
    final result = top8PlusOthers(widget.totals, enabled: widget.topN);
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(tr('r_recap'), style: theme.textTheme.titleMedium),
        const SizedBox(height: SsrSpace.xs),
        SectionCard(
          padding: const EdgeInsets.symmetric(
            horizontal: SsrSpace.lg,
            vertical: SsrSpace.xs,
          ),
          child: Column(
            children: [
              for (final c in result.top) _row(context, c.name, c.total),
              if (result.others.isNotEmpty && !expanded)
                InkWell(
                  onTap: () => setState(() => expanded = true),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            tr('r_others').replaceFirst(
                              '{n}',
                              '${result.others.length}',
                            ),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Text(
                          amt(result.othersTotal),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontFeatures: const [
                              FontFeature.tabularFigures(),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (expanded) ...[
                for (final c in result.others) _row(context, c.name, c.total),
                InkWell(
                  onTap: () => setState(() => expanded = false),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Text(
                      tr('r_collapse'),
                      style: TextStyle(color: theme.colorScheme.primary),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _row(BuildContext context, String name, double total) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(name, overflow: TextOverflow.ellipsis),
          ),
          Text(
            amt(total),
            style: theme.textTheme.bodyMedium?.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

/// Kerangka layar Laporan: AppBar "Laporan" + body (state / daftar).

class _ReportsScaffold extends StatelessWidget {
  final Widget body;
  const _ReportsScaffold(this.body);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('nav_laporan'))),
      body: body,
    );
  }
}

/// Kartu daftar transaksi bulan terpilih: judul + baris TxRow berdivider.
class _TxListCard extends StatelessWidget {
  final List<SaasTransaction> items;

  const _TxListCard({required this.items});

  @override
  Widget build(BuildContext context) {
    final buckets = groupDayBuckets(items);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(tr('r_tx_title'), style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: SsrSpace.xs),
        SectionCard(
          padding: const EdgeInsets.symmetric(
            horizontal: SsrSpace.sm,
            vertical: SsrSpace.xs,
          ),
          child: Column(
            children: [
              for (final b in buckets) ...[
                DayHeader(dateKey: b.key, count: b.items.length),
                for (var i = 0; i < b.items.length; i++) ...[
                  if (i > 0) const Divider(height: 1),
                  TxRow(tx: b.items[i]),
                ],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Ringkasan bulan berjalan: kartu Masuk + Keluar, kartu Selisih,
/// dan tombol unduh CSV / PDF.
class _MonthlySummary extends StatelessWidget {
  final String monthLabel;
  final double totalIn;
  final double totalOut;
  final double net;
  final bool exporting;
  final bool hasItems;
  final VoidCallback onExportCsv;
  final VoidCallback onExportPdf;

  const _MonthlySummary({
    required this.monthLabel,
    required this.totalIn,
    required this.totalOut,
    required this.net,
    required this.exporting,
    required this.hasItems,
    required this.onExportCsv,
    required this.onExportPdf,
  });

  Widget _statCard(
    BuildContext context,
    String label,
    double value,
    Color color,
  ) {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: SsrSpace.xs),
          Text(amt(value), style: SsrTheme.money.copyWith(color: color)),
        ],
      ),
    );
  }

  Widget _exportButton(String label, VoidCallback onTap) {
    return Expanded(
      child: OutlinedButton(
        onPressed: hasItems && !exporting ? onTap : null,
        child: exporting
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2.2),
              )
            : Text(tr('r_dl').replaceFirst('{l}', label)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: _statCard(context, tr('tx_in'), totalIn, SsrColors.accent),
            ),
            const SizedBox(width: SsrSpace.md),
            Expanded(
              child: _statCard(
                context,
                tr('tx_out'),
                totalOut,
                SsrColors.danger,
              ),
            ),
          ],
        ),
        const SizedBox(height: SsrSpace.md),
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr('beranda_diff').replaceFirst('{m}', monthLabel),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: SsrSpace.xs),
              Text(
                amt(net),
                style: SsrType.moneyLarge.copyWith(
                  color: net >= 0 ? SsrColors.accent : SsrColors.danger,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: SsrSpace.md),
        Row(
          children: [
            _exportButton('CSV', onExportCsv),
            const SizedBox(width: SsrSpace.sm),
            _exportButton('PDF', onExportPdf),
          ],
        ),
      ],
    );
  }
}
