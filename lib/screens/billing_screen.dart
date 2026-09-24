import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ssr_space/core/format/money.dart';
import 'package:ssr_space/core/saas/billing_service.dart';
import 'package:ssr_space/widgets/state_views.dart';

class BillingScreen extends StatefulWidget {
  const BillingScreen({super.key});
  @override
  State<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends State<BillingScreen> {
  String plan = '';
  bool loading = true;
  String? msg;

  @override
  void initState() { super.initState(); _load(); }

  Future<String> _orgId() async => (await SharedPreferences.getInstance()).getString('active_org_id') ?? '';

  Future<void> _load() async {
    final orgId = await _orgId();
    if (orgId.isEmpty) {
      setState(() => loading = false);
      return;
    }
    final p = await currentPlan(orgId);
    if (!mounted) return;
    setState(() { plan = p; loading = false; });
  }

  Future<void> _upgrade() async {
    await requestUpgrade(await _orgId(), 'pro', proPrice);
    if (!mounted) return;
    setState(() => msg = 'Permintaan Pro tercatat. Aktivasi menyusul setelah pembayaran terkonfirmasi.');
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Scaffold(appBar: AppBar(title: const Text('Billing')), body: const LoadingView(label: 'Memuat paket...'));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Billing')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text('Paket aktif: ${plan.isEmpty ? '-' : plan}', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        const ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text('Gratis'),
          subtitle: Text('Rp0. Catat transaksi dan 1 workspace.'),
        ),
        const Divider(height: 1),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Pro'),
          subtitle: Text('${rp(proPrice)}/bulan. Workspace banyak, export laporan, tanpa batas.'),
        ),
        const Divider(height: 1),
        if (msg != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(msg!, style: TextStyle(color: Theme.of(context).colorScheme.primary)),
          ),
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: plan == 'pro' ? null : _upgrade,
          child: const Text('Naik ke Pro'),
        ),
      ]),
    );
  }
}
