import 'package:flutter/material.dart';
import 'package:ssr_space/utils/org_prefs.dart';
import 'package:ssr_space/utils/strings.dart';
import 'package:ssr_space/models/transaction.dart';
import 'package:ssr_space/models/wallet.dart';
import 'package:ssr_space/services/transaction_service.dart';
import 'package:ssr_space/theme/app_icons.dart';
import 'package:ssr_space/theme/app_theme.dart';
import 'package:ssr_space/widgets/section_card.dart';
import 'package:ssr_space/widgets/state_views.dart';
import 'package:ssr_space/widgets/status_chip.dart';
import 'package:ssr_space/widgets/tx_row.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.wallet.name)),
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
    return ListView(
      padding: const EdgeInsets.all(SsrSpace.lg),
      children: [
        _SummaryCard(
          typeLabel: widget.typeLabel,
          balanceText: widget.balanceText,
          count: items.length,
        ),
        const SizedBox(height: SsrSpace.md),
        if (items.isEmpty)
          EmptyView(
            icon: AppIcons.wallet,
            illustration: 'assets/illustrations/empty_riwayat.svg',
            title: tr('wd_empty_t'),
            subtitle: tr('wd_empty_s'),
            actionLabel: tr('back'),
            onAction: () => Navigator.pop(context),
          )
        else
          _HistoryCard(items: items),
      ],
    );
  }
}

/// Kop: jenis + saldo akhir + jumlah transaksi pembentuk.
class _SummaryCard extends StatelessWidget {
  final String typeLabel;
  final String balanceText;
  final int count;

  const _SummaryCard({
    required this.typeLabel,
    required this.balanceText,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StatusChip(label: typeLabel),
          const SizedBox(height: SsrSpace.xs),
          Text(balanceText, style: SsrTheme.moneyLarge),
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

/// Daftar transaksi + divider ala ledger.
class _HistoryCard extends StatelessWidget {
  final List<SaasTransaction> items;

  const _HistoryCard({required this.items});

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      padding: const EdgeInsets.symmetric(
        horizontal: SsrSpace.sm,
        vertical: SsrSpace.xs,
      ),
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            TxRow(tx: items[i]),
          ],
        ],
      ),
    );
  }
}
