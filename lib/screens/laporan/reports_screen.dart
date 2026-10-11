import 'dart:async';
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
import 'package:ssr_space/services/cashflow_forecast.dart';
import 'package:ssr_space/services/category_icons.dart';
import 'package:ssr_space/services/category_meta.dart';
import 'package:ssr_space/services/export_files.dart';
import 'package:ssr_space/services/export_saved_notify.dart';
import 'package:ssr_space/services/month.dart';
import 'package:ssr_space/services/month_compare.dart';
import 'package:ssr_space/services/month_figures.dart';
import 'package:ssr_space/services/recurring_bills.dart';
import 'package:ssr_space/services/plan_limits.dart';
import 'package:ssr_space/services/report_export.dart';
import 'package:ssr_space/services/report_pdf.dart';
import 'package:ssr_space/services/report_xlsx.dart';
import 'package:ssr_space/services/xlsx_layout.dart';
import 'package:ssr_space/services/reports_topn.dart';
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
  // Angka eksak via RPC (ikut filter dompet); display via halaman.
  MonthFigures? fig;
  Map<String, double> prevCats = {};
  // Prakiraan kas 30 hari (fail-open null = kartu sembunyi).
  CashForecast? forecast;
  // Pagination display: halaman 100, sambung saat gulir mentok.
  final _scroll = ScrollController();
  bool hasMore = true;
  bool loadingMore = false;
  bool reordering = false;
  String? err;

  @override
  void initState() {
    super.initState();
    month = currentMonth();
    _scroll.addListener(_onScroll);
    _load();
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients || loading || loadingMore || !hasMore) return;
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 600) {
      unawaited(_loadMore());
    }
  }

  Future<void> reload() => _load();

  Future<void> _load() async {
    setState(() {
      loading = true;
      err = null;
      items = [];
      hasMore = true;
      loadingMore = false;
      forecast = null;
    });
    try {
      final orgId = await activeOrgId();
      if (!mounted) return;
      if (orgId.isEmpty) {
        setState(() => loading = false);
        return;
      }
      // Angka eksak via RPC (ikut filter dompet); gagal → fallback list.
      final cur = await _figuresFor(orgId, month, filterWallet);
      var prev = <String, double>{};
      try {
        final pm = await _figuresFor(
          orgId,
          prevMonth(month),
          filterWallet,
        );
        prev = pm.catTotalsNoSaving;
      } catch (_) {
        prev = {};
      }
      final ws = await WalletService().list(orgId);
      // Display: halaman terbaru (cukup untuk rekap + daftar awal).
      final txs = await TransactionService().listMonthPage(orgId, month);
      if (!mounted) return;
      // Prakiraan kas: saldo kini + run-rate 30 hari + tagihan terjadwal.
      // Fail-open null (kartu sembunyi), tak ganggu angka utama.
      CashForecast? fc;
      try {
        fc = await _loadForecast(orgId);
      } catch (_) {
        fc = null;
      }
      if (!mounted) return;
      setState(() {
        items = txs;
        fig = cur;
        prevCats = prev;
        hasMore = txPageHasMore(txs.length, txPageSize);
        forecast = fc;
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

  /// Prakiraan 30 hari dari hari ini: saldo dompet kini + run-rate
  /// 30 hari terakhir + tagihan aktif terjadwal. Throw bila gagal
  /// (pemanggil fail-open).
  Future<CashForecast> _loadForecast(String orgId) async {
    final bals = await WalletService().balances(orgId);
    var start = 0.0;
    for (final b in bals) {
      start += b.balance;
    }
    final now = DateTime.now();
    String ymd(DateTime d) =>
        '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
    final today = ymd(now);
    final hist = await TransactionService().listRange(
      orgId,
      ymd(now.subtract(const Duration(days: 29))),
      ymd(now.add(const Duration(days: 1))),
      limit: 500,
    );
    final rate = dailyRate(
      [
        for (final t in hist)
          TxFlow(date: t.date ?? '', type: t.type, amount: t.amount),
      ],
      30,
    );
    final bills = await loadBills();
    final dues = upcomingBills(
      [
        for (final b in bills)
          BillDue(nextDue: b.nextDue, amount: b.amount, active: b.active),
      ],
      today,
      forecastDays,
    );
    return projectForecast(
      start: start,
      inPerDay: rate.inPerDay,
      outPerDay: rate.outPerDay,
      dues: dues,
      fromDate: today,
    );
  }

  /// Angka sebulan (ikut filter dompet): RPC dulu, list penuh bila gagal.
  Future<MonthFigures> _figuresFor(
    String orgId,
    String m,
    String? walletId,
  ) async {
    try {
      final mix = await TransactionService()
          .monthMix(orgId, m, walletId: walletId);
      return foldMonthMix(
        mix.rows,
        otherLabel: tr('cat_other'),
        totalN: mix.totalN,
      );
    } catch (_) {
      final full = await TransactionService().listMonth(orgId, m);
      final f = filterByWallet(full, walletId);
      return foldMonthMix(
        mixRowsFromTx([
          for (final t in f)
            {'type': t.type, 'category': t.category, 'amount': t.amount},
        ]),
        otherLabel: tr('cat_other'),
        totalN: f.length,
      );
    }
  }

  /// Halaman display berikut (filter dompet tetap di klien, spt semula).
  Future<void> _loadMore() async {
    if (loading || loadingMore || !hasMore || err != null) return;
    setState(() => loadingMore = true);
    try {
      final orgId = await activeOrgId();
      if (!mounted) return;
      if (orgId.isEmpty) {
        setState(() => loadingMore = false);
        return;
      }
      final t = await TransactionService()
          .listMonthPage(orgId, month, offset: items.length);
      if (!mounted) return;
      setState(() {
        items = [...items, ...t];
        hasMore = txPageHasMore(t.length, txPageSize);
        loadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => loadingMore = false);
    }
  }

  /// Item ekspor = yang tampil di layar (filter dompet + jenis sesi).
  /// CSV dan PDF memakai daftar yang sama.
  List<SaasTransaction> _exportItems(List<SaasTransaction> src) =>
      applyReportFilters(src, filterWallet, flowFilter);

  /// Ekspor memuat SEMUA halaman dulu (cap 2000) supaya tak kepotong
  /// paginasi display. Gagal muat = lempar (ditangkap _runExport).
  Future<List<SaasTransaction>> _allItems() async {
    final orgId = await activeOrgId();
    final all = <SaasTransaction>[];
    var offset = 0;
    for (var i = 0; i < 20; i++) {
      final page = await TransactionService()
          .listMonthPage(orgId, month, offset: offset);
      all.addAll(page);
      if (!txPageHasMore(page.length, txPageSize)) break;
      offset += page.length;
    }
    return all;
  }

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
    final data = _exportItems(await _allItems());
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
    final data = _exportItems(await _allItems());
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

  Future<void> _exportXlsx() async {
    final data = _exportItems(await _allItems());
    final bytes = buildReportXlsx(
      data,
      walletNames,
      metaLine: tr('r_xlsx_meta')
          .replaceFirst('{p}', monthLabel(month))
          .replaceFirst('{d}', idFullDate(DateTime.now())),
    );
    if (bytes == null) throw StateError('xlsx kosong');
    final base = exportBaseName(
      month,
      walletLabel: _exportWalletLabel(),
      flow: flowFilter,
    );
    await _saveAndNotify(
      base: base,
      ext: 'xlsx',
      shareText: tr('r_share_xlsx'),
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

  void _onWalletChanged(String? v) {
    // Angka ikut filter dompet → hitung ulang (figures + halaman).
    setState(() => filterWallet = v);
    _load();
  }

  void _toggleOrdering() => setState(() => reordering = !reordering);

  /// Angka sebulan dari agregat RPC (eksak, ikut filter dompet);
  /// display/export memakai item termuat di bawah.
  _MonthFigures _figuresFromFold(List<SaasTransaction> loaded) {
    final f = fig ?? MonthFigures.empty;
    return _MonthFigures(
      items: loaded,
      totalIn: f.totalIn,
      totalOut: f.totalOut,
      spendOut: f.spendOut,
      savingOut: f.savingOut,
      net: f.net,
      catTotals: f.catTotals,
      catTotalsNoSaving: f.catTotalsNoSaving,
      totalN: f.totalN,
    );
  }

  Widget _summarySection(
    _MonthFigures f,
    bool hasItems,
    Map<String, double> prevCats,
  ) {
    final hasFlow = f.totalIn + f.spendOut + f.savingOut > 0;
    final deltas = compareMonths(f.catTotalsNoSaving, prevCats);
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
          onExportXlsx: () => _runExport(_exportXlsx),
          onExportPdf: () => _guardPdf(),
        ),
        if (forecast != null && month == currentMonth()) ...[
          const SizedBox(height: SsrSpace.md),
          _ForecastCard(fc: forecast!),
        ],
        if (deltas.isNotEmpty) ...[
          const SizedBox(height: SsrSpace.md),
          _CompareCard(deltas: deltas),
        ],
      ],
    );
  }

  Future<void> _guardPdf() async {
    String plan = 'free';
    try {
      final orgId = await activeOrgId();
      plan = orgId.isEmpty ? 'free' : await currentPlan(orgId);
    } catch (_) {
      // Offline / org hilang: gagal jujur via snackbar, bukan diam.
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(tr('r_export_fail'))));
      return;
    }
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
    final figs = _figuresFromFold(filterByWallet(items, filterWallet));
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
              summary: _summarySection(figs, items.isNotEmpty, prevCats),
              recapTotals: figs.catTotals,
              list: _listSection(figs.items),
              listSlivers: _listSlivers(
                figs.items,
                totalN: figs.totalN,
              ),
              scrollController: _scroll,
            ),
          ),
        ],
      ),
    );
  }

  String _walletName(String? id) => walletNames[id] ?? tr('tx_f_wallet');

  /// Bagian filter + daftar untuk path lazy (mode baca).
  /// Path susun-ulang (reorder) tetap pakai [_listSection] eager.
  /// [totalN] = cacah filter eksak (ikut filter dompet) untuk caption jujur.
  List<Widget> _listSlivers(
    List<SaasTransaction> filtered, {
    required int totalN,
  }) {
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
    return [
      head,
      ..._TxListCard(items: parts.visible).slivers(context),
      ..._pageFooter(totalN: totalN, loaded: filtered.length),
    ];
  }

  /// Kaki paginasi: spinner saat muat, caption jujur saat parsial/habis.
  List<Widget> _pageFooter({required int totalN, required int loaded}) {
    if (loadingMore) {
      return const [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: SsrSpace.lg),
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
        ),
      ];
    }
    if (hasMore && loaded > 0) {
      return [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: SsrSpace.md),
            child: Center(
              child: Text(
                tr('tx_partial').replaceFirst('{n}', '$loaded'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
        ),
      ];
    }
    if (!hasMore && totalN > 0) {
      return [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: SsrSpace.md),
            child: Center(
              child: Text(
                tr('tx_all_shown').replaceFirst('{n}', '$totalN'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
        ),
      ];
    }
    return const [];
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
  final Map<String, double> catTotalsNoSaving;
  final int totalN;

  const _MonthFigures({
    required this.items,
    required this.totalIn,
    required this.totalOut,
    required this.spendOut,
    required this.savingOut,
    required this.net,
    required this.catTotals,
    required this.catTotalsNoSaving,
    required this.totalN,
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

  /// Paginasi display (milik state parent).
  final ScrollController scrollController;

  const _ReportSections({
    required this.month,
    required this.reordering,
    required this.summary,
    required this.recapTotals,
    required this.list,
    required this.listSlivers,
    required this.scrollController,
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
            controller: scrollController,
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
/// Kartu banding bulan ini vs bulan lalu per kategori, urut perubahan
/// terbesar. 3 teratas tebal + panah berwarna (naik = merah, turun =
/// hijau). Panah selalu ditemani angka persen, bukan makna tunggal.
class _CompareCard extends StatelessWidget {
  final List<MonthDelta> deltas;

  const _CompareCard({required this.deltas});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tr('cmp_title'), style: theme.textTheme.titleSmall),
          const SizedBox(height: SsrSpace.sm),
          for (var i = 0; i < deltas.length; i++)
            _CompareRow(
              delta: deltas[i],
              highlight: i < 3,
              upColor: scheme.error,
              downColor: scheme.primary,
            ),
        ],
      ),
    );
  }
}

class _CompareRow extends StatelessWidget {
  final MonthDelta delta;
  final bool highlight;
  final Color upColor;
  final Color downColor;

  const _CompareRow({
    required this.delta,
    required this.highlight,
    required this.upColor,
    required this.downColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final d = delta;
    final up = d.delta > 0;
    final same = d.delta == 0;
    final color = same
        ? theme.colorScheme.outline
        : (up ? upColor : downColor);
    final pctText = d.pct == null
        ? tr('cmp_new')
        : '${d.pct! >= 0 ? '+' : ''}${d.pct!.round()}%';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          if (!same)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: DuoIcon(
                up ? AppIcons.arrowUp : AppIcons.arrowDown,
                size: 16,
                color: color,
              ),
            ),
          Expanded(
            child: Text(
              d.category,
              overflow: TextOverflow.ellipsis,
              style: (highlight
                      ? theme.textTheme.bodyMedium
                      : theme.textTheme.bodySmall)
                  ?.copyWith(fontWeight:
                      highlight ? FontWeight.w700 : FontWeight.w400),
            ),
          ),
          Text(
            amt(d.cur),
            style: theme.textTheme.bodySmall?.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 56,
            child: Text(
              pctText,
              textAlign: TextAlign.right,
              style: theme.textTheme.bodySmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Prakiraan kas 30 hari: garis saldo + angka akhir bulan + warning.
/// Merah bila diprediksi minus; chart ikut colorScheme (dark aman).
class _ForecastCard extends StatelessWidget {
  final CashForecast fc;

  const _ForecastCard({required this.fc});

  /// Sumbu-Y kompak: 1500rb -> 1,5jt, 50000 -> 50rb.
  String _short(double v) {
    final a = v.abs();
    final sign = v < 0 ? '-' : '';
    if (a >= 1000000) {
      final n = a / 1000000;
      return '$sign${n.toStringAsFixed(n % 1 == 0 ? 0 : 1)}jt';
    }
    if (a >= 1000) {
      final n = a / 1000;
      return '$sign${n.toStringAsFixed(n % 1 == 0 ? 0 : 1)}rb';
    }
    return '$sign${a.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final now = DateTime.now();
    final lastDay = DateTime(now.year, now.month + 1, 0).day;
    final endIdx = (lastDay - now.day).clamp(0, fc.points.length - 1);
    final endVal = fc.points[endIdx];
    final negative = fc.min < 0;
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tr('cf_title'), style: theme.textTheme.titleSmall),
          Text(tr('cf_sub'), style: theme.textTheme.bodySmall),
          const SizedBox(height: SsrSpace.sm),
          SizedBox(
            height: 160,
            child: LineChart(_data(scheme, negative)),
          ),
          const SizedBox(height: SsrSpace.sm),
          Text(
            tr('cf_end').replaceFirst('{m}', amt(endVal)),
            style: theme.textTheme.titleSmall?.copyWith(
              color: endVal < 0 ? scheme.error : null,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          if (negative) ...[
            const SizedBox(height: SsrSpace.sm),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: scheme.error.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(SsrRadius.chip),
              ),
              child: Text(
                tr('cf_warn')
                    .replaceFirst('{m}', amt(fc.min))
                    .replaceFirst('{n}', '${fc.minDay}'),
                style: TextStyle(
                  color: scheme.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  LineChartData _data(ColorScheme scheme, bool negative) {
    final pts = fc.points;
    var lo = pts.first;
    var hi = pts.first;
    for (final v in pts) {
      if (v < lo) lo = v;
      if (v > hi) hi = v;
    }
    if ((hi - lo).abs() < 1) {
      hi += 1;
      lo -= 1;
    }
    final pad = (hi - lo) * 0.1;
    return LineChartData(
      minX: 0,
      maxX: (pts.length - 1).toDouble(),
      minY: lo - pad,
      maxY: hi + pad,
      lineTouchData: const LineTouchData(enabled: false),
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: (hi - lo) / 3,
      ),
      titlesData: FlTitlesData(
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 44,
            getTitlesWidget: (v, _) => Text(
              _short(v),
              style: const TextStyle(fontSize: 10),
            ),
          ),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            interval: 10,
            getTitlesWidget: (v, _) => Text(
              '${v.toInt()}',
              style: const TextStyle(fontSize: 10),
            ),
          ),
        ),
        topTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
      ),
      borderData: FlBorderData(show: false),
      extraLinesData: negative
          ? ExtraLinesData(
              horizontalLines: [
                HorizontalLine(
                  y: 0,
                  color: scheme.error,
                  dashArray: [4, 4],
                ),
              ],
            )
          : const ExtraLinesData(),
      lineBarsData: [
        LineChartBarData(
          spots: [
            for (var i = 0; i < pts.length; i++) FlSpot(i.toDouble(), pts[i]),
          ],
          isCurved: true,
          color: negative ? scheme.error : scheme.primary,
          barWidth: 2.5,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(
            show: true,
            color: (negative ? scheme.error : scheme.primary)
                .withValues(alpha: 0.15),
          ),
        ),
        if (negative)
          LineChartBarData(
            spots: [FlSpot(fc.minDay.toDouble(), fc.min)],
            color: Colors.transparent,
            barWidth: 0,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, _, __, ___) => FlDotCirclePainter(
                radius: 4,
                color: scheme.error,
              ),
            ),
          ),
      ],
    );
  }
}

class _MonthlySummary extends StatelessWidget {
  final String monthLabel;
  final double totalIn;
  final double totalOut;
  final double net;
  final bool exporting;
  final bool hasItems;
  final VoidCallback onExportCsv;
  final VoidCallback onExportXlsx;
  final VoidCallback onExportPdf;

  const _MonthlySummary({
    required this.monthLabel,
    required this.totalIn,
    required this.totalOut,
    required this.net,
    required this.exporting,
    required this.hasItems,
    required this.onExportCsv,
    required this.onExportXlsx,
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
            _exportButton('XLSX', onExportXlsx),
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
