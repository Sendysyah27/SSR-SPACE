import 'package:flutter/material.dart';
import 'package:ssr_space/utils/org_prefs.dart';
import 'package:ssr_space/utils/mask.dart';
import 'package:ssr_space/utils/strings.dart';
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
          ? tr('w_err_recursion')
          : msg.contains('permission')
          ? tr('w_err_perm')
          : tr('w_err_load');
      setState(() {
        loading = false;
        err = short;
      });
    }
  }

  String _balanceLabel(String walletId) {
    if (!balancesOk) return tr('w_notloaded');
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
        return tr('w_cash');
      case 'ewallet':
        return tr('w_ewallet');
      case 'bank':
        return tr('w_bank');
      default:
        return t;
    }
  }

  Future<void> _save() async {
    final name = nameC.text.trim();
    if (name.isEmpty) {
      setState(() => formErr = tr('w_err_name'));
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
            .showSnackBar(SnackBar(content: Text(tr('w_added'))));
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => formErr = tr('w_err_save'));
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
          title: tr('w_noorg_t'),
          subtitle: tr('w_noorg_s'),
          actionLabel: tr('reload'),
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
      appBar: AppBar(title: Text(tr('nav_dompet'))),
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
            label: tr('w_total'),
            children: [Text(amt(t), style: SsrTheme.moneyLarge)],
          ),
        if (items.isEmpty)
          EmptyView(
            icon: AppIcons.wallet,
            illustration: 'assets/illustrations/empty_dompet.svg',
            title: tr('w_empty_t'),
            subtitle: tr('w_empty_s'),
            actionLabel: tr('w_empty_a'),
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
          Text(tr('w_new'), style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: SsrSpace.md),
          TextField(
            controller: nameC,
            focusNode: nameFocus,
            decoration: const InputDecoration(labelText: tr('w_f_name')),
          ),
          const SizedBox(height: SsrSpace.md),
          DropdownButtonFormField<String>(
            initialValue: type,
            decoration: InputDecoration(labelText: tr('w_f_type')),
            items: const [
              DropdownMenuItem(value: 'cash', child: Text(tr('w_cash'))),
              DropdownMenuItem(value: 'ewallet', child: Text(tr('w_ewallet'))),
              DropdownMenuItem(value: 'bank', child: Text(tr('w_bank'))),
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
            label: tr('w_save'),
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
