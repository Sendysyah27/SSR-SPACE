import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ssr_space/core/format/money.dart';
import 'package:ssr_space/core/saas/dashboard_service.dart';
import 'package:ssr_space/core/theme/app_theme.dart';
import 'package:ssr_space/widgets/state_views.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  DashboardData? data;
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
      final orgId = (await SharedPreferences.getInstance()).getString('active_org_id') ?? '';
      if (orgId.isEmpty) {
        setState(() { loading = false; data = null; });
        return;
      }
      final d = await fetchDashboard(orgId);
      if (!mounted) return;
      setState(() { data = d; loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { loading = false; err = 'Gagal memuat dashboard. Periksa koneksi.'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Scaffold(appBar: AppBar(title: const Text('Dashboard')), body: const LoadingView(label: 'Memuat ringkasan...'));
    }
    if (err != null) {
      return Scaffold(appBar: AppBar(title: const Text('Dashboard')), body: ErrorView(message: err!, onRetry: _load));
    }
    final d = data;
    if (d == null) {
      return Scaffold(appBar: AppBar(title: const Text('Dashboard')), body: const Center(child: Text('Pilih workspace dulu')));
    }
    if (d.recent.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Dashboard')),
        body: EmptyView(
          icon: Icons.receipt_long_outlined,
          title: 'Belum ada transaksi. Catat pemasukan atau pengeluaran pertama.',
          actionLabel: 'Lihat transaksi',
          onAction: () => Navigator.pop(context),
        ),
      );
    }
    final cats = d.outByCategory.entries.toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text(rp(d.balance), style: SsrTheme.moneyLarge),
        Text(
          'Masuk ${rp(d.totalIn)}, keluar ${rp(d.totalOut)}',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 20),
        Text('Pengeluaran per kategori', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        SizedBox(
          height: 220,
          child: PieChart(PieChartData(
            centerSpaceRadius: 30,
            sectionsSpace: 2,
            sections: [
              for (var i = 0; i < cats.length; i++)
                PieChartSectionData(
                  value: cats[i].value,
                  title: cats[i].key,
                  color: Colors.primaries[i % Colors.primaries.length].shade700,
                  radius: 70,
                  titleStyle: const TextStyle(fontSize: 11, color: Colors.white),
                ),
            ],
          )),
        ),
        const SizedBox(height: 20),
        Text('Terakhir dicatat', style: Theme.of(context).textTheme.titleMedium),
        for (final t in d.recent) ...[
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('${t.type == 'in' ? 'Masuk' : 'Keluar'}: ${rp(t.amount)}', style: SsrTheme.money),
            subtitle: Text(t.note?.isNotEmpty ?? false ? t.note! : (t.category ?? '-')),
          ),
          const Divider(height: 1),
        ],
      ]),
    );
  }
}
