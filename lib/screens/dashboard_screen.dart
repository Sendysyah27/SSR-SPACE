import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ssr_space/core/saas/dashboard_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  DashboardData? data;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final orgId = (await SharedPreferences.getInstance()).getString('active_org_id') ?? '';
    if (orgId.isEmpty) {
      setState(() => loading = false);
      return;
    }
    final d = await fetchDashboard(orgId);
    if (!mounted) return;
    setState(() { data = d; loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Scaffold(appBar: AppBar(title: const Text('Dashboard')), body: const Center(child: CircularProgressIndicator()));
    }
    final d = data;
    if (d == null) {
      return Scaffold(appBar: AppBar(title: const Text('Dashboard')), body: const Center(child: Text('Pilih workspace dulu')));
    }
    final cats = d.outByCategory.entries.toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text('Saldo: ${d.balance.toStringAsFixed(0)}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        Text('Masuk: ${d.totalIn.toStringAsFixed(0)} | Keluar: ${d.totalOut.toStringAsFixed(0)}'),
        const SizedBox(height: 16),
        const Text('Pengeluaran per kategori'),
        if (cats.isEmpty)
          const Text('Belum ada pengeluaran')
        else
          SizedBox(
            height: 220,
            child: PieChart(PieChartData(
              centerSpaceRadius: 30,
              sections: [
                for (var i = 0; i < cats.length; i++)
                  PieChartSectionData(
                    value: cats[i].value,
                    title: cats[i].key,
                    color: Colors.primaries[i % Colors.primaries.length],
                    radius: 70,
                    titleStyle: const TextStyle(fontSize: 11, color: Colors.white),
                  ),
              ],
            )),
          ),
        const SizedBox(height: 16),
        const Text('Terakhir'),
        for (final t in d.recent)
          ListTile(title: Text('${t.type} - ${t.amount}'), subtitle: Text(t.note ?? '')),
      ]),
    );
  }
}
