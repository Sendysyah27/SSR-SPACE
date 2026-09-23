import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ssr_space/core/saas/wallet_service.dart';
import 'package:ssr_space/core/session/session_service.dart';
import 'package:ssr_space/models/wallet.dart';
import 'package:ssr_space/screens/org_switcher_screen.dart';

class WalletsScreen extends StatefulWidget {
  final SessionService? session;
  const WalletsScreen({super.key, this.session});
  @override
  State<WalletsScreen> createState() => _WalletsScreenState();
}

class _WalletsScreenState extends State<WalletsScreen> {
  List<Wallet> items = [];
  bool noOrg = false;
  final nameC = TextEditingController();
  String type = 'cash';

  @override
  void initState() { super.initState(); _load(); }

  Future<String> _orgId() async => (await SharedPreferences.getInstance()).getString('active_org_id') ?? '';

  Future<void> _load() async {
    final orgId = await _orgId();
    if (orgId.isEmpty) {
      setState(() => noOrg = true);
      return;
    }
    setState(() { noOrg = false; items = []; });
    final data = await WalletService().list(orgId);
    setState(() => items = data);
  }

  @override
  Widget build(BuildContext context) {
    if (noOrg) {
      return Scaffold(
        appBar: AppBar(title: const Text('Dompet')),
        body: const Center(child: Text('Pilih / buat workspace dulu')),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Dompet')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        for (final w in items) ListTile(title: Text(w.name), subtitle: Text(w.type)),
        const Divider(),
        TextField(controller: nameC, decoration: const InputDecoration(labelText: 'Nama dompet (Cash/Dana/Bank)')),
        DropdownButton<String>(
          value: type,
          items: const [DropdownMenuItem(value: 'cash', child: Text('cash')), DropdownMenuItem(value: 'ewallet', child: Text('ewallet')), DropdownMenuItem(value: 'bank', child: Text('bank'))],
          onChanged: (v) => setState(() => type = v ?? 'cash'),
        ),
        ElevatedButton(
          onPressed: () async {
            final orgId = await _orgId();
            await WalletService().create(orgId, nameC.text, type);
            nameC.clear();
            await _load();
          },
          child: const Text('Tambah dompet'),
        ),
      ]),
    );
  }
}
