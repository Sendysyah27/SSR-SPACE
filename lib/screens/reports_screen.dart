import 'dart:io';
import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:ssr_space/core/saas/transaction_service.dart';
import 'package:ssr_space/models/transaction.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});
  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  List<SaasTransaction> items = [];
  String? err;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final orgId = (await SharedPreferences.getInstance()).getString('active_org_id') ?? '';
      if (orgId.isEmpty) return;
      final txs = await TransactionService().list(orgId);
      if (!mounted) return;
      setState(() => items = txs);
    } catch (e) {
      setState(() => err = e.toString().split('\n').first);
    }
  }

  Future<void> _exportCsv() async {
    final rows = <List<dynamic>>[
      ['tanggal', 'tipe', 'nominal', 'kategori', 'catatan'],
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
    final totalIn = items.where((t) => t.type == 'in').fold<double>(0, (s, t) => s + t.amount);
    final totalOut = items.where((t) => t.type == 'out').fold<double>(0, (s, t) => s + t.amount);
    return Scaffold(
      appBar: AppBar(title: const Text('Laporan')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text('Masuk: $totalIn | Keluar: $totalOut | Bersih: ${totalIn - totalOut}'),
        if (err != null) Text(err!, style: const TextStyle(color: Colors.red)),
        Row(children: [
          ElevatedButton(onPressed: _exportCsv, child: const Text('Export CSV')),
          const SizedBox(width: 8),
          ElevatedButton(onPressed: _exportPdf, child: const Text('Export PDF')),
        ]),
        const Divider(),
        for (final t in items)
          ListTile(title: Text('${t.type} - ${t.amount}'), subtitle: Text('${t.date ?? '-'} ${t.note ?? ''}')),
      ]),
    );
  }
}
