import 'dart:io';

import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:ssr_space/core/format/money.dart';
import 'package:ssr_space/core/saas/month.dart';
import 'package:ssr_space/core/saas/transaction_service.dart';
import 'package:ssr_space/core/theme/app_theme.dart';
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
      final orgId =
          (await SharedPreferences.getInstance()).getString('active_org_id') ??
          '';
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
              style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
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

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Laporan')),
        body: const LoadingView(label: 'Menyusun laporan...'),
      );
    }
    if (err != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Laporan')),
        body: ErrorView(message: err!, onRetry: _load),
      );
    }
    final totalIn = items
        .where((t) => t.type == 'in')
        .fold<double>(0, (s, t) => s + t.amount);
    final totalOut = items
        .where((t) => t.type == 'out')
        .fold<double>(0, (s, t) => s + t.amount);
    final net = totalIn - totalOut;
    return Scaffold(
      appBar: AppBar(title: const Text('Laporan')),
      body: ListView(
        padding: const EdgeInsets.all(SsrSpace.lg),
        children: [
          MonthPicker(
            month: month,
            onChanged: (m) {
              setState(() => month = m);
              _load();
            },
          ),
          const SizedBox(height: SsrSpace.md),
          Row(
            children: [
              Expanded(
                child: SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Masuk',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: SsrSpace.xs),
                      Text(
                        rp(totalIn),
                        style: SsrTheme.money.copyWith(color: SsrColors.accent),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: SsrSpace.md),
              Expanded(
                child: SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Keluar',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: SsrSpace.xs),
                      Text(
                        rp(totalOut),
                        style: SsrTheme.money.copyWith(color: SsrColors.danger),
                      ),
                    ],
                  ),
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
                  'Selisih ${monthLabel(month)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: SsrSpace.xs),
                Text(
                  rp(net),
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
              Expanded(
                child: OutlinedButton(
                  onPressed: items.isEmpty || exporting
                      ? null
                      : () => _runExport(_exportCsv, 'CSV'),
                  child: exporting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2.2),
                        )
                      : const Text('Unduh CSV'),
                ),
              ),
              const SizedBox(width: SsrSpace.sm),
              Expanded(
                child: OutlinedButton(
                  onPressed: items.isEmpty || exporting
                      ? null
                      : () => _runExport(_exportPdf, 'PDF'),
                  child: exporting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2.2),
                        )
                      : const Text('Unduh PDF'),
                ),
              ),
            ],
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
          else ...[
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
        ],
      ),
    );
  }
}
