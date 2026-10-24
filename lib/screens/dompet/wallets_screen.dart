import 'package:flutter/material.dart';
import 'package:ssr_space/utils/org_prefs.dart';
import 'package:ssr_space/utils/mask.dart';
import 'package:ssr_space/utils/currency.dart';
import 'package:ssr_space/utils/strings.dart';
import 'package:ssr_space/services/wallet_service.dart';
import 'package:ssr_space/services/plan_limits.dart';
import 'package:ssr_space/services/wallet_composition.dart';
import 'package:ssr_space/services/session_service.dart';
import 'package:ssr_space/services/notif_parse.dart';
import 'package:ssr_space/services/transaction_service.dart';
import 'package:ssr_space/theme/app_icons.dart';
import 'package:ssr_space/theme/app_theme.dart';
import 'package:ssr_space/theme/dribbble_tokens.dart';
import 'package:ssr_space/models/wallet.dart';
import 'package:ssr_space/models/wallet_balance.dart';
import 'package:ssr_space/screens/dompet/wallet_detail_screen.dart';
import 'package:ssr_space/widgets/drib_card.dart';
import 'package:ssr_space/widgets/premium/premium_button.dart';
import 'package:ssr_space/widgets/restyle/donut_chart.dart';
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
  final openC = TextEditingController();
  final nameFocus = FocusNode();
  String type = 'cash';
  String currency = 'IDR';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    nameC.dispose();
    openC.dispose();
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
      if (!mounted) return;
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
    String cur = 'IDR';
    for (final w in items) {
      if (w.id == walletId) { cur = w.currency; break; }
    }
    if (!balancesOk) return tr('w_notloaded');
    for (final b in balances) {
      if (b.walletId == walletId) return formatMoney(b.balance, cur);
    }
    return formatMoney(0, cur);
  }

  double? _totalBalance() {
    if (!balancesOk) return null;
    var sum = 0.0;
    for (final b in balances) {
      sum += b.balance;
    }
    return sum;
  }

  Composition? _composition() {
    if (!balancesOk) return null;
    final comp = composeComposition(
      {for (final b in balances) b.walletId: b.balance},
      {for (final w in items) w.id: w.type},
    );
    return comp.showStrip ? comp : null;
  }

  String _typeLabel(String t) {
    switch (t) {
      case 'cash':
        return tr('w_cash');
      case 'ewallet':
        return tr('w_ewallet');
      case 'bank':
        return tr('w_bank');
      case 'savings':
        return tr('w_savings');
      case 'investment':
        return tr('w_investment');
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
      final id = await WalletService().create(orgId, name, type, currency: currency);
      final opening =
          int.tryParse(openC.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
      if (opening > 0) {
        try {
          await TransactionService().add(
            orgId: orgId,
            type: 'in',
            amount: opening.toDouble(),
            walletId: id,
            category: 'Saldo awal',
            note: 'Saldo awal $name',
            date: ymd(DateTime.now()),
          );
        } catch (_) {
          try {
            await WalletService().deleteWallet(id, orgId);
          } catch (_) {}
          await _load();
          if (!mounted) return;
          setState(() => formErr = tr('w_err_save'));
          return;
        }
      }
      openC.clear();
      nameC.clear();
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(tr('w_added'))));
      }
    } on QuotaExceededException catch (e) {
      if (!mounted) return;
      await requirePro(context, e.message);
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
          illustration: 'assets/illustrations/empty_undangan.svg',
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
    final comp = _composition();
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
            onChanged: _load,
          ),
          if (comp != null) _CompositionStrip(comp: comp),
          _NewWalletForm(
            nameC: nameC,
            openC: openC,
            nameFocus: nameFocus,
            type: type,
            formErr: formErr,
            saving: saving,
            onTypeChanged: (v) => setState(() => type = v ?? 'cash'),
            onCurrencyChanged: (v) => setState(() => currency = v ?? 'IDR'),
            currency: currency,
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
      backgroundColor: DribTokens.bgOf(context),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          tr('nav_dompet'),
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
      ),
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
  final Future<void> Function() onChanged;

  const _WalletOverview({
    required this.total,
    required this.items,
    required this.typeLabelOf,
    required this.balanceTextOf,
    required this.onFocusForm,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final t = total;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (t != null)
          Container(
            margin: const EdgeInsets.only(bottom: SsrSpace.md),
            padding: const EdgeInsets.all(17),
            decoration: BoxDecoration(
              gradient: DribTokens.balanceGradient,
              borderRadius: BorderRadius.circular(24),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x800B1B3F),
                  blurRadius: 30,
                  offset: Offset(0, 16),
                  spreadRadius: -14,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr('w_total'),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFB9CBEF),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  amt(t),
                  style: DribTokens.bigNumber(
                    size: 24,
                    color: DribTokens.onNavy,
                  ),
                ),
              ],
            ),
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
            onChanged: onChanged,
          ),
      ],
    );
  }
}

/// Kartu form "Dompet baru": nama + jenis + tombol simpan.
class _NewWalletForm extends StatelessWidget {
  final TextEditingController nameC;
  final TextEditingController openC;
  final FocusNode nameFocus;
  final String type;
  final String? formErr;
  final bool saving;
  final ValueChanged<String?> onTypeChanged;
  final ValueChanged<String?> onCurrencyChanged;
  final String currency;
  final VoidCallback onSave;

  const _NewWalletForm({
    required this.nameC,
    required this.openC,
    required this.nameFocus,
    required this.type,
    required this.formErr,
    required this.saving,
    required this.onTypeChanged,
    required this.onCurrencyChanged,
    required this.currency,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return DribCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr('w_new'),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: SsrSpace.md),
          TextField(
            controller: nameC,
            focusNode: nameFocus,
            decoration: InputDecoration(labelText: tr('w_f_name')),
          ),
          const SizedBox(height: SsrSpace.md),
          _WalletTypeField(type: type, onChanged: onTypeChanged),
          const SizedBox(height: SsrSpace.md),
          _CurrencyField(currency: currency, onChanged: onCurrencyChanged),
          const SizedBox(height: SsrSpace.md),
          TextField(
            controller: openC,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: tr('w_opening')),
          ),
          if (formErr != null) ...[
            const SizedBox(height: SsrSpace.sm),
            Text(
              formErr!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ],
          const SizedBox(height: SsrSpace.lg),
          PremiumButton(
            label: tr('w_save'),
            loading: saving,
            onPressed: onSave,
            gradient: const LinearGradient(
              colors: [DribTokens.primary, DribTokens.primary],
            ),
              foreground: DribTokens.navy,
          ),
        ],
      ),
    );
  }
}

/// Dropdown jenis dompet: Kas, E-wallet, Bank, Tabungan, Investasi.
class _WalletTypeField extends StatelessWidget {
  final String type;
  final ValueChanged<String?> onChanged;

  const _WalletTypeField({required this.type, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: type,
      decoration: InputDecoration(labelText: tr('w_f_type')),
      items: [
        DropdownMenuItem(value: 'cash', child: Text(tr('w_cash'))),
        DropdownMenuItem(value: 'ewallet', child: Text(tr('w_ewallet'))),
        DropdownMenuItem(value: 'bank', child: Text(tr('w_bank'))),
        DropdownMenuItem(
          value: 'savings',
          child: Text(tr('w_savings')),
        ),
        DropdownMenuItem(
          value: 'investment',
          child: Text(tr('w_investment')),
        ),
      ],
      onChanged: onChanged,
    );
  }
}

/// Dropdown mata uang dompet.
class _CurrencyField extends StatelessWidget {
  final String currency;
  final ValueChanged<String?> onChanged;

  const _CurrencyField({required this.currency, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: currency,
      decoration: InputDecoration(labelText: tr('w_f_currency')),
      items: [
        for (final cur in supportedCurrencies)
          DropdownMenuItem(
            value: cur.code,
            child: Text('${cur.code} \u2014 ${cur.symbol.trim()}'),
          ),
      ],
      onChanged: onChanged,
    );
  }
}
/// Kartu daftar dompet: satu WalletRow per dompet, dipisah Divider.
class _WalletListCard extends StatelessWidget {
  final List<Wallet> items;
  final String Function(String type) typeLabelOf;
  final String Function(String walletId) balanceTextOf;
  final Future<void> Function() onChanged;

  const _WalletListCard({
    required this.items,
    required this.typeLabelOf,
    required this.balanceTextOf,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          DribCard(
            margin: const EdgeInsets.only(bottom: SsrSpace.md),
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 6,
            ),
            child: WalletRow(
              name: items[i].name,
              type: items[i].type,
              typeLabel: typeLabelOf(items[i].type),
              balanceText: balanceTextOf(items[i].id),
              onTap: () async {
                final r = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => WalletDetailScreen(
                      wallet: items[i],
                      balanceText: balanceTextOf(items[i].id),
                      typeLabel: typeLabelOf(items[i].type),
                    ),
                  ),
                );
                if (r == true) await onChanged();
              },
            ),
          ),
        ],
      ],
    );
  }
}

/// Strip komposisi aset: judul + donut mini + 3 baris per kelompok.
/// Pemanggil hanya merender bila comp.showStrip true.
class _CompositionStrip extends StatelessWidget {
  final Composition comp;
  const _CompositionStrip({required this.comp});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return DribCard(
      margin: const EdgeInsets.only(bottom: SsrSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr('comp_title'),
            style: text.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          Text(
            tr('comp_sub'),
            style: text.bodySmall?.copyWith(
                  color: DribTokens.textSecondary,
                ),
          ),
          const SizedBox(height: SsrSpace.md),
          _CompChart(comp: comp),
        ],
      ),
    );
  }
}

/// Donut mini + 3 baris kelompok di strip komposisi.
class _CompChart extends StatelessWidget {
  final Composition comp;
  const _CompChart({required this.comp});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 96,
          height: 64,
          child: _CompDonut(comp: comp),
        ),
        const SizedBox(width: SsrSpace.md),
        Expanded(
          child: Column(
            children: [
              _compRow(
                context,
                DribTokens.primary,
                tr('comp_liquid'),
                comp.liquid,
                comp.liquidPct,
              ),
              _compRow(
                context,
                DribTokens.accentOrange,
                tr('w_savings'),
                comp.savings,
                comp.savingsPct,
              ),
              _compRow(
                context,
                Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF8FB4F7)
                    : DribTokens.navy,
                tr('w_investment'),
                comp.investments,
                comp.investmentsPct,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Donut mini komposisi via komponen DonutChart (biru/navy/oranye).
class _CompDonut extends StatelessWidget {
  final Composition comp;
  const _CompDonut({required this.comp});

  @override
  Widget build(BuildContext context) {
    return DonutChart(
      compact: true,
      slices: [
        DonutSlice(
          value: comp.liquid,
          label: tr('comp_liquid'),
          color: DribTokens.primary,
        ),
        DonutSlice(
          value: comp.savings,
          label: tr('w_savings'),
          color: DribTokens.accentOrange,
        ),
        DonutSlice(
          value: comp.investments,
          label: tr('w_investment'),
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF8FB4F7)
              : DribTokens.navy,
        ),
      ],
    );
  }
}

Widget _compRow(
  BuildContext context,
  Color dot,
  String label,
  double value,
  double pct,
) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: SsrSpace.xs),
    child: Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: dot,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: SsrSpace.sm),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: DribTokens.textSecondary,
            ),
          ),
        ),
        Text(
          '${amt(value)} ${(pct * 100).round()}%',
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
            color: DribTokens.navy,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
      ],
    ),
  );
}
