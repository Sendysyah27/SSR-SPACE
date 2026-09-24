import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ssr_space/core/format/money.dart';
import 'package:ssr_space/core/saas/category_icons.dart';
import 'package:ssr_space/core/saas/month.dart';
import 'package:ssr_space/core/saas/transaction_service.dart';
import 'package:ssr_space/core/theme/app_theme.dart';
import 'package:ssr_space/models/transaction.dart';
import 'package:ssr_space/screens/budgets_screen.dart';
import 'package:ssr_space/screens/reports_screen.dart';
import 'package:ssr_space/screens/transactions_screen.dart';
import 'package:ssr_space/widgets/month_picker.dart';
import 'package:ssr_space/widgets/state_views.dart';

class BerandaScreen extends StatefulWidget {
  const BerandaScreen({super.key});
  @override
  State<BerandaScreen> createState() => _BerandaScreenState();
}

class _BerandaScreenState extends State<BerandaScreen> {
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

  Future<void> _load() async {
    setState(() { loading = true; err = null; });
    try {
      final prefs = await SharedPreferences.getInstance();
      final orgId = prefs.getString('active_org_id') ?? '';
      if (orgId.isEmpty) {
        setState(() { loading = false; items = []; });
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
      setState(() { loading = false; err = 'Gagal memuat beranda. Periksa koneksi.'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Beranda')),
      body: _body(),
    );
  }

  Widget _body() {
    if (loading) return const LoadingView(label: 'Memuat ringkasan...');
    if (err != null) return ErrorView(message: err!, onRetry: _load);
    final totalIn = items.where((t) => t.type == 'in').fold<double>(0, (s, t) => s + t.amount);
    final totalOut = items.where((t) => t.type == 'out').fold<double>(0, (s, t) => s + t.amount);
    final surplus = totalIn - totalOut;
    final denom = totalIn + totalOut;
    final inShare = denom <= 0 ? 0.0 : totalIn / denom;
    final pctOut = totalOut <= 0 ? null : (surplus / totalOut * 100).round();
    final groups = <String, List<SaasTransaction>>{};
    for (final t in items) {
      final d = (t.date ?? '').isEmpty ? '-' : t.date!;
      groups.putIfAbsent(d, () => []).add(t);
    }
    return ListView(padding: const EdgeInsets.all(16), children: [
      Center(child: Text(orgName, style: Theme.of(context).textTheme.bodyMedium)),
      MonthPicker(month: month, onChanged: (m) { setState(() => month = m); _load(); }),
      const SizedBox(height: 8),
      _surplusCard(totalIn, totalOut, surplus, inShare, pctOut),
      const SizedBox(height: 12),
      InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TransactionsScreen(initialMonth: month))),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text('${items.length} transaksi ${monthLabel(month).toLowerCase()}', style: TextStyle(color: Theme.of(context).colorScheme.primary)),
        ),
      ),
      Row(children: [
        Expanded(
          child: ElevatedButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TransactionsScreen())),
            child: const Text('Catat'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BudgetsScreen())),
            child: const Text('Budget'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReportsScreen())),
            child: const Text('Laporan'),
          ),
        ),
      ]),
      const SizedBox(height: 20),
      Text('Transaksi terbaru', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 8),
      if (items.isEmpty)
        Text('Belum ada transaksi bulan ini.', style: Theme.of(context).textTheme.bodyMedium),
      for (final d in groups.keys.take(7)) ...[
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 4),
          child: Text(d, style: Theme.of(context).textTheme.bodySmall),
        ),
        for (final t in groups[d]!.take(5)) _txRow(t),
      ],
    ]);
  }

  Widget _surplusCard(double totalIn, double totalOut, double surplus, double inShare, int? pctOut) {
    final positive = surplus >= 0;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: SsrColors.ink, borderRadius: BorderRadius.circular(24)),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
          child: Text(
            positive ? 'SURPLUS' : 'DEFISIT',
            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.8),
          ),
        ),
        const SizedBox(height: 8),
        Text(rp(surplus), style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w700, letterSpacing: -0.5, color: Colors.white, fontFeatures: [FontFeature.tabularFigures()])),
        Text('Selisih ${monthLabel(month).toLowerCase()}', style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13)),
        if (pctOut != null) ...[
          const SizedBox(height: 8),
          Text('${pctOut >= 0 ? '+' : ''}$pctOut% dari pengeluaran', style: const TextStyle(color: Colors.white, fontSize: 13)),
        ],
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: Text('Masuk ${rp(totalIn)}', style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 13))),
          Expanded(child: Text('Keluar ${rp(totalOut)}', textAlign: TextAlign.end, style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 13))),
        ]),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: inShare,
            minHeight: 8,
            color: SsrColors.accent,
            backgroundColor: Colors.white.withOpacity(0.15),
          ),
        ),
      ]),
    );
  }

  Widget _txRow(SaasTransaction t) {
    final isIn = t.type == 'in';
    return Column(children: [
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(color: SsrColors.accent.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
          child: Icon(iconForCategory(t.category), color: SsrColors.accent),
        ),
        title: Text(t.note?.isNotEmpty ?? false ? t.note! : (t.category ?? '-')),
        subtitle: Text('${t.code ?? '-'} | ${t.category ?? '-'}'),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: (isIn ? SsrColors.accent : SsrColors.danger).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '${isIn ? '+' : '-'}${rp(t.amount)}',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: isIn ? SsrColors.accent : SsrColors.danger,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ),
      const Divider(height: 1),
    ]);
  }
}
