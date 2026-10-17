import 'dart:async';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ssr_space/services/ai_zen_client.dart';
import 'package:ssr_space/services/ai_chat_parse.dart';
import 'package:ssr_space/services/ai_quota.dart';
import 'package:ssr_space/utils/mask.dart';
import 'package:ssr_space/utils/org_prefs.dart';
import 'package:ssr_space/utils/datetime.dart';
import 'package:ssr_space/utils/strings.dart';
import 'package:ssr_space/services/app_settings.dart';
import 'package:ssr_space/services/billing_service.dart';
import 'package:ssr_space/services/export_files.dart';
import 'package:ssr_space/services/export_saved_notify.dart';
import 'package:ssr_space/services/month.dart';
import 'package:ssr_space/services/month_figures.dart';
import 'package:ssr_space/theme/category_emoji.dart';
import 'package:ssr_space/services/plan_limits.dart';
import 'package:ssr_space/screens/transaksi/transactions_screen.dart';
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
import 'package:ssr_space/theme/dribbble_tokens.dart';
import 'package:ssr_space/theme/glass.dart';
import 'package:ssr_space/theme/tokens.dart';
import 'package:ssr_space/models/transaction.dart';
import 'package:ssr_space/widgets/day_header.dart';
import 'package:ssr_space/widgets/drib_card.dart';
import 'package:ssr_space/widgets/month_picker.dart';
import 'package:ssr_space/widgets/premium/premium_button.dart';
import 'package:ssr_space/widgets/restyle/donut_chart.dart';
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
  // Arus kas 12 bulan terakhir (fail-open: bulan gagal = nol).
  List<_YearBar> _yearFlow = [];
  // Insight Mang AI (cache prefs 1 jam, fail-open sembunyi).
  String? insight;
  // Pagination display: halaman 100, sambung saat gulir mentok.
  final _scroll = ScrollController();
  bool hasMore = true;
  bool loadingMore = false;
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
      _yearFlow = [];
      insight = null;
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
      final ws = await WalletService().list(orgId);
      // Display: halaman terbaru (cukup untuk rekap + daftar awal).
      final txs = await TransactionService().listMonthPage(orgId, month);
      if (!mounted) return;
      // Arus 12 bulan paralel (tiap bulan fail-open nol).
      final yf = await _loadYearFlow(orgId, filterWallet);
      if (!mounted) return;
      setState(() {
        items = txs;
        fig = cur;
        hasMore = txPageHasMore(txs.length, txPageSize);
        _yearFlow = yf;
        walletNames = {for (final w in ws) w.id: w.name};
        if (filterWallet != null && !walletNames.containsKey(filterWallet)) {
          filterWallet = null;
        }
        loading = false;
      });
      // Insight AI: tak block layar (async, cache 1 jam).
      unawaited(_loadInsight(orgId));
    } catch (_) {
      if (!mounted) return;
      setState(() {
        loading = false;
        err = tr('r_err_load');
      });
    }
  }

  /// Total masuk/keluar 12 bulan terakhir (paralel, per bulan fail-open).
  Future<List<_YearBar>> _loadYearFlow(
      String orgId, String? walletId) async {
    final now = DateTime.now();
    final months = <String>[];
    for (var i = 11; i >= 0; i--) {
      final d = DateTime(now.year, now.month - i, 1);
      months.add('${d.year}-${d.month.toString().padLeft(2, '0')}');
    }
    final out = await Future.wait(months.map((m) async {
      try {
        final mix = await TransactionService()
            .monthMix(orgId, m, walletId: walletId);
        final f = foldMonthMix(
          mix.rows,
          otherLabel: '',
          totalN: mix.totalN,
        );
        return _YearBar(month: m, masuk: f.totalIn, keluar: f.totalOut);
      } catch (_) {
        return _YearBar(month: m, masuk: 0, keluar: 0);
      }
    }));
    return out;
  }

  /// Insight Mang AI 2-3 kalimat (brief §5.1): cache prefs 1 jam per
  /// org+bulan, fail-silent (kartu sembunyi). Tanpa foto (teks saja).
  Future<void> _loadInsight(String orgId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'ai_insight_${orgId}_$month';
      final at = prefs.getInt('${key}_at') ?? 0;
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      if (nowMs - at < 3600000) {
        final cached = prefs.getString(key);
        if (cached != null && cached.trim().isNotEmpty) {
          if (!mounted) return;
          // Kompat: cache lama mungkin masih JSON mentah kontrak {"reply",...}.
          setState(() => insight = parseChatReply(cached).reply.trim());
          return;
        }
      }
      final f = fig;
      if (f == null) return;
      final tops = f.catTotalsNoSaving.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final top3 = tops
          .take(3)
          .map((e) => '${e.key} ${amt(e.value)}')
          .join(', ');
      final prompt =
          'Kamu Mang AI, asisten keuangan santai Bahasa Indonesia. '
          'Data bulan ${monthLabel(month)}: masuk ${amt(f.totalIn)}, '
          'keluar ${amt(f.totalOut)}, net ${amt(f.net)}. '
          'Top belanja: ${top3.isEmpty ? '-' : top3}. '
          'Tulis 2-3 kalimat manusiawi: sorotan + satu saran hemat. '
          'Tanpa list mentah, tanpa markdown berat.';
      // Gate kuota AI (entitlement Fase 1): insight = prefetch otomatis
      // tiap buka Laporan (bukan aksi user) -> mentok = fail-silent
      // (kartu sembunyi), tanpa paywall. Cache di atas tetap tampil
      // tanpa makan kuota. Fail-open: server diam -> lolos.
      if (orgId.isNotEmpty && !await aiAllowed(orgId)) return;
      final r = await aiChat(prompt);
      // Sukses -> catat pemakaian kuota AI (fail-silent, tanpa blokir UI).
      if (orgId.isNotEmpty) unawaited(recordAiUse(orgId, 'insight'));
      if (!mounted) return;
      // Kontrak Mang AI: {"reply":"...","action":...} -> tampilkan reply saja.
      final parsed = parseChatReply(r.text);
      final text = parsed.reply.trim();
      if (text.isEmpty) return;
      await prefs.setString(key, text);
      await prefs.setInt('${key}_at', nowMs);
      if (!mounted) return;
      setState(() => insight = text);
    } catch (_) {}
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
  ) {
    final hasFlow = f.totalIn + f.spendOut + f.savingOut > 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _YearFlowCard(bars: _yearFlow),
        const SizedBox(height: SsrSpace.md),
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
        if (insight != null) ...[
          const SizedBox(height: SsrSpace.md),
          _InsightCard(text: insight!),
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
          ),
          Expanded(
            child: _ReportSections(
              month: month,
              summary: _summarySection(figs, items.isNotEmpty),
              recapTotals: figs.catTotals,
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

}
/// Satu batang tahun: total masuk/keluar sebulan (fail-open nol).
class _YearBar {
  final String month;
  final double masuk;
  final double keluar;
  const _YearBar({
    required this.month,
    required this.masuk,
    required this.keluar,
  });
}

/// Angka turunan sebulan dari list yang sudah difilter dompet.
class _MonthFigures {  final List<SaasTransaction> items;
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

/// Kepala Laporan: month picker + filter dompet dalam wadah segmented
/// iOS (brief §5.1). Murni visual; state milik ReportsScreenState.
class _ReportHeader extends StatelessWidget {
  final String month;
  final ValueChanged<String> onMonth;
  final String? wallet;
  final Map<String, String> names;
  final ValueChanged<String?> onWallet;

  const _ReportHeader({
    required this.month,
    required this.onMonth,
    required this.wallet,
    required this.names,
    required this.onWallet,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        SsrSpace.lg,
        SsrSpace.lg,
        SsrSpace.lg,
        0,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: SsrSpace.sm,
          vertical: SsrSpace.xs,
        ),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Expanded(
              child: MonthPicker(month: month, onChanged: onMonth),
            ),
            Container(
              width: 1,
              height: 28,
              color: scheme.outline,
            ),
            Expanded(
              child: _WalletFilterDropdown(
                value: wallet,
                names: names,
                onChanged: onWallet,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Daftar seksi Laporan (ringkasan, rekap, daftar) ikut urutan TopN/reorder.
/// Murni relokasi builder ListenableBuilder dari build; logika identik.
class _ReportSections extends StatelessWidget {
  final String month;
  final Widget summary;
  final Map<String, double> recapTotals;

  /// Varian lazy seksi daftar untuk mode baca (dibangun di parent).
  final List<Widget> listSlivers;

  /// Paginasi display (milik state parent).
  final ScrollController scrollController;

  const _ReportSections({
    required this.month,
    required this.summary,
    required this.recapTotals,
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
            month: month,
          ),
        };
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
              else if (id == 'summary')
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
      },
    );
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
    final total = totalIn + spendOut + savingOut;
    final pctIn = total <= 0 ? 0 : (totalIn / total * 100).round();
    return DribCard(
      padding: const EdgeInsets.all(GlassSpace.lg),
      child: DonutChart(
        centerText: '$pctIn%',
        slices: [
          DonutSlice(
            value: totalIn,
            label: tr('tx_in'),
            color: DribTokens.primary,
          ),
          DonutSlice(
            value: spendOut,
            label: tr('tx_out'),
            color: DribTokens.navy,
          ),
          DonutSlice(
            value: savingOut,
            label: tr('sv_label'),
            color: DribTokens.accentOrange,
          ),
        ],
      ),
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
    return DribCard(
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
  final String month;

  const _CategoryRecap({
    super.key,
    required this.totals,
    required this.topN,
    required this.month,
  });

  @override
  State<_CategoryRecap> createState() => _CategoryRecapState();
}

class _CategoryRecapState extends State<_CategoryRecap> {
  bool expanded = false;

  void _drill(String category) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TransactionsScreen(
          initialMonth: widget.month,
          initialCategory: category,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.totals.isEmpty) return const SizedBox.shrink();
    final result = top8PlusOthers(widget.totals, enabled: widget.topN);
    final theme = Theme.of(context);
    final sum = result.top.fold(0.0, (s, c) => s + c.total) +
        result.othersTotal;
    final shown = expanded
        ? [...result.top, ...result.others]
        : result.top.take(5).toList();
    final canExpand =
        result.top.length + result.others.length > shown.length ||
            expanded;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          tr('r_recap'),
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: SsrSpace.xs),
        DribCard(
          padding: const EdgeInsets.symmetric(
            horizontal: GlassSpace.lg,
            vertical: GlassSpace.sm,
          ),
          child: Column(
            children: [
              for (final c in shown)
                _RecapRow(
                  name: c.name,
                  total: c.total,
                  pct: sum > 0 ? c.total / sum : 0,
                  onTap: () => _drill(c.name),
                ),
              if (canExpand)
                InkWell(
                onTap: () => setState(() => expanded = !expanded),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        expanded ? tr('r_collapse') : tr('r_see_all'),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Satu baris rekap (brief §5.2): emoji + nama 15sp + persen kanan,
/// bar 6px di bawah. Tap = drill ke Transaksi filter kategori ini.
class _RecapRow extends StatelessWidget {
  final String name;
  final double total;
  final double pct;
  final VoidCallback onTap;

  const _RecapRow({
    required this.name,
    required this.total,
    required this.pct,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(SsrRadius.tile),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  categoryEmoji(name),
                  style: const TextStyle(fontSize: 22),
                ),
                const SizedBox(width: SsrSpace.sm),
                Expanded(
                  child: Text(
                    name,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(fontSize: 15),
                  ),
                ),
                Text(
                  '${(pct * 100).round()}%',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(width: SsrSpace.sm),
                Text(
                  amt(total),
                  style: SsrType.moneyMedium.copyWith(color: scheme.error),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: pct.clamp(0.0, 1.0).toDouble(),
                minHeight: 6,
                backgroundColor: scheme.outline,
                valueColor:
                    AlwaysStoppedAnimation<Color>(scheme.error),
              ),
            ),
          ],
        ),
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
      backgroundColor: DribTokens.bg,
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
        DribCard(
          padding: const EdgeInsets.symmetric(
            horizontal: GlassSpace.sm,
            vertical: GlassSpace.xs,
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
          decoration: glassSliverDecoration(),
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

/// Kartu ARUS KAS 12 BULAN (brief §5.1): grouped bar masuk biru +
/// keluar merah, radius 4 atas, bulan berjalan highlight, ringkasan.
/// Biru #0A84FF & merah #FF453A untuk GRAFIK (bukan teks) — alasan
/// identitas iOS per brief; teks tetap warna skema (R-37 tercatat).
class _YearFlowCard extends StatelessWidget {
  final List<_YearBar> bars;

  const _YearFlowCard({required this.bars});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    var totalIn = 0.0;
    var totalOut = 0.0;
    var maxV = 0.0;
    for (final b in bars) {
      totalIn += b.masuk;
      totalOut += b.keluar;
      if (b.masuk > maxV) maxV = b.masuk;
      if (b.keluar > maxV) maxV = b.keluar;
    }
    const inColor = DribTokens.primary;
    const outColor = DribTokens.navy;
    final nowM = currentMonth();
    return DribCard(
      padding: const EdgeInsets.all(GlassSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr('r_flow12'),
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: SsrSpace.md),
          SizedBox(
            height: 170,
            child: bars.isEmpty
                ? Center(
                    child: Text(
                      tr('r_empty_s'),
                      style: theme.textTheme.bodySmall,
                    ),
                  )
                : BarChart(
                    BarChartData(
                      maxY: maxV <= 0 ? 1 : maxV * 1.15,
                      gridData: const FlGridData(show: false),
                      borderData: FlBorderData(show: false),
                      titlesData: FlTitlesData(
                        leftTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (v, _) {
                              final i = v.toInt();
                              if (i < 0 || i >= bars.length) {
                                return const SizedBox.shrink();
                              }
                              const names = 'JFMAMJJASOND';
                              final m =
                                  int.tryParse(bars[i].month.substring(5)) ??
                                      1;
                              return Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  names[(m - 1).clamp(0, 11)],
                                  style: const TextStyle(fontSize: 9),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      barGroups: [
                        for (var i = 0; i < bars.length; i++)
                          BarChartGroupData(
                            x: i,
                            barsSpace: 2,
                            barRods: [
                              BarChartRodData(
                                toY: bars[i].masuk,
                                width: 6,
                                color: inColor,
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(4),
                                ),
                                backDrawRodData: BackgroundBarChartRodData(
                                  show:
                                      bars[i].month == nowM,
                                  toY: maxV <= 0 ? 1 : maxV * 1.15,
                                  color: scheme.primary
                                      .withValues(alpha: 0.10),
                                ),
                              ),
                              BarChartRodData(
                                toY: bars[i].keluar,
                                width: 6,
                                color: outColor,
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(4),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
          ),
          const SizedBox(height: SsrSpace.sm),
          Text(
            '${tr('tx_in')} ${amt(totalIn)} · ${tr('tx_out')} ${amt(totalOut)}',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

/// Kartu INSIGHT MANG AI (brief §5.1): 2-3 kalimat manusiawi, cache
/// prefs 1 jam, fail-silent (sembunyi bila gagal). Tint ungu-biru
/// sebagai penanda identitas AI (R-01: alasan tertulis, satu kartu).
class _InsightCard extends StatelessWidget {
  final String text;

  const _InsightCard({required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DribCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr('ai_insight_t'),
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: SsrSpace.sm),
          Text(text, style: theme.textTheme.bodyMedium),
        ],
      ),
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
    return DribCard(
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
      child: PremiumButton(
        height: 48,
        loading: exporting,
        onPressed: hasItems && !exporting ? onTap : null,
        gradient: const LinearGradient(
          colors: [DribTokens.primary, DribTokens.primary],
        ),
              foreground: DribTokens.navy,
        label: tr('r_dl').replaceFirst('{l}', label),
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
// rose bila defisit) di atas kartu gelap.
class _NetCard extends StatelessWidget {
  final String monthLabel;
  final double net;

  const _NetCard({required this.monthLabel, required this.net});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DribCard(
      padding: const EdgeInsets.all(GlassSpace.lg),
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
