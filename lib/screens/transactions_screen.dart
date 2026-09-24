import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ssr_space/core/format/money.dart';
import 'package:ssr_space/core/saas/transaction_service.dart';
import 'package:ssr_space/core/saas/wallet_service.dart';
import 'package:ssr_space/core/theme/app_theme.dart';
import 'package:ssr_space/models/transaction.dart';
import 'package:ssr_space/models/wallet.dart';
import 'package:ssr_space/widgets/state_views.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});
  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  List<SaasTransaction> items = [];
  List<Wallet> wallets = [];
  bool noOrg = false;
  bool loading = true;
  String? err;
  final amountC = TextEditingController();
  final noteC = TextEditingController();
  String type = 'out';
  String? walletId;
  String? toWalletId;

  @override
  void initState() { super.initState(); _load(); }

  Future<String> _orgId() async => (await SharedPreferences.getInstance()).getString('active_org_id') ?? '';

  Future<void> _load() async {
    setState(() { loading = true; err = null; });
    try {
      final orgId = await _orgId();
      if (orgId.isEmpty) {
        setState(() { noOrg = true; loading = false; });
        return;
      }
      final w = await WalletService().list(orgId);
      final t = await TransactionService().list(orgId);
      if (!mounted) return;
      setState(() { noOrg = false; wallets = w; items = t; loading = false; });
    } catch (_) {
      if (!mounted) return;
      setState(() { loading = false; err = 'Gagal memuat transaksi. Periksa koneksi.'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (noOrg) {
      return Scaffold(
        appBar: AppBar(title: const Text('Transaksi')),
        body: const Center(child: Text('Pilih atau buat workspace dulu')),
      );
    }
    if (loading) {
      return Scaffold(appBar: AppBar(title: const Text('Transaksi')), body: const LoadingView(label: 'Memuat transaksi...'));
    }
    if (err != null) {
      return Scaffold(appBar: AppBar(title: const Text('Transaksi')), body: ErrorView(message: err!, onRetry: _load));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Transaksi')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text('Belum ada transaksi bulan ini.', style: Theme.of(context).textTheme.bodyMedium),
          ),
        for (final t in items) ...[
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('${t.type == 'in' ? 'Masuk' : t.type == 'transfer' ? 'Transfer' : 'Keluar'}: ${rp(t.amount)}', style: SsrTheme.money),
            subtitle: Text(t.note?.isNotEmpty ?? false ? t.note! : (t.category ?? '-')),
          ),
          const Divider(height: 1),
        ],
        const SizedBox(height: 16),
        Text('Catat transaksi', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: type,
          decoration: const InputDecoration(labelText: 'Jenis'),
          items: const [
            DropdownMenuItem(value: 'in', child: Text('Pemasukan')),
            DropdownMenuItem(value: 'out', child: Text('Pengeluaran')),
            DropdownMenuItem(value: 'transfer', child: Text('Transfer antar dompet')),
          ],
          onChanged: (v) => setState(() => type = v ?? 'out'),
        ),
        const SizedBox(height: 8),
        TextField(controller: amountC, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Nominal (Rp)', prefixText: 'Rp ')),
        const SizedBox(height: 8),
        TextField(controller: noteC, decoration: const InputDecoration(labelText: 'Catatan')),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: walletId,
          decoration: const InputDecoration(labelText: 'Dompet'),
          items: [for (final w in wallets) DropdownMenuItem(value: w.id, child: Text(w.name))],
          onChanged: (v) => setState(() => walletId = v),
        ),
        if (type == 'transfer') ...[
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: toWalletId,
            decoration: const InputDecoration(labelText: 'Dompet tujuan'),
            items: [for (final w in wallets) DropdownMenuItem(value: w.id, child: Text(w.name))],
            onChanged: (v) => setState(() => toWalletId = v),
          ),
        ],
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: () async {
            final nominal = double.tryParse(amountC.text);
            if (nominal == null || nominal <= 0 || walletId == null) return;
            final orgId = await _orgId();
            await TransactionService().add(
              orgId: orgId, type: type, amount: nominal,
              walletId: walletId, toWalletId: toWalletId, note: noteC.text.trim(),
            );
            amountC.clear(); noteC.clear();
            await _load();
          },
          child: const Text('Simpan transaksi'),
        ),
      ]),
    );
  }
}
