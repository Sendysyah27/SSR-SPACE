import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ssr_space/core/saas/billing_service.dart';

class BillingScreen extends StatefulWidget {
  const BillingScreen({super.key});
  @override
  State<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends State<BillingScreen> {
  String plan = 'free';
  String? msg;

  @override
  void initState() { super.initState(); _load(); }

  Future<String> _orgId() async => (await SharedPreferences.getInstance()).getString('active_org_id') ?? '';

  Future<void> _load() async {
    final orgId = await _orgId();
    if (orgId.isEmpty) return;
    setState(() => plan = '...');
    final p = await currentPlan(orgId);
    if (!mounted) return;
    setState(() => plan = p);
  }

  Future<void> _upgrade() async {
    await requestUpgrade(await _orgId(), 'pro', proPrice);
    if (!mounted) return;
    setState(() => msg = 'Permintaan Pro tercatat (pending). Aktivasi otomatis menyusul setelah payment gateway live.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Billing')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text('Paket aktif: $plan', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const ListTile(title: Text('Free'), subtitle: Text('Rp0 — catat + 1 workspace')),
        const ListTile(title: Text('Pro'), subtitle: Text('Rp25.000/bln — multi workspace + export + prioritas')),
        if (msg != null) Text(msg!, style: const TextStyle(color: Colors.green)),
        ElevatedButton(onPressed: plan == 'pro' ? null : _upgrade, child: const Text('Upgrade ke Pro')),
      ]),
    );
  }
}
