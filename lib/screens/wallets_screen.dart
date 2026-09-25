import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ssr_space/core/format/money.dart';
import 'package:ssr_space/core/saas/wallet_service.dart';
import 'package:ssr_space/core/session/session_service.dart';
import 'package:ssr_space/core/theme/app_theme.dart';
import 'package:ssr_space/models/wallet.dart';
import 'package:ssr_space/models/wallet_balance.dart';
import 'package:ssr_space/widgets/primary_button.dart';
import 'package:ssr_space/widgets/section_card.dart';
import 'package:ssr_space/widgets/state_views.dart';
import 'package:ssr_space/widgets/status_chip.dart';

class WalletsScreen extends StatefulWidget {
  final SessionService? session;
  const WalletsScreen({super.key, this.session});
  @override
  State<WalletsScreen> createState() => _WalletsScreenState();
}

class _WalletsScreenState extends State<WalletsScreen> {
  List<Wallet> items = [];
  List<WalletBalance> balances = [];
  bool balancesOk = false;
  bool noOrg = false;
  bool loading = true;
  bool saving = false;
  String? err;
  String? formErr;
  final nameC = TextEditingController();
  final nameFocus = FocusNode();
  String type = 'cash';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    nameC.dispose();
    nameFocus.dispose();
    super.dispose();
  }

  Future<String> _orgId() async =>
      (await SharedPreferences.getInstance()).getString('active_org_id') ?? '';

  Future<void> _load() async {
    setState(() {
      loading = true;
      err = null;
    });
    try {
      final orgId = await _orgId();
      if (orgId.isEmpty) {
        setState(() {
          noOrg = true;
          loading = false;
        });
        return;
      }
      final data = await WalletService().list(orgId);
      List<WalletBalance> bals = [];
      var bOk = false;
      try {
        bals = await WalletService().balances(orgId);
        bOk = true;
      } catch (_) {
        bals = [];
        bOk = false;
      }
      if (!mounted) return;
      setState(() {
        noOrg = false;
        items = data;
        balances = bals;
        balancesOk = bOk;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString();
      final short = msg.contains('recursion')
          ? 'Gagal memuat dompet: RLS recursion. Jalankan migration_08 di Supabase.'
          : msg.contains('permission')
          ? 'Gagal memuat dompet: izin RLS. Cek membership workspace.'
          : 'Gagal memuat dompet. Periksa koneksi.';
      setState(() {
        loading = false;
        err = short;
      });
    }
  }

  String _balanceLabel(String walletId) {
    if (!balancesOk) return 'Belum termuat';
    for (final b in balances) {
      if (b.walletId == walletId) return rp(b.balance);
    }
    return rp(0);
  }

  double? _totalBalance() {
    if (!balancesOk) return null;
    var sum = 0.0;
    for (final b in balances) {
      sum += b.balance;
    }
    return sum;
  }

  String _typeLabel(String t) {
    switch (t) {
      case 'cash':
        return 'Tunai';
      case 'ewallet':
        return 'E-wallet';
      case 'bank':
        return 'Bank';
      default:
        return t;
    }
  }

  Future<void> _save() async {
    final name = nameC.text.trim();
    if (name.isEmpty) {
      setState(() => formErr = 'Isi nama dompet dulu.');
      return;
    }
    setState(() {
      formErr = null;
      saving = true;
    });
    try {
      final orgId = await _orgId();
      await WalletService().create(orgId, name, type);
      nameC.clear();
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Dompet ditambahkan.')));
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => formErr = 'Gagal menyimpan. Periksa koneksi.');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  void _focusForm() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      nameFocus.requestFocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (noOrg) {
      return Scaffold(
        appBar: AppBar(title: const Text('Dompet')),
        body: EmptyView(
          icon: Icons.account_balance_wallet_outlined,
          title: 'Pilih atau buat workspace dulu.',
          subtitle: 'Dompet selalu menempel pada satu workspace.',
          actionLabel: 'Muat ulang',
          onAction: _load,
        ),
      );
    }
    if (loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Dompet')),
        body: const LoadingView(label: 'Memuat dompet...'),
      );
    }
    if (err != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Dompet')),
        body: ErrorView(message: err!, onRetry: _load),
      );
    }
    final total = items.isEmpty ? null : _totalBalance();
    return Scaffold(
      appBar: AppBar(title: const Text('Dompet')),
      body: ListView(
        padding: const EdgeInsets.all(SsrSpace.lg),
        children: [
          if (total != null)
            SectionCard(
              margin: const EdgeInsets.only(bottom: SsrSpace.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total aset',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: SsrSpace.xs),
                  Text(rp(total), style: SsrTheme.moneyLarge),
                ],
              ),
            ),
          if (items.isEmpty)
            EmptyView(
              icon: Icons.account_balance_wallet_outlined,
              title: 'Belum ada dompet.',
              subtitle: 'Tambah dompet pertama lewat form di bawah.',
              actionLabel: 'Isi dompet',
              onAction: _focusForm,
            )
          else
            SectionCard(
              margin: const EdgeInsets.only(bottom: SsrSpace.md),
              padding: const EdgeInsets.symmetric(
                horizontal: SsrSpace.md,
                vertical: SsrSpace.xs,
              ),
              child: Column(
                children: [
                  for (var i = 0; i < items.length; i++) ...[
                    if (i > 0) const Divider(height: 1),
                    _walletRow(items[i]),
                  ],
                ],
              ),
            ),
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Dompet baru',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: SsrSpace.md),
                TextField(
                  controller: nameC,
                  focusNode: nameFocus,
                  decoration: const InputDecoration(
                    labelText: 'Nama dompet (Kas, Dana, Bank)',
                  ),
                ),
                const SizedBox(height: SsrSpace.md),
                DropdownButtonFormField<String>(
                  initialValue: type,
                  decoration: const InputDecoration(labelText: 'Jenis'),
                  items: const [
                    DropdownMenuItem(value: 'cash', child: Text('Tunai')),
                    DropdownMenuItem(value: 'ewallet', child: Text('E-wallet')),
                    DropdownMenuItem(value: 'bank', child: Text('Bank')),
                  ],
                  onChanged: (v) => setState(() => type = v ?? 'cash'),
                ),
                if (formErr != null) ...[
                  const SizedBox(height: SsrSpace.sm),
                  Text(
                    formErr!,
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: SsrColors.danger),
                  ),
                ],
                const SizedBox(height: SsrSpace.lg),
                PrimaryButton(
                  label: 'Simpan dompet',
                  loading: saving,
                  onPressed: _save,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _walletRow(Wallet w) {
    final balance = _balanceLabel(w.id);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: SsrSpace.sm),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: SsrColors.accentSoft,
              borderRadius: BorderRadius.circular(SsrRadius.tile),
            ),
            child: const Icon(
              Icons.account_balance_wallet_outlined,
              color: SsrColors.accent,
              size: 22,
            ),
          ),
          const SizedBox(width: SsrSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(w.name, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 2),
                StatusChip(label: _typeLabel(w.type)),
              ],
            ),
          ),
          const SizedBox(width: SsrSpace.sm),
          Flexible(
            child: Text(
              balance,
              textAlign: TextAlign.end,
              style: balance == 'Belum termuat'
                  ? Theme.of(context).textTheme.bodySmall
                  : SsrTheme.money.copyWith(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
