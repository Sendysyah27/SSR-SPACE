import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ssr_space/core/format/money.dart';
import 'package:ssr_space/core/saas/category_icons.dart';
import 'package:ssr_space/core/saas/month.dart';
import 'package:ssr_space/core/saas/transaction_service.dart';
import 'package:ssr_space/core/saas/tx_validation.dart';
import 'package:ssr_space/core/saas/wallet_service.dart';
import 'package:ssr_space/core/theme/app_theme.dart';
import 'package:ssr_space/models/transaction.dart';
import 'package:ssr_space/models/wallet.dart';
import 'package:ssr_space/models/wallet_balance.dart';
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
  List<WalletBalance> balances = [];
  SaasTransaction? editing;
  DateTime? editDate;
  final formKey = GlobalKey();
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
      List<WalletBalance> bals = [];
      try {
        bals = await WalletService().balances(orgId);
      } catch (_) {
        bals = [];
      }
      final t = await TransactionService().listMonth(orgId, month);
      if (!mounted) return;
      setState(() {
        noOrg = false;
        wallets = w;
        balances = bals;
        items = t;
        loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() { loading = false; err = 'Gagal memuat transaksi. Periksa koneksi.'; });
    }
  }

  double? _balanceOf(String? id) {
    if (id == null) return null;
    for (final b in balances) {
      if (b.walletId == id) return b.balance;
    }
    return null;
  }

  void _startEdit(SaasTransaction t) {
    setState(() {
      editing = t;
      type = t.type;
      amountC.text = t.amount.toStringAsFixed(0);
      catC.text = t.category ?? '';
      noteC.text = t.note ?? '';
      walletId = t.walletId;
      toWalletId = t.toWalletId;
      editDate = t.date == null ? null : DateTime.tryParse(t.date!);
      formErr = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = formKey.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(ctx, duration: Duration.zero);
      }
    });
  }

  void _cancelEdit() {
    setState(() {
      editing = null;
      editDate = null;
      type = 'out';
      amountC.clear();
      noteC.clear();
      catC.clear();
      walletId = null;
      toWalletId = null;
      formErr = null;
    });
  }

  String _ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  Future<void> _save() async {
    final nominal = double.tryParse(amountC.text);
    if (nominal == null) {
      setState(() => formErr = 'Isi nominal dengan angka yang benar.');
      return;
    }
    final v = validateTxInput(
      amount: nominal,
      walletId: walletId,
      type: type,
      toWalletId: toWalletId,
    );
    if (v != null) {
      setState(() => formErr = v);
      return;
    }
    setState(() { saving = true; formErr = null; });
    try {
      final orgId = await _orgId();
      final cat = catC.text.trim().isEmpty ? null : catC.text.trim();
      final note = noteC.text.trim();
      final svc = TransactionService();
      if (editing != null) {
        await svc.update(
          id: editing!.id,
          orgId: orgId,
          type: type,
          amount: nominal,
          walletId: walletId,
          toWalletId: type == 'transfer' ? toWalletId : null,
          category: cat,
          note: note.isEmpty ? null : note,
          date: editDate == null ? editing!.date : _ymd(editDate!),
        );
        if (!mounted) return;
        _cancelEdit();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Transaksi diperbarui')),
        );
      } else {
        await svc.add(
          orgId: orgId,
          type: type,
          amount: nominal,
          walletId: walletId,
          toWalletId: type == 'transfer' ? toWalletId : null,
          category: cat,
          note: note,
        );
        if (!mounted) return;
        amountC.clear();
        noteC.clear();
        catC.clear();
        setState(() {
          walletId = null;
          toWalletId = null;
        });
      }
      await _load();
    } catch (_) {
      if (!mounted) return;
      setState(() => formErr = 'Gagal menyimpan. Coba lagi.');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> _confirmDelete() async {
    if (editing == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus transaksi'),
        content: const Text('Hapus transaksi ini? Tidak bisa dibatalkan.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted || editing == null) return;
    try {
      final orgId = await _orgId();
      await TransactionService().delete(editing!.id, orgId);
      if (!mounted) return;
      _cancelEdit();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Transaksi dihapus')),
      );
      await _load();
    } catch (_) {
      if (!mounted) return;
      setState(() => formErr = 'Gagal menghapus. Coba lagi.');
    }
  }

  DropdownMenuItem<String> _walletItem(Wallet w, ThemeData theme) {
    final bal = _balanceOf(w.id);
    return DropdownMenuItem(
      value: w.id,
      child: Text(
        bal == null ? w.name : '${w.name} · ${rp(bal)}',
        style: bal == null
            ? null
            : theme.textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF5F5E5B),
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
      ),
    );
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
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Transaksi')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        MonthPicker(month: month, onChanged: (m) { setState(() => month = m); _load(); }),
        Text(
          editing != null ? 'Mengubah transaksi' : 'Catat transaksi',
          style: theme.textTheme.titleMedium,
        ),
        if (editing != null) ...[
          const SizedBox(height: 8),
          Container(
            key: formKey,
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: SsrColors.accent.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Mengubah ${editing!.code ?? 'transaksi'}',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
                TextButton(
                  onPressed: _cancelEdit,
                  child: const Text('Batalkan edit'),
                ),
              ],
            ),
          ),
        ],
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
          items: [for (final w in wallets) _walletItem(w, theme)],
          onChanged: (v) => setState(() => walletId = v),
        ),
        if (type == 'transfer') ...[
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: toWalletId,
            decoration: const InputDecoration(labelText: 'Dompet tujuan'),
            items: [for (final w in wallets) _walletItem(w, theme)],
            onChanged: (v) => setState(() => toWalletId = v),
          ),
        ],
        if (formErr != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(formErr!, style: TextStyle(color: theme.colorScheme.error)),
          ),
        const SizedBox(height: 12),
        if (saving)
          const Center(child: CircularProgressIndicator())
        else ...[
          ElevatedButton(
            onPressed: _save,
            child: Text(editing != null ? 'Simpan perubahan' : 'Simpan transaksi'),
          ),
          if (editing != null) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton(
                onPressed: _confirmDelete,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFB3261E),
                  side: const BorderSide(color: Color(0xFFB3261E)),
                ),
                child: const Text('Hapus'),
              ),
            ),
          ],
        ],
        const SizedBox(height: 16),
        const Divider(),
        Text('Riwayat ${monthLabel(month).toLowerCase()}', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Belum ada transaksi bulan ini. Catat pemasukan atau pengeluaran di form di atas.',
              style: theme.textTheme.bodyMedium,
            ),
          ),
        for (final t in items) ...[
          ListTile(
            selected: editing?.id == t.id,
            onTap: () => _startEdit(t),
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
      ]),
    );
  }
}
