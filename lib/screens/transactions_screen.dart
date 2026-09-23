import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ssr_space/core/saas/transaction_service.dart';
import 'package:ssr_space/core/saas/wallet_service.dart';
import 'package:ssr_space/models/transaction.dart';
import 'package:ssr_space/models/wallet.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});
  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  List<SaasTransaction> items = [];
  List<Wallet> wallets = [];
  final amountC = TextEditingController();
  final noteC = TextEditingController();
  String type = 'out';
  String? walletId;
  String? toWalletId;

  @override
  void initState() { super.initState(); _load(); }

  Future<String> _orgId() async => (await SharedPreferences.getInstance()).getString('active_org_id') ?? '';

  Future<void> _load() async {
    final orgId = await _orgId();
    if (orgId.isEmpty) return;
    wallets = await WalletService().list(orgId);
    items = await TransactionService().list(orgId);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Transaksi')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        for (final t in items)
          ListTile(title: Text('${t.type} - ${t.amount}'), subtitle: Text(t.note ?? '')),
        const Divider(),
        DropdownButton<String>(
          value: type,
          items: const [DropdownMenuItem(value: 'in', child: Text('Pemasukan')), DropdownMenuItem(value: 'out', child: Text('Pengeluaran')), DropdownMenuItem(value: 'transfer', child: Text('Transfer'))],
          onChanged: (v) => setState(() => type = v ?? 'out'),
        ),
        TextField(controller: amountC, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Nominal')),
        TextField(controller: noteC, decoration: const InputDecoration(labelText: 'Catatan')),
        DropdownButton<String>(
          value: walletId,
          hint: const Text('Dompet'),
          items: [for (final w in wallets) DropdownMenuItem(value: w.id, child: Text(w.name))],
          onChanged: (v) => setState(() => walletId = v),
        ),
        if (type == 'transfer')
          DropdownButton<String>(
            value: toWalletId,
            hint: const Text('Ke dompet'),
            items: [for (final w in wallets) DropdownMenuItem(value: w.id, child: Text(w.name))],
            onChanged: (v) => setState(() => toWalletId = v),
          ),
        ElevatedButton(
          onPressed: () async {
            final orgId = await _orgId();
            await TransactionService().add(
              orgId: orgId, type: type, amount: double.parse(amountC.text),
              walletId: walletId, toWalletId: toWalletId, note: noteC.text,
            );
            amountC.clear(); noteC.clear();
            await _load();
          },
          child: const Text('Simpan'),
        ),
      ]),
    );
  }
}
