import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ssr_space/core/format/money.dart';
import 'package:ssr_space/core/saas/category_icons.dart';
import 'package:ssr_space/core/saas/month.dart';
import 'package:ssr_space/core/saas/transaction_service.dart';
import 'package:ssr_space/core/saas/wallet_service.dart';
import 'package:ssr_space/core/theme/app_theme.dart';
import 'package:ssr_space/models/transaction.dart';
import 'package:ssr_space/models/wallet.dart';
import 'package:ssr_space/widgets/month_picker.dart';
import 'package:ssr_space/widgets/state_views.dart';

class TransactionsScreen extends StatefulWidget {
  final String? initialMonth;
  const TransactionsScreen({super.key, this.initialMonth});
  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  late String month;
  List<SaasTransaction> items = [];
  List<Wallet> wallets = [];
  bool noOrg = false;
  bool loading = true;
  bool saving = false;
  String? err;
  String? formErr;
  final amountC = TextEditingController();
  final noteC = TextEditingController();
  final catC = TextEditingController();
  String type = 'out';
  String? walletId;
  String? toWalletId;

  @override
  void initState() {
    super.initState();
    month = widget.initialMonth ?? currentMonth();
    _load();
  }

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
      final t = await TransactionService().listMonth(orgId, month);
      if (!mounted) return;
      setState(() { noOrg = false; wallets = w; items = t; loading = false; });
    } catch (_) {
      if (!mounted) return;
      setState(() { loading = false; err = 'Gagal memuat transaksi. Periksa koneksi.'; });
    }
  }

  Future<void> _save() async {
    final nominal = double.tryParse(amountC.text);
    if (nominal == null || nominal <= 0 || walletId == null) {
      setState(() => formErr = 'Isi nominal lebih dari 0 dan pilih dompet.');
      return;
    }
    if (type == 'transfer' && (toWalletId == null || toWalletId == walletId)) {
      setState(() => formErr = 'Pilih dompet tujuan yang berbeda.');
      return;
    }
    setState(() { saving = true; formErr = null; });
    try {
      final orgId = await _orgId();
      final code = await TransactionService().mintCode(orgId);
      await TransactionService().add(
        orgId: orgId, type: type, amount: nominal,
        walletId: walletId, toWalletId: toWalletId,
        category: catC.text.trim().isEmpty ? null : catC.text.trim(),
        note: noteC.text.trim(), code: code,
      );
      amountC.clear(); noteC.clear(); catC.clear();
      setState(() => walletId = null);
      await _load();
    } catch (e) {
      setState(() => formErr = 'Gagal menyimpan. Coba lagi.');
    } finally {
      if (mounted) setState(() => saving = false);
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
        MonthPicker(month: month, onChanged: (m) { setState(() => month = m); _load(); }),
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text('Belum ada transaksi ${monthLabel(month).toLowerCase()}.', style: Theme.of(context).textTheme.bodyMedium),
          ),
        for (final t in items) ...[
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: SsrColors.accent.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
              child: Icon(iconForCategory(t.category), color: SsrColors.accent),
            ),
            title: Text('${t.type == 'in' ? 'Masuk' : t.type == 'transfer' ? 'Transfer' : 'Keluar'}: ${rp(t.amount)}', style: SsrTheme.money),
            subtitle: Text('${t.code ?? '-'}${t.sourcePackage != null ? ' | Otomatis' : ''} | ${t.category ?? '-'} ${t.note?.isNotEmpty ?? false ? '| ${t.note}' : ''}'),
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
        TextField(controller: catC, decoration: const InputDecoration(labelText: 'Kategori (misal Makan)')),
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
        if (formErr != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(formErr!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        const SizedBox(height: 12),
        saving
            ? const Center(child: CircularProgressIndicator())
            : ElevatedButton(onPressed: _save, child: const Text('Simpan transaksi')),
      ]),
    );
  }
}
