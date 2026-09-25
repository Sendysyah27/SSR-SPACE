import 'dart:io';

import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:ssr_space/utils/mask.dart';
import 'package:ssr_space/utils/org_prefs.dart';
import 'package:ssr_space/services/month.dart';
import 'package:ssr_space/services/transaction_service.dart';
import 'package:ssr_space/theme/app_theme.dart';
import 'package:ssr_space/models/transaction.dart';
import 'package:ssr_space/widgets/month_picker.dart';
import 'package:ssr_space/widgets/section_card.dart';
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
  bool loading = true;
  bool exporting = false;
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
      if (!mounted) return;
      setState(() {
        items = txs;
        loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        loading = false;
        err = 'Gagal memuat laporan. Periksa koneksi.';
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
    await Share.shareXFiles([XFile(f.path)], text: 'Laporan SSR SPACE (CSV)');
  }

  Future<void> _exportPdf() async {
    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        build: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'Laporan SSR SPACE',
              style: const pw.TextStyle(
                fontSize: 20,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 12),
            for (final t in items)
              pw.Text(
                '${t.date ?? '-'} | ${t.type} | ${t.amount} | ${t.category ?? '-'} | ${t.note ?? ''}',
              ),
          ],
        ),
      ),
    );
    final dir = await getTemporaryDirectory();
    final f = File('${dir.path}/laporan-ssr-space.pdf');
    await f.writeAsBytes(await doc.save());
    await Share.shareXFiles([XFile(f.path)], text: 'Laporan SSR SPACE (PDF)');
  }

  Future<void> _runExport(Future<void> Function() run, String label) async {
    if (exporting) return;
    setState(() => exporting = true);
    try {
      await run();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('File $label siap dibagikan.')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal membuat file. Coba lagi.')),
      );
    } finally {
      if (mounted) setState(() => exporting = false);
    }
  }

  void _onMonthChanged(String m) {
    setState(() => month = m);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const _ReportsScaffold(LoadingView(label: 'Menyusun laporan...'));
    }
    if (err != null) {
      return _ReportsScaffold(ErrorView(message: err!, onRetry: _load));
    }
    final totalIn = items
        .where((t) => t.type == 'in')
        .fold<double>(0, (s, t) => s + t.amount);
    final totalOut = items
        .where((t) => t.type == 'out')
        .fold<double>(0, (s, t) => s + t.amount);
    final net = totalIn - totalOut;
    return _ReportsScaffold(
      ListView(
        padding: const EdgeInsets.all(SsrSpace.lg),
        children: [
          MonthPicker(month: month, onChanged: _onMonthChanged),
          const SizedBox(height: SsrSpace.md),
          _MonthlySummary(
            monthLabel: monthLabel(month),
            totalIn: totalIn,
            totalOut: totalOut,
            net: net,
            exporting: exporting,
            hasItems: items.isNotEmpty,
            onExportCsv: () => _runExport(_exportCsv, 'CSV'),
            onExportPdf: () => _runExport(_exportPdf, 'PDF'),
          ),
          const SizedBox(height: SsrSpace.lg),
          if (items.isEmpty)
            EmptyView(
              icon: Icons.receipt_long_outlined,
              title: 'Belum ada transaksi untuk bulan ini.',
              subtitle: 'Pilih bulan lain atau catat transaksi dulu.',
              actionLabel: 'Muat ulang',
              onAction: _load,
            )
          else
            _TxListCard(items: items),
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
      appBar: AppBar(title: const Text('Laporan')),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Transaksi', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: SsrSpace.xs),
        SectionCard(
          padding: const EdgeInsets.symmetric(
            horizontal: SsrSpace.sm,
            vertical: SsrSpace.xs,
          ),
          child: Column(
            children: [
              for (var i = 0; i < items.length; i++) ...[
                if (i > 0) const Divider(height: 1),
                TxRow(tx: items[i]),
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
            : Text('Unduh $label'),
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
              child: _statCard(context, 'Masuk', totalIn, SsrColors.accent),
            ),
            const SizedBox(width: SsrSpace.md),
            Expanded(
              child: _statCard(context, 'Keluar', totalOut, SsrColors.danger),
            ),
          ],
        ),
        const SizedBox(height: SsrSpace.md),
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Selisih $monthLabel',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: SsrSpace.xs),
              Text(
                amt(net),
                style: SsrTheme.moneyLarge.copyWith(
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
