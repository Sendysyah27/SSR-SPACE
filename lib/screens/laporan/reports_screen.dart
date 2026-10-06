import 'dart:io';

import 'package:csv/csv.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:ssr_space/utils/mask.dart';
import 'package:ssr_space/utils/org_prefs.dart';
import 'package:ssr_space/utils/datetime.dart';
import 'package:ssr_space/utils/strings.dart';
import 'package:ssr_space/services/app_settings.dart';
import 'package:ssr_space/services/billing_service.dart';
import 'package:ssr_space/services/category_icons.dart';
import 'package:ssr_space/services/category_meta.dart';
import 'package:ssr_space/services/export_files.dart';
import 'package:ssr_space/services/export_saved_notify.dart';
import 'package:ssr_space/services/month.dart';
import 'package:ssr_space/services/plan_limits.dart';
import 'package:ssr_space/services/report_export.dart';
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
import 'package:ssr_space/widgets/tx_day_slivers.dart';
import 'package:ssr_space/widgets/tx_row.dart';
import 'package:ssr_space/widgets/tx_type_selector.dart';

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

  /// Item ekspor = yang tampil di layar (filter dompet + jenis sesi).
  /// CSV dan PDF memakai daftar yang sama.
  List<SaasTransaction> _exportItems() =>
      applyReportFilters(items, filterWallet, flowFilter);

  String? _exportWalletLabel() => filterWallet == null
      ? null
      : (walletNames[filterWallet] ?? tr('tx_f_wallet'));

  String? _exportTypeLabel() {
    if (flowFilter == 'in') return tr('tx_in');
    if (flowFilter == 'out') return tr('tx_out');
    if (flowFilter == 'transfer') return tr('tx_transfer');
    return null;
  }

  /// CSV terfilter (header alias impor dipertahankan; nominal bulat tanpa
  /// desimal supaya tak terbaca 10x lipat saat ditempel balik).
  Future<void> _exportCsv() async {
    String num(double v) =>
        v % 1 == 0 ? v.toInt().toString() : v.toString();
    final data = _exportItems();
    final rows = <List<dynamic>>[
      ['tanggal', 'jenis', 'nominal', 'dompet', 'ke_dompet', 'kategori', 'catatan'],
      for (final t in data)
        [
          t.date ?? '',
          t.type,
          num(t.amount),
          walletNames[t.walletId] ?? '',
          walletNames[t.toWalletId] ?? '',
          t.category ?? '',
          t.note ?? '',
        ],
    ];
    final base = exportBaseName(
      month,
      walletLabel: _exportWalletLabel(),
      flow: flowFilter,
    );
    final csv = const ListToCsvConverter().convert(rows);
    await _saveAndNotify(
      base: base,
      ext: 'csv',
      shareText: tr('r_share_csv'),
      write: (p) => File(p).writeAsString(csv),
    );
  }

  Future<void> _exportPdf() async {
    final data = _exportItems();
    final bytes = await buildReportPdf(
      orgName: await activeOrgName(),
      monthLabel: monthLabel(month),
      items: data,
      walletLabel: _exportWalletLabel(),
      typeLabel: _exportTypeLabel(),
      walletNames: walletNames,
    );
    final base = exportBaseName(
      month,
      walletLabel: _exportWalletLabel(),
      flow: flowFilter,
    );
    await _saveAndNotify(
      base: base,
      ext: 'pdf',
      shareText: tr('r_share_pdf'),
      write: (p) => File(p).writeAsBytes(bytes),
    );
  }

  /// Simpan ke Documents/ssr-space + notif Bagikan. Izin ditolak =
  /// fallback temp + share langsung + pesan jujur (bukan gagal).
  Future<void> _saveAndNotify({
    required String base,
    required String ext,
    required String shareText,
    required Future<void> Function(String path) write,
  }) async {
    final fileName = '$base.$ext';
    try {
      final path = await saveToDocuments(fileName: fileName, write: write);
      await ExportSavedNotify.showExportSaved(
        filePath: path,
        fileName: fileName,
      );
    } on ExportNoPermission {
      final dir = await getTemporaryDirectory();
      final f = File('${dir.path}/$fileName');
      await write(f.path);
      if (!mounted) return;
      await Share.shareXFiles([XFile(f.path)], text: shareText);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(tr('exp_noperm'))));
    }
  }

  Future<void> _runExport(Future<void> Function() run) async {
    if (exporting) return;
    setState(() => exporting = true);
    try {
      // Sukses dikonfirmasi notif sistem (tombol Bagikan), bukan snackbar.
      await run();
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

  void _onWalletChanged(String? v) => setState(() => filterWallet = v);

  void _toggleOrdering() => setState(() => reordering = !reordering);

  /// Angka turunan sebulan dari list yang sudah difilter dompet.
  /// Isi identik dengan hitungan inline build sebelumnya.
  _MonthFigures _totalsFor(List<SaasTransaction> filtered) {
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
    return _MonthFigures(
      items: filtered,
      totalIn: totalIn,
      totalOut: totalOut,
      spendOut: spendOut,
      savingOut: savingOut,
      net: net,
      catTotals: catTotals,
    );
  }

  Widget _summarySection(_MonthFigures f, bool hasItems) {
    final hasFlow = f.totalIn + f.spendOut + f.savingOut > 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (hasFlow) ...[
          _MonthFlowChart(
            totalIn: f.totalIn,
            spendOut: f.spendOut,
            savingOut: f.savingOut,
          ),
          const SizedBox(height: SsrSpace.md),
        ],
        _MonthlySummary(
          monthLabel: monthLabel(month),
          totalIn: f.totalIn,
          totalOut: f.totalOut,
          net: f.net,
          exporting: exporting,
          hasItems: hasItems,
          onExportCsv: () => _runExport(_exportCsv),
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
    _runExport(_exportPdf);
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const _ReportsScaffold(ReportSkeleton());
    }
    if (err != null) {
      return _ReportsScaffold(ErrorView(message: err!, onRetry: _load));
    }
    final figs = _totalsFor(filterByWallet(items, filterWallet));
    return _ReportsScaffold(
      Column(
        children: [
          _ReportHeader(
            month: month,
            onMonth: _onMonthChanged,
            wallet: filterWallet,
            names: walletNames,
            onWallet: _onWalletChanged,
            ordering: reordering,
            onOrder: _toggleOrdering,
          ),
          Expanded(
            child: _ReportSections(
              month: month,
              reordering: reordering,
              summary: _summarySection(figs, items.isNotEmpty),
              recapTotals: figs.catTotals,
              list: _listSection(figs.items),
              listSlivers: _listSlivers(figs.items),
            ),
          ),
        ],
      ),
    );
  }

  String _walletName(String? id) => walletNames[id] ?? tr('tx_f_wallet');

  /// Bagian filter + daftar untuk path lazy (mode baca).
  /// Path susun-ulang (reorder) tetap pakai [_listSection] eager.
  List<Widget> _listSlivers(List<SaasTransaction> filtered) {
    final parts = _flowParts(filtered);
    final head = SliverPadding(
      padding: const EdgeInsets.fromLTRB(
        SsrSpace.lg,
        0,
        SsrSpace.lg,
        0,
      ),
      sliver: SliverToBoxAdapter(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _FlowFilter(
              value: flowFilter,
              onChanged: (v) => setState(() => flowFilter = v),
            ),
            const SizedBox(height: SsrSpace.md),
            if (parts.pairs.isNotEmpty) ...[
              _TransferHints(pairs: parts.pairs, nameOf: _walletName),
              const SizedBox(height: SsrSpace.md),
            ],
          ],
        ),
      ),
    );
    if (filtered.isEmpty) {
      return [
        head,
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            SsrSpace.lg,
            0,
            SsrSpace.lg,
            SsrSpace.lg,
          ),
          sliver: SliverToBoxAdapter(
            child: EmptyView(
              icon: AppIcons.reports,
              illustration: 'assets/illustrations/empty_laporan.svg',
              title: tr('r_empty_t'),
              subtitle: tr('r_empty_s'),
              actionLabel: tr('reload'),
              onAction: _load,
            ),
          ),
        ),
      ];
    }
    if (parts.visible.isEmpty) {
      return [
        head,
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            SsrSpace.lg,
            0,
            SsrSpace.lg,
            SsrSpace.lg,
          ),
          sliver: SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: SsrSpace.xl),
              child: Text(tr('r_noflow'), textAlign: TextAlign.center),
            ),
          ),
        ),
      ];
    }
    return [head, ..._TxListCard(items: parts.visible).slivers(context)];
  }

  /// Saring alur + deteksi pasangan transfer (dipakai list widget & slivers).
  ({List<SaasTransaction> visible, List<TransferPair> pairs}) _flowParts(
    List<SaasTransaction> filtered,
  ) {
    final visible = filtered
        .where((t) => flowFilter == 'all' || t.type == flowFilter)
        .toList();
    return (visible: visible, pairs: detectTransferPairs(filtered));
  }

  Widget _listSection(List<SaasTransaction> filtered) {
    final parts = _flowParts(filtered);
    final visible = parts.visible;
    final pairs = parts.pairs;
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

/// Angka turunan sebulan dari list yang sudah difilter dompet.
class _MonthFigures {
  final List<SaasTransaction> items;
  final double totalIn;
  final double totalOut;
  final double spendOut;
  final double savingOut;
  final double net;
  final Map<String, double> catTotals;

  const _MonthFigures({
    required this.items,
    required this.totalIn,
    required this.totalOut,
    required this.spendOut,
    required this.savingOut,
    required this.net,
    required this.catTotals,
  });
}

/// Kepala Laporan: month picker + filter dompet + toggle susun ulang.
/// Murni visual; state dan logika tetap milik ReportsScreenState.
class _ReportHeader extends StatelessWidget {
  final String month;
  final ValueChanged<String> onMonth;
  final String? wallet;
  final Map<String, String> names;
  final ValueChanged<String?> onWallet;
  final bool ordering;
  final VoidCallback onOrder;

  const _ReportHeader({
    required this.month,
    required this.onMonth,
    required this.wallet,
    required this.names,
    required this.onWallet,
    required this.ordering,
    required this.onOrder,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            SsrSpace.lg,
            SsrSpace.lg,
            SsrSpace.lg,
            0,
          ),
          child: MonthPicker(month: month, onChanged: onMonth),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            SsrSpace.lg,
            SsrSpace.sm,
            SsrSpace.lg,
            0,
          ),
          child: _WalletFilterDropdown(
            value: wallet,
            names: names,
            onChanged: onWallet,
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: onOrder,
            child: Text(tr(ordering ? 'r_arrange_done' : 'r_arrange')),
          ),
        ),
      ],
    );
  }
}

/// Daftar seksi Laporan (ringkasan, rekap, daftar) ikut urutan TopN/reorder.
/// Murni relokasi builder ListenableBuilder dari build; logika identik.
class _ReportSections extends StatelessWidget {
  final String month;
  final bool reordering;
  final Widget summary;
  final Map<String, double> recapTotals;
  final Widget list;

  /// Varian lazy seksi daftar untuk mode baca (dibangun di parent).
  final List<Widget> listSlivers;

  const _ReportSections({
    required this.month,
    required this.reordering,
    required this.summary,
    required this.recapTotals,
    required this.list,
    required this.listSlivers,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([reportSectionOrder, reportsTopN]),
      builder: (context, _) {
        final order = sanitizeSectionOrder(reportSectionOrder.value);
        final sections = <String, Widget>{
          'summary': summary,
          'recap': _CategoryRecap(
            key: ValueKey('recap-$month'),
            totals: recapTotals,
            topN: reportsTopN.value,
          ),
          'list': list,
        };
        final kids = _sectionKids(order, sections, recapTotals.isEmpty);
        if (!reordering) {
          return CustomScrollView(
            slivers: [
              for (final id in order)
                if (id == 'recap' && recapTotals.isEmpty)
                  const SliverToBoxAdapter(
                    key: ValueKey('recap-empty'),
                    child: SizedBox.shrink(),
                  )
                else if (id == 'list')
                  ...listSlivers
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      SsrSpace.lg,
                      0,
                      SsrSpace.lg,
                      SsrSpace.lg,
                    ),
                    sliver: SliverToBoxAdapter(child: sections[id]!),
                  ),
            ],
          );
        }

        /// Pindah seksi lalu simpan urutan (tetap 3 seksi valid).
        Future<void> move(int i, int dir) async {
          final j = i + dir;
          if (j < 0 || j >= order.length) return;
          final next = List<String>.of(order);
          final moved = next.removeAt(i);
          next.insert(j, moved);
          await setReportSectionOrder(next);
        }

        return ListView(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                SsrSpace.lg,
                SsrSpace.sm,
                SsrSpace.lg,
                0,
              ),
              child: Text(
                tr('r_arrange_hint'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            for (var i = 0; i < kids.length; i++)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: kids[i]),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const DuoIcon(AppIcons.arrowUp, size: 20),
                        tooltip: tr('r_arrange_up'),
                        onPressed: i == 0 ? null : () => move(i, -1),
                      ),
                      IconButton(
                        icon: const DuoIcon(AppIcons.arrowDown, size: 20),
                        tooltip: tr('r_arrange_down'),
                        onPressed: i == kids.length - 1
                            ? null
                            : () => move(i, 1),
                      ),
                    ],
                  ),
                ],
              ),
          ],
        );
      },
    );
  }

  List<Widget> _sectionKids(
    List<String> order,
    Map<String, Widget> sections,
    bool recapEmpty,
  ) {
    return [
      for (final id in order)
        if (id == 'recap' && recapEmpty)
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
  }
}

/// Donut 3 iris bulan terpilih: emerald (masuk), rust (belanja
/// non-tabungan), gold (tabungan). Persen masuk di tengah, legenda
/// mask-aware di bawah.
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
    final scheme = Theme.of(context).colorScheme;
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
                  color: scheme.primary,
                  label: tr('tx_in'),
                  value: totalIn,
                ),
              ),
              Expanded(
                child: _FlowLegend(
                  color: scheme.error,
                  label: tr('tx_out'),
                  value: spendOut,
                ),
              ),
              Expanded(
                child: _FlowLegend(
                  color: AppColors.gold,
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
    final track = Theme.of(context).colorScheme.outline;
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
              sections: _sections(track, Theme.of(context).colorScheme),
            ),
            duration: SsrMotion.base,
            curve: SsrMotion.curve,
          ),
          _DonutCenter(pctIn: pctIn),
        ],
      ),
    );
  }

  List<PieChartSectionData> _sections(Color track, ColorScheme scheme) {
    final live = <PieChartSectionData>[
      if (totalIn > 0)
        PieChartSectionData(
          value: totalIn,
          color: scheme.primary,
          radius: 26,
          showTitle: false,
        ),
      if (spendOut > 0)
        PieChartSectionData(
          value: spendOut,
          color: scheme.error,
          radius: 26,
          showTitle: false,
        ),
      if (savingOut > 0)
        PieChartSectionData(
          value: savingOut,
          color: AppColors.gold,
          radius: 26,
          showTitle: false,
        ),
    ];
    if (live.isNotEmpty) return live;
    return [
      PieChartSectionData(
        value: 1,
        color: track,
        radius: 26,
        showTitle: false,
      ),
    ];
  }
}

/// Persen masuk di tengah donut (onSurface eksplisit agar terbaca
/// di light dan dark).
class _DonutCenter extends StatelessWidget {
  final int pctIn;

  const _DonutCenter({required this.pctIn});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$pctIn%',
            style: AppTheme.money.copyWith(
              fontSize: 20,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          Text(
            tr('r_center'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

/// Titik warna + dua baris: label lalu nominal penuh lewat amt
/// (ikut privacy mode). Tanpa truncate: nominal panjang turun baris utuh.
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 10,
          height: 10,
          margin: const EdgeInsets.only(top: 3),
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: SsrSpace.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 2),
              Text(
                amt(value),
                style: SsrType.moneyMedium.copyWith(color: color),
              ),
            ],
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
      style: ssrSegmentedStyle(context),
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
        Text(
          tr('r_recap'),
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: SsrSpace.xs),
        SectionCard(
          padding: const EdgeInsets.symmetric(
            horizontal: SsrSpace.lg,
            vertical: SsrSpace.xs,
          ),
          child: Column(
            children: [
              for (final c in result.top)
                _RecapRow(name: c.name, total: c.total),
              _RecapOthers(
                result: result,
                expanded: expanded,
                onToggle: () => setState(() => expanded = !expanded),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Satu baris rekap kategori: lencana SVG + label + nominal ala TxRow.
/// Baris rekap selalu total belanja, jadi ikut varian Keluar (tint dan
/// glif rust, nominal rust). Logika TopN tak berubah.
class _RecapRow extends StatelessWidget {
  final String name;
  final double total;

  const _RecapRow({required this.name, required this.total});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          _RecapBadge(category: name),
          const SizedBox(width: SsrSpace.md),
          Expanded(
            child: Text(
              name,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium,
            ),
          ),
          Text(
            amt(total),
            style: SsrType.moneyMedium.copyWith(color: scheme.error),
          ),
        ],
      ),
    );
  }
}

/// Lencana rekap: tint + glif ikut kustomisasi kategori bila ada,
/// else tint rust + glif rust 19px ikut baris Keluar TxRow.
class _RecapBadge extends StatelessWidget {
  final String category;

  const _RecapBadge({required this.category});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ValueListenableBuilder<Map<String, CatMeta>>(
      valueListenable: categoryMeta,
      builder: (context, meta, _) {
        final m = meta[topOf(category)];
        final base = m == null ? scheme.error : metaSlotColor(context, m.color);
        final svg = m == null
            ? svgForCategory(category)
            : svgForMetaIcon(m.icon);
        return Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: base.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Center(
            child: SvgPicture.asset(
              svg,
              width: 19,
              colorFilter: ColorFilter.mode(base, BlendMode.srcIn),
            ),
          ),
        );
      },
    );
  }
}

/// Baris Others rekap: prompt kembang saat ciut, daftar sisa plus
/// tombol tutup saat kembang. Cabang dan kondisi tampil identik
/// dengan logika inline sebelumnya.
class _RecapOthers extends StatelessWidget {
  final TopNResult result;
  final bool expanded;
  final VoidCallback onToggle;

  const _RecapOthers({
    required this.result,
    required this.expanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    if (result.others.isNotEmpty && !expanded) {
      return InkWell(
        onTap: onToggle,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  tr('r_others').replaceFirst('{n}', '${result.others.length}'),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                amt(result.othersTotal),
                style: SsrType.moneyMedium.copyWith(color: scheme.error),
              ),
            ],
          ),
        ),
      );
    }
    if (!expanded) return const SizedBox.shrink();
    return Column(
      children: [
        for (final c in result.others)
          _RecapRow(name: c.name, total: c.total),
        InkWell(
          onTap: onToggle,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Text(
              tr('r_collapse'),
              style: TextStyle(color: theme.colorScheme.primary),
            ),
          ),
        ),
      ],
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
        Text(
          tr('r_tx_title'),
          style: Theme.of(context).textTheme.titleMedium,
        ),
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

  /// Varian lazy untuk mode baca: judul + kartu (DecoratedSliver) + baris.
  /// Path susun-ulang tetap pakai [build] eager (UI transien).
  List<Widget> slivers(BuildContext context) {
    final head = SliverPadding(
      padding: const EdgeInsets.fromLTRB(
        SsrSpace.lg,
        0,
        SsrSpace.lg,
        0,
      ),
      sliver: SliverToBoxAdapter(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              tr('r_tx_title'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: SsrSpace.xs),
          ],
        ),
      ),
    );
    if (items.isEmpty) {
      return [head];
    }
    return [
      head,
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(
          SsrSpace.lg,
          0,
          SsrSpace.lg,
          SsrSpace.lg,
        ),
        sliver: DecoratedSliver(
          decoration: sectionCardDecoration(context),
          sliver: SliverPadding(
            padding: const EdgeInsets.symmetric(
              horizontal: SsrSpace.sm,
              vertical: SsrSpace.xs,
            ),
            sliver: txDaySliverList(
              items: items,
              buildRow: (t) => TxRow(tx: t),
            ),
          ),
        ),
      ),
    ];
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
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: SsrSpace.xs),
          Text(
            amt(value),
            style: SsrType.moneyMedium.copyWith(
              fontSize: 16,
              color: color,
            ),
          ),
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
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: _statCard(
                context,
                tr('tx_in'),
                totalIn,
                scheme.primary,
              ),
            ),
            const SizedBox(width: SsrSpace.md),
            Expanded(
              child: _statCard(
                context,
                tr('tx_out'),
                totalOut,
                scheme.error,
              ),
            ),
          ],
        ),
        const SizedBox(height: SsrSpace.md),
        _NetCard(monthLabel: monthLabel, net: net),
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

/// Kartu Selisih bulan: label + nominal Fraunces (mint bila surplus,
// rose bila defisit) di atas kartu noir.
class _NetCard extends StatelessWidget {
  final String monthLabel;
  final double net;

  const _NetCard({required this.monthLabel, required this.net});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SectionCard(
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
              color: net >= 0 ? scheme.primary : scheme.error,
            ),
          ),
        ],
      ),
    );
  }
}
