import 'package:flutter/material.dart';
import 'package:ssr_space/utils/org_prefs.dart';
import 'package:ssr_space/utils/mask.dart';
import 'package:ssr_space/services/wallet_service.dart';
import 'package:ssr_space/services/session_service.dart';
import 'package:ssr_space/theme/app_icons.dart';
import 'package:ssr_space/theme/app_theme.dart';
import 'package:ssr_space/models/wallet.dart';
import 'package:ssr_space/models/wallet_balance.dart';
import 'package:ssr_space/screens/dompet/wallet_detail_screen.dart';
import 'package:ssr_space/widgets/labeled_section_card.dart';
import 'package:ssr_space/widgets/primary_button.dart';
import 'package:ssr_space/widgets/section_card.dart';
import 'package:ssr_space/widgets/skeletons.dart';
import 'package:ssr_space/widgets/state_views.dart';
import 'package:ssr_space/widgets/wallet_row.dart';

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

  Future<void> _load() async {
    setState(() {
      loading = true;
      err = null;
    });
    try {
      final orgId = await activeOrgId();
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
      if (b.walletId == walletId) return amt(b.balance);
    }
    return amt(0);
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
      final orgId = await activeOrgId();
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
      return _WalletsScaffold(
        EmptyView(
          icon: AppIcons.workspace,
          title: 'Pilih atau buat workspace dulu.',
          subtitle: 'Dompet selalu menempel pada satu workspace.',
          actionLabel: 'Muat ulang',
          onAction: _load,
        ),
      );
    }
    if (loading) {
      return const _WalletsScaffold(WalletListSkeleton());
    }
    if (err != null) {
      return _WalletsScaffold(ErrorView(message: err!, onRetry: _load));
    }
    return _WalletsScaffold(
      ListView(
        padding: const EdgeInsets.all(SsrSpace.lg),
        children: [
          _WalletOverview(
            total: items.isEmpty ? null : _totalBalance(),
            items: items,
            typeLabelOf: _typeLabel,
            balanceTextOf: _balanceLabel,
            onFocusForm: _focusForm,
          ),
          _NewWalletForm(
            nameC: nameC,
            nameFocus: nameFocus,
            type: type,
            formErr: formErr,
            saving: saving,
            onTypeChanged: (v) => setState(() => type = v ?? 'cash'),
            onSave: _save,
          ),
        ],
      ),
    );
  }
}

/// Kerangka layar Dompet: AppBar "Dompet" + body (state / daftar).
class _WalletsScaffold extends StatelessWidget {
  final Widget body;
  const _WalletsScaffold(this.body);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dompet')),
      body: body,
    );
  }
}

/// Total aset + daftar dompet (atau EmptyView bila belum ada).
class _WalletOverview extends StatelessWidget {
  final double? total;
  final List<Wallet> items;
  final String Function(String type) typeLabelOf;
  final String Function(String walletId) balanceTextOf;
  final VoidCallback onFocusForm;

  const _WalletOverview({
    required this.total,
    required this.items,
    required this.typeLabelOf,
    required this.balanceTextOf,
    required this.onFocusForm,
  });

  @override
  Widget build(BuildContext context) {
    final t = total;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (t != null)
          LabeledSectionCard(
            margin: const EdgeInsets.only(bottom: SsrSpace.md),
            label: 'Total aset',
            children: [Text(amt(t), style: SsrTheme.moneyLarge)],
          ),
        if (items.isEmpty)
          EmptyView(
            icon: AppIcons.wallet,
            illustration: 'assets/illustrations/empty_dompet.svg',
            title: 'Belum ada dompet.',
            subtitle: 'Tambah dompet pertama lewat form di bawah.',
            actionLabel: 'Isi dompet',
            onAction: onFocusForm,
          )
        else
          _WalletListCard(
            items: items,
            typeLabelOf: typeLabelOf,
            balanceTextOf: balanceTextOf,
          ),
      ],
    );
  }
}

/// Kartu form "Dompet baru": nama + jenis + tombol simpan.
class _NewWalletForm extends StatelessWidget {
  final TextEditingController nameC;
  final FocusNode nameFocus;
  final String type;
  final String? formErr;
  final bool saving;
  final ValueChanged<String?> onTypeChanged;
  final VoidCallback onSave;

  const _NewWalletForm({
    required this.nameC,
    required this.nameFocus,
    required this.type,
    required this.formErr,
    required this.saving,
    required this.onTypeChanged,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Dompet baru', style: Theme.of(context).textTheme.titleMedium),
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
            onChanged: onTypeChanged,
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
            onPressed: onSave,
          ),
        ],
      ),
    );
  }
}

/// Kartu daftar dompet: satu WalletRow per dompet, dipisah Divider.
class _WalletListCard extends StatelessWidget {
  final List<Wallet> items;
  final String Function(String type) typeLabelOf;
  final String Function(String walletId) balanceTextOf;

  const _WalletListCard({
    required this.items,
    required this.typeLabelOf,
    required this.balanceTextOf,
  });

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      margin: const EdgeInsets.only(bottom: SsrSpace.md),
      padding: const EdgeInsets.symmetric(
        horizontal: SsrSpace.md,
        vertical: SsrSpace.xs,
      ),
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            WalletRow(
              name: items[i].name,
              type: items[i].type,
              typeLabel: typeLabelOf(items[i].type),
              balanceText: balanceTextOf(items[i].id),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => WalletDetailScreen(
                    wallet: items[i],
                    balanceText: balanceTextOf(items[i].id),
                    typeLabel: typeLabelOf(items[i].type),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
