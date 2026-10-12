import 'package:flutter/material.dart';
import 'package:ssr_space/utils/mask.dart';
import 'package:ssr_space/utils/org_prefs.dart';
import 'package:ssr_space/utils/strings.dart';
import 'package:ssr_space/models/transaction.dart';
import 'package:ssr_space/models/wallet.dart';
import 'package:ssr_space/services/transaction_service.dart';
import 'package:ssr_space/services/saving.dart';
import 'package:ssr_space/services/wallet_edit_logic.dart';
import 'package:ssr_space/services/wallet_service.dart';
import 'package:ssr_space/theme/app_icons.dart';
import 'package:ssr_space/theme/app_theme.dart';
import 'package:ssr_space/widgets/pin_dialog.dart';
import 'package:ssr_space/widgets/section_card.dart';
import 'package:ssr_space/widgets/state_views.dart';
import 'package:ssr_space/widgets/status_chip.dart';
import 'package:ssr_space/widgets/tx_day_slivers.dart';
import 'package:ssr_space/widgets/tx_row.dart';
import 'package:ssr_space/widgets/wallet_art.dart';

/// Riwayat satu dompet: saldo akhir di kop + semua transaksi pembentuknya.
class WalletDetailScreen extends StatefulWidget {
  final Wallet wallet;
  final String balanceText;
  final String typeLabel;

  const WalletDetailScreen({
    super.key,
    required this.wallet,
    required this.balanceText,
    required this.typeLabel,
  });

  @override
  State<WalletDetailScreen> createState() => _WalletDetailScreenState();
}

class _WalletDetailScreenState extends State<WalletDetailScreen> {
  List<SaasTransaction> items = [];
  bool loading = true;
  String? err;
  bool savingOnly = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      err = null;
    });
    try {
      final orgId = await activeOrgId();
      if (orgId.isEmpty) {
        setState(() => loading = false);
        return;
      }
      final txs = await TransactionService().listByWallet(
        orgId,
        widget.wallet.id,
      );
      if (!mounted) return;
      setState(() {
        items = txs;
        loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        loading = false;
        err = tr('wd_err');
      });
    }
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

  Future<void> _edit() async {
    final nameC = TextEditingController(text: widget.wallet.name);
    var type = widget.wallet.type;
    try {
      final saved = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(tr('w_rename_t')),
          content: StatefulBuilder(
            builder: (ctx, setD) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameC,
                  decoration: InputDecoration(labelText: tr('w_f_name')),
                ),
                const SizedBox(height: SsrSpace.md),
                DropdownButtonFormField<String>(
                  initialValue: type,
                  decoration: InputDecoration(labelText: tr('w_f_type')),
                  items: [
                    for (final t in ['cash', 'ewallet', 'bank', 'savings', 'investment'])
                      DropdownMenuItem(value: t, child: Text(_typeLabel(t))),
                  ],
                  onChanged: (v) => setD(() => type = v ?? type),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(tr('cancel')),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(tr('save')),
            ),
          ],
        ),
      );
      if (saved != true || !mounted) return;
      final name = nameC.text.trim();
      if (!isValidWalletName(nameC.text)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('w_err_name'))),
        );
        return;
      }
      final orgId = await activeOrgId();
      final svc = WalletService();
      if (name != widget.wallet.name) await svc.rename(widget.wallet.id, orgId, name);
      if (isKnownWalletType(type) && type != widget.wallet.type) {
        await svc.changeType(widget.wallet.id, orgId, type);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('w_renamed'))),
      );
      Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('w_err_save'))),
      );
    } finally {
      nameC.dispose();
    }
  }

  Future<void> _remove() async {
    final pinOk = await askPinDialog(context);
    if (!pinOk || !mounted) return;
    try {
      final orgId = await activeOrgId();
      final svc = WalletService();
      if (await svc.hasTransactions(orgId, widget.wallet.id)) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('w_has_tx'))),
        );
        return;
      }
      if (!mounted) return;
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(tr('w_del_confirm')),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(tr('cancel')),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(tr('tx_delete')),
            ),
          ],
        ),
      );
      if (ok != true || !mounted) return;
      try {
        await svc.deleteWallet(widget.wallet.id, orgId);
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('w_has_tx'))),
        );
        return;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('w_deleted'))),
      );
      Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('w_err_save'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.wallet.name),
        actions: [
          IconButton(
            icon: const DuoIcon(AppIcons.settings),
            tooltip: tr('w_rename_t'),
            onPressed: _edit,
          ),
        ],
      ),
      body: _body(),
    );
  }

  Widget _body() {
    if (loading) {
      return LoadingView(label: tr('wd_loading'));
    }
    if (err != null) {
      return ErrorView(message: err!, onRetry: _load);
    }
    // Rincian tabungan: OUT berkategori Tabungan/Savings, semua waktu.
    final svTotal = savingOutOf(items);
    final svCount = items
        .where((t) => t.type == 'out' && isSavingCategory(t.category))
        .length;
    final visible = savingOnly
        ? items
              .where((t) => t.type == 'out' && isSavingCategory(t.category))
              .toList()
        : items;
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            SsrSpace.lg,
            SsrSpace.lg,
            SsrSpace.lg,
            0,
          ),
          sliver: SliverToBoxAdapter(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _SummaryCard(
                  name: widget.wallet.name,
                  type: widget.wallet.type,
                  typeLabel: widget.typeLabel,
                  balanceText: widget.balanceText,
                  count: items.length,
                ),
                if (svCount > 0) ...[
                  const SizedBox(height: SsrSpace.md),
                  _SavingStrip(
                    total: svTotal,
                    count: svCount,
                    only: savingOnly,
                    onToggle: () => setState(() => savingOnly = !savingOnly),
                  ),
                ],
                const SizedBox(height: SsrSpace.md),
              ],
            ),
          ),
        ),
        if (items.isEmpty)
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: SsrSpace.lg),
            sliver: SliverToBoxAdapter(
              child: EmptyView(
                icon: AppIcons.wallet,
                illustration: 'assets/illustrations/empty_riwayat.svg',
                title: tr('wd_empty_t'),
                subtitle: tr('wd_empty_s'),
                actionLabel: tr('back'),
                onAction: () => Navigator.pop(context),
              ),
            ),
          )
        else
          ..._historySlivers(visible),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            SsrSpace.lg,
            SsrSpace.lg,
            SsrSpace.lg,
            SsrSpace.lg,
          ),
          sliver: SliverToBoxAdapter(
            child: _DeleteSection(onPressed: _remove),
          ),
        ),
      ],
    );
  }

  /// Riwayat lazy: kartu SectionCard digambar di belakang SliverList
  /// (isi tak diketahui tingginya, jadi tak bisa dibungkus Container).
  List<Widget> _historySlivers(List<SaasTransaction> items) {
    if (items.isEmpty) {
      return [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: SsrSpace.lg),
          sliver: DecoratedSliver(
            decoration: sectionCardDecoration(context),
            sliver: const SliverToBoxAdapter(
              child: SizedBox(height: SsrSpace.xs * 2),
            ),
          ),
        ),
      ];
    }
    return [
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: SsrSpace.lg),
        sliver: DecoratedSliver(
          decoration: sectionCardDecoration(context),
          sliver: SliverPadding(
            padding: const EdgeInsets.symmetric(
              horizontal: SsrSpace.sm,
              vertical: SsrSpace.xs,
            ),
            sliver: txDaySliverList(
              items: items,
              buildRow: (t) => TxRow(tx: t),
            ),
          ),
        ),
      ),
    ];
  }
}

/// Zona bahaya: hapus dompet (kunci PIN, hanya bila kosong transaksi).
class _DeleteSection extends StatelessWidget {
  final VoidCallback onPressed;

  const _DeleteSection({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: onPressed,
            child: Text(tr('tx_delete')),
          ),
        ],
      ),
    );
  }
}

/// Kop: jenis + saldo akhir + jumlah transaksi pembentuk.
class _SummaryCard extends StatelessWidget {
  final String name;
  final String type;
  final String typeLabel;
  final String balanceText;
  final int count;

  const _SummaryCard({
    required this.name,
    required this.type,
    required this.typeLabel,
    required this.balanceText,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: scheme.outline.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(SsrRadius.tile),
                  border: Border.all(color: scheme.outline),
                ),
                child: Center(child: WalletArt(type, name: name)),
              ),
              const SizedBox(width: SsrSpace.md),
              Expanded(child: StatusChip(label: typeLabel)),
            ],
          ),
          const SizedBox(height: SsrSpace.xs),
          Text(
            balanceText,
            style: AppTheme.moneyLarge.copyWith(color: scheme.onSurface),
          ),
          const SizedBox(height: SsrSpace.xs),
          Text(
            tr('wd_count').replaceFirst('{n}', '$count'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

/// Strip rincian tabungan: dot emas + "Ditabung {a} · {n} transaksi"
/// + toggle filter hanya-tabungan. Muncul hanya bila ada OUT tabungan.
class _SavingStrip extends StatelessWidget {
  final double total;
  final int count;
  final bool only;
  final VoidCallback onToggle;

  const _SavingStrip({
    required this.total,
    required this.count,
    required this.only,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      color: AppColors.gold.withValues(alpha: 0.14),
      borderColor: AppColors.gold.withValues(alpha: 0.45),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: const BoxDecoration(
              color: AppColors.gold,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: SsrSpace.sm),
          Expanded(
            child: Text(
              tr('sv_wallet_line')
                  .replaceFirst('{a}', amt(total))
                  .replaceFirst('{n}', '$count'),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          TextButton(
            onPressed: onToggle,
            child: Text(tr(only ? 'tx_show_all' : 'sv_only')),
          ),
        ],
      ),
    );
  }
}


