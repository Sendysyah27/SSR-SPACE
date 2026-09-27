import 'package:flutter/material.dart';
import 'package:ssr_space/services/app_settings.dart';
import 'package:ssr_space/utils/org_prefs.dart';
import 'package:ssr_space/utils/mask.dart';
import 'package:ssr_space/services/month.dart';
import 'package:ssr_space/services/transaction_service.dart';
import 'package:ssr_space/services/tx_day_group.dart';
import 'package:ssr_space/utils/strings.dart';
import 'package:ssr_space/services/tx_wallet_check.dart';
import 'package:ssr_space/theme/app_icons.dart';
import 'package:ssr_space/theme/app_theme.dart';
import 'package:ssr_space/models/transaction.dart';
import 'package:ssr_space/widgets/day_header.dart';
import 'package:ssr_space/widgets/month_picker.dart';
import 'package:ssr_space/widgets/section_card.dart';
import 'package:ssr_space/widgets/skeletons.dart';
import 'package:ssr_space/widgets/state_views.dart';
import 'package:ssr_space/widgets/tx_input_sheet.dart';
import 'package:ssr_space/widgets/tx_row.dart';

String txHistoryTitle(String m) {
  final label = localeCode.value == 'en'
      ? monthLabel(m)
      : monthLabel(m).toLowerCase();
  return tr('tx_history').replaceFirst('{m}', label);
}

/// Layar Transaksi = riwayat premium. Input pindah ke [TxInputSheet]
/// lewat tombol + tengah navbar / aksi + AppBar / ketuk baris (edit).
class TransactionsScreen extends StatefulWidget {
  final String? initialMonth;
  const TransactionsScreen({super.key, this.initialMonth});
  @override
  State<TransactionsScreen> createState() => TransactionsScreenState();
}

class TransactionsScreenState extends State<TransactionsScreen> {
  late String month;
  List<SaasTransaction> items = [];
  bool noOrg = false;
  bool loading = true;
  String? err;
  bool onlyNoWallet = false;

  @override
  void initState() {
    super.initState();
    month = widget.initialMonth ?? currentMonth();
    _load();
  }

  /// Muat ulang dari luar (dipanggil MainShell setelah sheet tersimpan).
  Future<void> reload() => _load();

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
      final t = await TransactionService().listMonth(orgId, month);
      if (!mounted) return;
      setState(() {
        noOrg = false;
        items = t;
        loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        loading = false;
        err = tr('tx_err_load');
      });
    }
  }

  Future<void> _openAdd() async {
    if (await openTxInputSheet(context)) await _load();
  }

  Future<void> _openEdit(SaasTransaction t) async {
    if (await openTxInputSheet(context, editing: t)) await _load();
  }

  void _onMonthChanged(String m) {
    setState(() {
      month = m;
      onlyNoWallet = false;
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    if (noOrg) {
      return _TxStateScaffold(
        onAdd: _openAdd,
        body: EmptyView(
          icon: AppIcons.workspace,
          title: tr('tx_no_org_t'),
          subtitle: tr('tx_no_org_s'),
          actionLabel: tr('reload'),
          onAction: _load,
        ),
      );
    }
    if (loading) {
      return _TxStateScaffold(onAdd: _openAdd, body: const TxListSkeleton());
    }
    if (err != null) {
      return _TxStateScaffold(
        onAdd: _openAdd,
        body: ErrorView(message: err!, onRetry: _load),
      );
    }
    return _TxStateScaffold(
      onAdd: _openAdd,
      body: _TxListBody(
        month: month,
        onMonthChanged: _onMonthChanged,
        items: items,
        onTap: _openEdit,
        onEmptyAction: _openAdd,
        onlyNoWallet: onlyNoWallet,
        onToggleNoWallet: () =>
            setState(() => onlyNoWallet = !onlyNoWallet),
      ),
    );
  }
}

/// Strip ringkasan bulan: Masuk / Keluar / Surplus-Defisit.
/// Rumus sama dengan beranda (transfer diabaikan), angka mask-aware.
class _TxSummaryStrip extends StatelessWidget {
  final List<SaasTransaction> items;

  const _TxSummaryStrip({required this.items});

  @override
  Widget build(BuildContext context) {
    var totalIn = 0.0;
    var totalOut = 0.0;
    for (final t in items) {
      if (t.type == 'in') {
        totalIn += t.amount;
      } else if (t.type == 'out') {
        totalOut += t.amount;
      }
    }
    final net = totalIn - totalOut;
    final scheme = Theme.of(context).colorScheme;
    return SectionCard(
      child: Row(
        children: [
          _SummaryCell(
            label: tr('tx_in'),
            value: amt(totalIn),
            color: scheme.primary,
          ),
          _SummaryCell(
            label: tr('tx_out'),
            value: amt(totalOut),
            color: scheme.error,
          ),
          _SummaryCell(
            label: tr(net >= 0 ? 'beranda_surplus' : 'beranda_defisit'),
            value: amt(net),
            color: scheme.onSurface,
          ),
        ],
      ),
    );
  }
}

/// Satu kolom angka ringkasan: label kecil sekunder, nominal tabular.
class _SummaryCell extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _SummaryCell({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              color: color,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

/// Blok riwayat: judul bulan + banner tanpa-dompet + daftar TxRow
/// (atau EmptyView bila kosong). Ketuk baris = ubah via sheet.
class _TxHistorySection extends StatelessWidget {
  final String month;
  final List<SaasTransaction> items;
  final ValueChanged<SaasTransaction> onTap;
  final VoidCallback onEmptyAction;
  final bool onlyNoWallet;
  final VoidCallback onToggleNoWallet;

  const _TxHistorySection({
    required this.month,
    required this.items,
    required this.onTap,
    required this.onEmptyAction,
    required this.onlyNoWallet,
    required this.onToggleNoWallet,
  });

  List<SaasTransaction> get _noWallet => items.where(hasNoWallet).toList();

  List<SaasTransaction> get _shown =>
      onlyNoWallet ? _noWallet : items;

  @override
  Widget build(BuildContext context) {
    final shown = _shown;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          txHistoryTitle(month),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: SsrSpace.sm),
        _noWalletBanner(),
        if (shown.isEmpty)
          SizedBox(
            height: 260,
            child: EmptyView(
              icon: AppIcons.transactions,
              illustration: 'assets/illustrations/empty_riwayat.svg',
              title: tr('tx_empty_t'),
              subtitle: tr('tx_empty_s'),
              actionLabel: tr('tx_empty_a'),
              onAction: onEmptyAction,
            ),
          )
        else
          for (final b in groupDayBuckets(shown)) ...[
            DayHeader(dateKey: b.key, count: b.items.length),
            for (final t in b.items) ...[
              TxRow(tx: t, onTap: () => onTap(t)),
              const Divider(height: 1),
            ],
          ],
      ],
    );
  }

  Widget _noWalletBanner() {
    final missing = _noWallet;
    if (missing.isEmpty) return const SizedBox.shrink();
    return _NoWalletBanner(
      text: tr('tx_nowallet_banner')
          .replaceFirst('{n}', '${missing.length}')
          .replaceFirst('{a}', amt(noWalletTotal(missing))),
      filterActive: onlyNoWallet,
      onToggle: onToggleNoWallet,
    );
  }
}

/// Banner peringatan: transaksi tanpa dompet tak masuk total aset.
/// Ketuk tombol untuk saring hanya yang tanpa dompet (biar cepat diperbaiki
/// via ubah — sheet ubah wajib isi dompet).
class _NoWalletBanner extends StatelessWidget {
  final String text;
  final bool filterActive;
  final VoidCallback onToggle;

  const _NoWalletBanner({
    required this.text,
    required this.filterActive,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: SsrSpace.sm),
      padding: const EdgeInsets.all(SsrSpace.md),
      decoration: BoxDecoration(
        color: scheme.error.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(SsrRadius.tile),
        border: Border.all(
          color: scheme.error.withValues(alpha: 0.45),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium,
            ),
          ),
          TextButton(
            onPressed: onToggle,
            child: Text(
              tr(filterActive ? 'tx_show_all' : 'tx_nowallet_only'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Kerangka layar Transaksi: AppBar + aksi catat + body (state / daftar).
class _TxStateScaffold extends StatelessWidget {
  final Widget body;
  final VoidCallback onAdd;

  const _TxStateScaffold({required this.body, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('nav_transaksi')),
        actions: [
          IconButton(
            onPressed: onAdd,
            icon: const DuoIcon(AppIcons.add),
            tooltip: tr('act_catat'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: onAdd,
        tooltip: tr('act_catat'),
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        child: const DuoIcon(AppIcons.add),
      ),
      body: body,
    );
  }
}

/// Isi layar Transaksi: pemilih bulan, strip ringkasan, dan blok riwayat.
class _TxListBody extends StatelessWidget {
  final String month;
  final ValueChanged<String> onMonthChanged;
  final List<SaasTransaction> items;
  final ValueChanged<SaasTransaction> onTap;
  final VoidCallback onEmptyAction;
  final bool onlyNoWallet;
  final VoidCallback onToggleNoWallet;

  const _TxListBody({
    required this.month,
    required this.onMonthChanged,
    required this.items,
    required this.onTap,
    required this.onEmptyAction,
    required this.onlyNoWallet,
    required this.onToggleNoWallet,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        SsrSpace.lg,
        SsrSpace.lg,
        SsrSpace.lg,
        120,
      ),
      children: [
        MonthPicker(month: month, onChanged: onMonthChanged),
        const SizedBox(height: SsrSpace.md),
        _TxSummaryStrip(items: items),
        const SizedBox(height: SsrSpace.xl),
        _TxHistorySection(
          month: month,
          items: items,
          onTap: onTap,
          onEmptyAction: onEmptyAction,
          onlyNoWallet: onlyNoWallet,
          onToggleNoWallet: onToggleNoWallet,
        ),
      ],
    );
  }
}
