import 'dart:io';
import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:ssr_space/core/format/money.dart';
import 'package:ssr_space/core/saas/transaction_service.dart';
import 'package:ssr_space/core/theme/app_theme.dart';
import 'package:ssr_space/models/transaction.dart';
import 'package:ssr_space/widgets/state_views.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});
  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  List<SaasTransaction> items = [];
  bool loading = true;
  String? err;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { loading = true; err = null; });
    try {
      final orgId = (await SharedPreferences.getInstance()).getString('active_org_id') ?? '';
      if (orgId.isEmpty) {
        setState(() => loading = false);
        return;
      }
      final txs = await TransactionService().list(orgId);
      if (!mounted) return;
      setState(() { items = txs; loading = false; });
    } catch (_) {
      if (!mounted) return;
      setState(() { loading = false; err = 'Gagal memuat laporan. Periksa koneksi.'; });
    }
  }

  Future<void> _exportCsv() async {
    final rows = <List<dynamic>>[
      ['tanggal', 'jenis', 'nominal', 'kategori', 'catatan'],
      for (final t in items) [t.date ?? '', t.type, t.amount, t.category ?? '', t.note ?? ''],
    ];
    final dir = await getTemporaryDirectory();
    final f = File('${dir.path}/laporan-ssr-space.csv');
    await f.writeAsString(const ListToCsvConverter().convert(rows));
    await Share.shareXFiles([XFile(f.path)], text: 'Laporan SSR SPACE (CSV)');
  }

  Future<void> _exportPdf() async {
    final doc = pw.Document();
    doc.addPage(pw.Page(
      build: (_) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('Laporan SSR SPACE', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 12),
          for (final t in items)
            pw.Text('${t.date ?? '-'} | ${t.type} | ${t.amount} | ${t.category ?? '-'} | ${t.note ?? ''}'),
        ],
      ),
    ));
    final dir = await getTemporaryDirectory();
    final f = File('${dir.path}/laporan-ssr-space.pdf');
    await f.writeAsBytes(await doc.save());
    await Share.shareXFiles([XFile(f.path)], text: 'Laporan SSR SPACE (PDF)');
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Scaffold(appBar: AppBar(title: const Text('Laporan')), body: const LoadingView(label: 'Menyusun laporan...'));
    }
    if (err != null) {
      return Scaffold(appBar: AppBar(title: const Text('Laporan')), body: ErrorView(message: err!, onRetry: _load));
    }
    final totalIn = items.where((t) => t.type == 'in').fold<double>(0, (s, t) => s + t.amount);
    final totalOut = items.where((t) => t.type == 'out').fold<double>(0, (s, t) => s + t.amount);
    return Scaffold(
      appBar: AppBar(title: const Text('Laporan')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text(rp(totalIn - totalOut), style: SsrTheme.moneyLarge),
        Text('Masuk ${rp(totalIn)}, keluar ${rp(totalOut)}', style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: ElevatedButton(onPressed: items.isEmpty ? null : _exportCsv, child: const Text('Unduh CSV'))),
          const SizedBox(width: 8),
          Expanded(child: ElevatedButton(onPressed: items.isEmpty ? null : _exportPdf, child: const Text('Unduh PDF'))),
        ]),
        const SizedBox(height: 8),
        if (items.isEmpty)
          Text('Belum ada transaksi untuk dilaporkan.', style: Theme.of(context).textTheme.bodyMedium),
        for (final t in items) ...[
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('${t.type == 'in' ? 'Masuk' : 'Keluar'}: ${rp(t.amount)}', style: SsrTheme.money),
            subtitle: Text('${t.date ?? '-'} ${t.note ?? ''}'),
          ),
          const Divider(height: 1),
        ],
      ]),
    );
  }
}
