import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ssr_space/services/app_settings.dart';
import 'package:ssr_space/services/category_icons.dart';
import 'package:ssr_space/services/tx_filter.dart';
import 'package:ssr_space/theme/cool_icons.dart';
import 'package:ssr_space/theme/dribbble_tokens.dart';
import 'package:ssr_space/utils/datetime.dart';
import 'package:ssr_space/utils/org_prefs.dart';
import 'package:ssr_space/utils/mask.dart';
import 'package:ssr_space/services/month.dart';
import 'package:ssr_space/services/transaction_service.dart';
import 'package:ssr_space/utils/strings.dart';
import 'package:ssr_space/services/tx_wallet_check.dart';
import 'package:ssr_space/theme/app_icons.dart';
import 'package:ssr_space/theme/app_theme.dart';
import 'package:ssr_space/theme/tokens.dart';
import 'package:ssr_space/models/transaction.dart';
import 'package:ssr_space/widgets/primary_button.dart';
import 'package:ssr_space/widgets/skeletons.dart';
import 'package:ssr_space/widgets/state_views.dart';
import 'package:ssr_space/widgets/tx_day_slivers.dart';
import 'package:ssr_space/widgets/tx_input_sheet.dart';
import 'package:ssr_space/widgets/restyle/transaction_item.dart';
import 'package:ssr_space/widgets/tx_detail_sheet.dart';

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

  /// Drill dari Laporan: filter kategori langsung aktif.
  final String? initialCategory;
  const TransactionsScreen({super.key, this.initialMonth, this.initialCategory});
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
  // Batch 28: pencarian + filter advanced (saring client-side).
  final _searchC = TextEditingController();
  String _query = '';
  Set<String> _types = {};
  Set<String> _cats = {};
  String? _dateFrom;
  String? _dateTo;
  double? _minAmt;
  double? _maxAmt;
  List<TxFav> _favs = [];
  // Pagination Batch 2: halaman 100 via range, sambung saat gulir mentok.
  final _scroll = ScrollController();
  bool hasMore = true;
  bool loadingMore = false;

  @override
  void initState() {
    super.initState();
    month = widget.initialMonth ?? currentMonth();
    if (widget.initialCategory != null &&
        widget.initialCategory!.trim().isNotEmpty) {
      _cats = {widget.initialCategory!.trim()};
    }
    _scroll.addListener(_onScroll);
    _searchC.addListener(_onQueryChanged);
    _load();
    _loadFavs();
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _searchC.removeListener(_onQueryChanged);
    _searchC.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onQueryChanged() {
    if (_query == _searchC.text) return;
    setState(() => _query = _searchC.text);
  }

  TxFilter get _filter => TxFilter(
        query: _query,
        types: _types,
        cats: _cats,
        dateFrom: _dateFrom,
        dateTo: _dateTo,
        minAmount: _minAmt,
        maxAmount: _maxAmt,
      );

  Future<void> _loadFavs() async {
    try {
      final p = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() => _favs = decodeTxFavs(p.getStringList(kTxFavKey) ?? []));
    } catch (_) {}
  }

  Future<void> _persistFavs(List<TxFav> next) async {
    setState(() => _favs = next);
    try {
      final p = await SharedPreferences.getInstance();
      await p.setStringList(kTxFavKey, encodeTxFavs(next));
    } catch (_) {}
  }

  void _onScroll() {
    if (!_scroll.hasClients || loading || loadingMore || !hasMore) return;
    if (_scroll.position.pixels >=
        _scroll.position.maxScrollExtent - 600) {
      unawaited(_loadMore());
    }
  }

  /// Muat ulang dari luar (dipanggil MainShell setelah sheet tersimpan).
  Future<void> reload() => _load();

  Future<void> _load() async {
    setState(() {
      loading = true;
      err = null;
      items = [];
      hasMore = true;
      loadingMore = false;
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
      final t = await TransactionService().listMonthPage(orgId, month);
      if (!mounted) return;
      setState(() {
        noOrg = false;
        items = t;
        hasMore = txPageHasMore(t.length, txPageSize);
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

  /// Halaman berikut: tambah di ekor, order server identik jadi mulus.
  Future<void> _loadMore() async {
    if (loading || loadingMore || !hasMore || err != null) return;
    setState(() => loadingMore = true);
    try {
      final orgId = await activeOrgId();
      if (!mounted) return;
      if (orgId.isEmpty) {
        setState(() => loadingMore = false);
        return;
      }
      final t = await TransactionService().listMonthPage(
        orgId,
        month,
        after: items.isEmpty ? null : items.last,
      );
      if (!mounted) return;
      setState(() {
        items = [...items, ...t];
        hasMore = txPageHasMore(t.length, txPageSize);
        loadingMore = false;
      });
    } catch (_) {
      // Halaman gagal = diam (data yang ada tetap tampil); coba lagi
      // saat pengguna menggulir ulang.
      if (!mounted) return;
      setState(() => loadingMore = false);
    }
  }

  Future<void> _openAdd() async {
    if (await openTxInputSheet(context)) await _load();
  }

  Future<void> _openEdit(SaasTransaction t) async {
    // Buka detail ala Ollo dulu (Edit/Hapus di dalam); muat ulang bila berubah.
    if (await showOlloTxDetailSheet(context, t)) await _load();
  }

  void _onMonthChanged(String m) {
    setState(() {
      month = m;
      onlyNoWallet = false;
      // Batas tanggal absolut milik bulan lama — buang, sisanya dipertahankan.
      _dateFrom = null;
      _dateTo = null;
    });
    _load();
  }

  void _resetFilter() {
    _searchC.clear();
    setState(() {
      _query = '';
      _types = {};
      _cats = {};
      _dateFrom = null;
      _dateTo = null;
      _minAmt = null;
      _maxAmt = null;
    });
  }

  Future<void> _openFilterSheet() async {
    final cats = {
      for (final t in items)
        if ((t.category ?? '').isNotEmpty) t.category!,
    }.toList()
      ..sort();
    final res = await showModalBottomSheet<TxFilter>(
      context: context,
      isScrollControlled: true,
      backgroundColor: DribTokens.cardOf(context),
      builder: (_) => _FilterSheet(initial: _filter, categories: cats),
    );
    if (res != null && mounted) {
      setState(() {
        _types = res.types;
        _cats = res.cats;
        _dateFrom = res.dateFrom;
        _dateTo = res.dateTo;
        _minAmt = res.minAmount;
        _maxAmt = res.maxAmount;
      });
    }
  }

  Future<void> _saveFav() async {
    final f = _filter;
    if (f.isEmpty) return;
    if (_favs.length >= kTxFavCap) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('txf_fav_full'))),
      );
      return;
    }
    final nameC = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('txf_save_fav')),
        content: TextField(
          controller: nameC,
          autofocus: true,
          maxLength: 24,
          decoration: InputDecoration(hintText: tr('txf_fav_name')),
          onSubmitted: (_) => Navigator.of(ctx).pop(nameC.text.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(tr('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(nameC.text.trim()),
            child: Text(tr('save')),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty || !mounted) return;
    await _persistFavs(addTxFav(_favs, TxFav(name: name, filter: f)));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(tr('txf_fav_saved'))),
    );
  }

  void _applyFav(TxFav fav) {
    _searchC.text = fav.filter.query;
    setState(() {
      _query = fav.filter.query;
      _types = Set.of(fav.filter.types);
      _cats = Set.of(fav.filter.cats);
      _dateFrom = fav.filter.dateFrom;
      _dateTo = fav.filter.dateTo;
      _minAmt = fav.filter.minAmount;
      _maxAmt = fav.filter.maxAmount;
    });
  }

  Future<void> _deleteFav(TxFav fav) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(fav.name),
        content: Text(tr('txf_del_body')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(tr('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(tr('tx_delete')),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _persistFavs(
        [for (final f in _favs) if (f.name != fav.name) f],
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (noOrg) {
      return _TxStateScaffold(
        onAdd: _openAdd,
        body: EmptyView(
          icon: AppIcons.workspace,
          illustration: 'assets/illustrations/empty_undangan.svg',
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
        scrollController: _scroll,
        loadingMore: loadingMore,
        hasMore: hasMore,
        searchController: _searchC,
        filter: _filter,
        favs: _favs,
        onOpenFilter: _openFilterSheet,
        onResetFilter: _resetFilter,
        onSaveFav: _saveFav,
        onApplyFav: _applyFav,
        onDeleteFav: _deleteFav,
        onTypeFilter: (types) => setState(() => _types = types),
      ),
    );
  }
}

/// Blok riwayat: judul bulan + banner tanpa-dompet + daftar TransactionItem
/// (atau EmptyView bila kosong). Ketuk baris = ubah via sheet. Hapus via
/// geser-konfirmasi di sheet ubah (bukan swipe di list).
class _TxHistorySection {
  final String month;
  final List<SaasTransaction> items;
  final ValueChanged<SaasTransaction> onTap;
  final VoidCallback onEmptyAction;
  final bool onlyNoWallet;
  final VoidCallback onToggleNoWallet;
  final TxFilter filter;
  final VoidCallback onResetFilter;

  const _TxHistorySection({
    required this.month,
    required this.items,
    required this.onTap,
    required this.onEmptyAction,
    required this.onlyNoWallet,
    required this.onToggleNoWallet,
    required this.filter,
    required this.onResetFilter,
  });

  List<SaasTransaction> get _noWallet => items.where(hasNoWallet).toList();

  List<SaasTransaction> get _shown => applyTxFilter(
        onlyNoWallet ? _noWallet : items,
        filter,
      );

  /// Judul + banner sebagai adapter, daftar sebagai SliverList lazy.
  List<Widget> slivers(BuildContext context) {
    final shown = _shown;
    final head = SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: SsrSpace.lg),
      sliver: SliverToBoxAdapter(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              txHistoryTitle(month),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: SsrSpace.sm),
            _noWalletBanner(),
          ],
        ),
      ),
    );
    if (shown.isEmpty) {
      final filtering = !filter.isEmpty;
      return [
        head,
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: SsrSpace.lg),
          sliver: SliverToBoxAdapter(
            child: SizedBox(
              height: 260,
              child: EmptyView(
                icon: AppIcons.transactions,
                illustration: 'assets/illustrations/empty_riwayat.svg',
                title: tr(filtering ? 'txf_empty_t' : 'tx_empty_t'),
                subtitle: tr(filtering ? 'txf_empty_s' : 'tx_empty_s'),
                actionLabel:
                    tr(filtering ? 'clear' : 'tx_empty_a'),
                onAction: filtering ? onResetFilter : onEmptyAction,
              ),
            ),
          ),
        ),
      ];
    }
    return [
      head,
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: SsrSpace.lg),
        sliver: txDaySliverList(
          items: shown,
          buildRow: _txItem,
          dividersBetween: false,
        ),
      ),
    ];
  }

  /// Satu baris gaya baru: ikon pastel + nominal tabular. Ketuk = ubah.
  /// Chips/catatan TxRow lama tak tampil di list (baca via ketuk-ubah);
  /// nominal, tanggal, kode, kategori tetap sama.
  Widget _txItem(SaasTransaction t) {
    final when = txWhenLabel(t.date, t.createdAt);
    final code = (t.code ?? '').isEmpty ? '' : t.code!;
    final date = when.isEmpty
        ? code
        : code.isEmpty
            ? when
            : '$when · $code';
    final nominal = amt(t.amount);
    final signed = t.type == 'in'
        ? '+ $nominal'
        : t.type == 'out'
            ? '− $nominal'
            : nominal;
    final kind = t.type == 'in'
        ? tr('tx_in')
        : t.type == 'transfer'
            ? tr('tx_transfer')
            : tr('tx_out');
    final title =
        (t.category ?? '').isNotEmpty ? t.category! : kind;
    final tint = t.type == 'in'
        ? Colors.green.shade700
        : t.type == 'out'
            ? Colors.red.shade700
            : DribTokens.navy;
    return TransactionItem(
      iconSvg: svgForCategory(t.category),
      tint: tint,
      title: title,
      date: date,
      amount: signed,
      isIncome: t.type == 'in',
      neutral: t.type == 'transfer',
      onTap: () => onTap(t),
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
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: SsrSpace.sm),
      padding: const EdgeInsets.all(SsrSpace.md),
      decoration: BoxDecoration(
        color: DribTokens.accentOrangeBg,
        borderRadius: BorderRadius.circular(DribTokens.cardRadius),
        border: Border.all(color: DribTokens.accentOrange),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: DribTokens.accentOrangeTextDark,
                fontWeight: FontWeight.w600,
              ),
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
/// Tanpa FAB sendiri: tombol + global milik MainShell (tengah bawah)
/// + aksi AppBar sudah cukup (tiga + membingungkan).
class _TxStateScaffold extends StatelessWidget {
  final Widget body;
  final VoidCallback onAdd;

  const _TxStateScaffold({required this.body, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DribTokens.bgOf(context),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          tr('nav_transaksi'),
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            onPressed: onAdd,
            icon: const DuoIcon(AppIcons.add),
            tooltip: tr('act_catat'),
          ),
        ],
      ),
      body: body,
    );
  }
}

/// Isi layar Transaksi: cari, pemilih bulan, strip ringkasan, favorit,
/// dan blok riwayat.
class _TxListBody extends StatelessWidget {
  final String month;
  final ValueChanged<String> onMonthChanged;
  final List<SaasTransaction> items;
  final ValueChanged<SaasTransaction> onTap;
  final VoidCallback onEmptyAction;
  final bool onlyNoWallet;
  final VoidCallback onToggleNoWallet;
  final ScrollController scrollController;
  final bool loadingMore;
  final bool hasMore;
  final TextEditingController searchController;
  final TxFilter filter;
  final List<TxFav> favs;
  final VoidCallback onOpenFilter;
  final VoidCallback onResetFilter;
  final VoidCallback onSaveFav;
  final ValueChanged<TxFav> onApplyFav;
  final ValueChanged<TxFav> onDeleteFav;
  final ValueChanged<Set<String>> onTypeFilter;

  const _TxListBody({
    required this.month,
    required this.onMonthChanged,
    required this.items,
    required this.onTap,
    required this.onEmptyAction,
    required this.onlyNoWallet,
    required this.onToggleNoWallet,
    required this.scrollController,
    required this.loadingMore,
    required this.hasMore,
    required this.searchController,
    required this.filter,
    required this.favs,
    required this.onOpenFilter,
    required this.onResetFilter,
    required this.onSaveFav,
    required this.onApplyFav,
    required this.onDeleteFav,
    required this.onTypeFilter,
  });

  @override
  Widget build(BuildContext context) {
    final base = onlyNoWallet ? items.where(hasNoWallet).toList() : items;
    final shown = applyTxFilter(base, filter);
    final filtering = !filter.isEmpty;
    return CustomScrollView(
      controller: scrollController,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.only(
            left: SsrSpace.lg,
            top: SsrSpace.lg,
            right: SsrSpace.lg,
          ),
          sliver: SliverToBoxAdapter(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _TxSearchRow(
                  controller: searchController,
                  filterActive: filtering,
                  onOpenFilter: onOpenFilter,
                  onClearSearch: searchController.clear,
                ),
                const SizedBox(height: SsrSpace.sm),
                _TxTypeChips(
                  types: filter.types,
                  onChanged: onTypeFilter,
                ),
                _TxCountCaption(
                  filtering: filtering,
                  shown: shown.length,
                  loaded: items.length,
                  hasMore: hasMore,
                ),
                if (favs.isNotEmpty || filtering) ...[
                  const SizedBox(height: SsrSpace.sm),
                  _TxFavRow(
                    favs: favs,
                    filtering: filtering,
                    onApply: onApplyFav,
                    onDelete: onDeleteFav,
                    onSave: onSaveFav,
                    onReset: onResetFilter,
                  ),
                ],
                const SizedBox(height: SsrSpace.xl),
              ],
            ),
          ),
        ),
        ..._TxHistorySection(
          month: month,
          items: items,
          onTap: onTap,
          onEmptyAction: onEmptyAction,
          onlyNoWallet: onlyNoWallet,
          onToggleNoWallet: onToggleNoWallet,
          filter: filter,
          onResetFilter: onResetFilter,
        ).slivers(context),
        if (loadingMore)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: SsrSpace.lg),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          )
        else if (!hasMore && items.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: SsrSpace.md),
              child: Center(
                child: Text(
                  tr('tx_all_shown')
                      .replaceFirst('{n}', '${items.length}'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 120)),
      ],
    );
  }
}

/// Keterangan jumlah jujur: ikut saring bila filter aktif, dan jujur
/// bila halaman belum habis (disaring dari yang termuat saja).
class _TxCountCaption extends StatelessWidget {
  final bool filtering;
  final int shown;
  final int loaded;
  final bool hasMore;

  const _TxCountCaption({
    required this.filtering,
    required this.shown,
    required this.loaded,
    required this.hasMore,
  });

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall;
    if (filtering) {
      final line = tr('txf_result')
          .replaceFirst('{n}', '$shown')
          .replaceFirst('{m}', '$loaded');
      if (!hasMore) return Text(line, style: style);
      return Text(
        '$line. ${tr('txf_partial').replaceFirst('{n}', '$loaded')}',
        style: style,
      );
    }
    // Tanpa filter: perilaku lama (caption halaman).
    if (!hasMore || loaded == 0) return const SizedBox.shrink();
    return Text(
      tr('tx_partial').replaceFirst('{n}', '$loaded'),
      style: style,
    );
  }
}

/// Baris cari + tombol filter (titik = filter aktif).
class _TxSearchRow extends StatelessWidget {
  final TextEditingController controller;
  final bool filterActive;
  final VoidCallback onOpenFilter;
  final VoidCallback onClearSearch;

  const _TxSearchRow({
    required this.controller,
    required this.filterActive,
    required this.onOpenFilter,
    required this.onClearSearch,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: SsrSpace.md),
            decoration: BoxDecoration(
              color: DribTokens.cardOf(context),
              borderRadius: BorderRadius.circular(SsrRadius.input),
              border: Border.all(color: DribTokens.border, width: 1.5),
            ),
            child: TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: tr('txf_search'),
                prefixIcon: const DuoIcon(AppIcons.search),
                suffixIcon: controller.text.isEmpty
                    ? null
                    : IconButton(
                        onPressed: onClearSearch,
                        icon: const DuoIcon(AppIcons.close),
                        tooltip: tr('clear'),
                      ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                    vertical: SsrSpace.sm),
              ),
            ),
          ),
        ),
        const SizedBox(width: SsrSpace.sm),
        Stack(
          alignment: Alignment.topRight,
          children: [
            IconButton(
              onPressed: onOpenFilter,
              tooltip: tr('txf_filter'),
              style: IconButton.styleFrom(
                backgroundColor: DribTokens.cardOf(context),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(SsrRadius.input),
                  side: const BorderSide(
                      color: DribTokens.border, width: 1.5),
                ),
              ),
              icon: SvgPicture.asset(
                CoolSvg.filter,
                width: 22,
                height: 22,
                colorFilter: ColorFilter.mode(
                  filterActive ? scheme.primary : scheme.onSurface,
                  BlendMode.srcIn,
                ),
              ),
            ),
            if (filterActive)
              Positioned(
                right: 11,
                top: 11,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// Baris favorit horizontal: ketuk = pakai, ikon hapus = buang.
/// Saat menyaring: tombol Simpan + Reset di ekor.
class _TxFavRow extends StatelessWidget {
  final List<TxFav> favs;
  final bool filtering;
  final ValueChanged<TxFav> onApply;
  final ValueChanged<TxFav> onDelete;
  final VoidCallback onSave;
  final VoidCallback onReset;

  const _TxFavRow({
    required this.favs,
    required this.filtering,
    required this.onApply,
    required this.onDelete,
    required this.onSave,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final f in favs)
            Padding(
              padding: const EdgeInsets.only(right: SsrSpace.sm),
              child: InputChip(
                label: Text(f.name),
                backgroundColor: DribTokens.cardOf(context),
                side: const BorderSide(color: DribTokens.border),
                onPressed: () => onApply(f),
                onDeleted: () => onDelete(f),
                deleteButtonTooltipMessage: tr('tx_delete'),
              ),
            ),
          if (filtering) ...[
            TextButton(
              onPressed: onReset,
              child: Text(tr('clear')),
            ),
            TextButton(
              onPressed: onSave,
              child: Text(tr('txf_save_fav')),
            ),
          ],
        ],
      ),
    );
  }
}

String _ymdOf(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

double? _parseAmt(String s) {
  final digits = s.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.isEmpty) return null;
  return double.tryParse(digits);
}

String _shortDay(String? ymd) {
  if (ymd == null || ymd.length < 10) return '–';
  final m = int.tryParse(ymd.substring(5, 7)) ?? 0;
  if (m < 1 || m > 12) return ymd;
  return '${ymd.substring(8, 10)} ${tr('s${m.toString().padLeft(2, '0')}')}';
}

/// Lembar filter multi-kriteria. Kembalikan [TxFilter] via pop,
/// atau null bila ditutup tanpa menerapkan.
class _FilterSheet extends StatefulWidget {
  final TxFilter initial;
  final List<String> categories;

  const _FilterSheet({required this.initial, required this.categories});

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late Set<String> _types;
  late Set<String> _cats;
  String? _from;
  String? _to;
  String? _expanded;
  late TextEditingController _minC;
  late TextEditingController _maxC;

  @override
  void initState() {
    super.initState();
    final i = widget.initial;
    _types = Set.of(i.types);
    _cats = Set.of(i.cats);
    _from = i.dateFrom;
    _to = i.dateTo;
    _minC = TextEditingController(
      text: i.minAmount == null ? '' : i.minAmount!.toStringAsFixed(0),
    );
    _maxC = TextEditingController(
      text: i.maxAmount == null ? '' : i.maxAmount!.toStringAsFixed(0),
    );
  }

  @override
  void dispose() {
    _minC.dispose();
    _maxC.dispose();
    super.dispose();
  }

  void _toggle(Set<String> set, String v) {
    setState(() {
      if (!set.remove(v)) set.add(v);
    });
  }

  Future<void> _pickDate(bool isFrom) async {
    final now = DateTime.now();
    DateTime init = DateTime(now.year, now.month, 1);
    final cur = isFrom ? _from : _to;
    if (cur != null && cur.length >= 10) {
      final p = DateTime.tryParse(cur);
      if (p != null) init = p;
    }
    final d = await showDatePicker(
      context: context,
      initialDate: init,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 1, 12, 31),
    );
    if (d == null) return;
    setState(() {
      if (isFrom) {
        _from = _ymdOf(d);
      } else {
        _to = _ymdOf(d);
      }
    });
  }

  void _apply() {
    Navigator.of(context).pop(
      TxFilter(
        query: widget.initial.query,
        types: _types,
        cats: _cats,
        dateFrom: _from,
        dateTo: _to,
        minAmount: _parseAmt(_minC.text),
        maxAmount: _parseAmt(_maxC.text),
      ),
    );
  }

  void _toggleExpanded(String key) =>
      setState(() => _expanded = _expanded == key ? null : key);

  @override
  Widget build(BuildContext context) {
    const typeDefs = [
      ('in', 'tx_in'),
      ('out', 'tx_out'),
      ('transfer', 'tx_transfer'),
    ];
    final lo = _parseAmt(_minC.text);
    final hi = _parseAmt(_maxC.text);

    final periodValue = (_from == null && _to == null)
        ? tr('txf_all_time')
        : '${_shortDay(_from)} - ${_shortDay(_to)}';
    final typeValue =
        _types.isEmpty ? tr('txf_all') : _types.map((t) => tr('tx_$t')).join(', ');
    final catValue = _cats.isEmpty
        ? tr('txf_all')
        : tr('txf_selected').replaceFirst('{n}', '${_cats.length}');
    final String nominalValue;
    if (lo == null && hi == null) {
      nominalValue = tr('txf_all');
    } else if (lo != null && hi != null) {
      nominalValue = '${amt(lo)} - ${amt(hi)}';
    } else if (lo != null) {
      nominalValue = '≥ ${amt(lo)}';
    } else if (hi != null) {
      nominalValue = '≤ ${amt(hi)}';
    } else {
      nominalValue = tr('txf_all');
    }

    return SafeArea(
      child: Container(
        color: DribTokens.cardOf(context),
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(SsrSpace.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        tr('txf_filter'),
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const DuoIcon(AppIcons.close),
                      tooltip: tr('td_close'),
                    ),
                  ],
                ),
                const SizedBox(height: SsrSpace.md),
                _PillRow(
                  title: tr('txf_period'),
                  value: periodValue,
                  expanded: _expanded == 'period',
                  onTap: () => _toggleExpanded('period'),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _pickDate(true),
                          child: Text('${tr('txf_from')}: ${_from ?? '–'}'),
                        ),
                      ),
                      const SizedBox(width: SsrSpace.sm),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _pickDate(false),
                          child: Text('${tr('txf_to')}: ${_to ?? '–'}'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: SsrSpace.sm),
                _PillRow(
                  title: tr('txf_type'),
                  value: typeValue,
                  expanded: _expanded == 'type',
                  onTap: () => _toggleExpanded('type'),
                  child: Wrap(
                    spacing: SsrSpace.sm,
                    children: [
                      for (final def in typeDefs)
                        FilterChip(
                          label: Text(tr(def.$2)),
                          selected: _types.contains(def.$1),
                          selectedColor: DribTokens.blueLight,
                          checkmarkColor: DribTokens.primaryStrong,
                          side: const BorderSide(color: DribTokens.border),
                          onSelected: (_) => _toggle(_types, def.$1),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: SsrSpace.sm),
                _PillRow(
                  title: tr('txf_cat'),
                  value: catValue,
                  expanded: _expanded == 'cat',
                  onTap: () => _toggleExpanded('cat'),
                  child: widget.categories.isEmpty
                      ? null
                      : Wrap(
                          spacing: SsrSpace.sm,
                          children: [
                            for (final c in widget.categories.take(20))
                              FilterChip(
                                label: Text(c),
                                selected: _cats.contains(c),
                                selectedColor: DribTokens.blueLight,
                                checkmarkColor: DribTokens.primaryStrong,
                                side: const BorderSide(
                                    color: DribTokens.border),
                                onSelected: (_) => _toggle(_cats, c),
                              ),
                          ],
                        ),
                ),
                const SizedBox(height: SsrSpace.sm),
                _PillRow(
                  title: tr('txf_nominal_range'),
                  value: nominalValue,
                  expanded: _expanded == 'amount',
                  onTap: () => _toggleExpanded('amount'),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _minC,
                          keyboardType: TextInputType.number,
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            hintText: tr('txf_min'),
                            border: const OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: SsrSpace.sm),
                      Expanded(
                        child: TextField(
                          controller: _maxC,
                          keyboardType: TextInputType.number,
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            hintText: tr('txf_max'),
                            border: const OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: SsrSpace.lg),
                PrimaryButton(
                  label: tr('txf_apply'),
                  onPressed: _apply,
                ),
                const SizedBox(height: SsrSpace.sm),
                Center(
                  child: TextButton(
                    onPressed: () =>
                        Navigator.of(context).pop(const TxFilter()),
                    child: Text(tr('clear')),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Baris pill-dropdown filter: judul + nilai + chevron, tap untuk
/// membuka isi filter di bawahnya.
class _PillRow extends StatelessWidget {
  final String title;
  final String value;
  final bool expanded;
  final VoidCallback onTap;
  final Widget? child;

  const _PillRow({
    required this.title,
    required this.value,
    required this.expanded,
    required this.onTap,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: SsrSpace.md,
              vertical: SsrSpace.sm + 2,
            ),
            decoration: BoxDecoration(
              color: DribTokens.cardOf(context),
              borderRadius: BorderRadius.circular(DribTokens.cardRadius),
              border: Border.all(color: DribTokens.border, width: 1.5),
            ),
            child: Row(
              children: [
                Text(title, style: Theme.of(context).textTheme.titleSmall),
                const Spacer(),
                Flexible(
                  child: Text(
                    value,
                    textAlign: TextAlign.end,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ),
                const SizedBox(width: 4),
                AnimatedRotation(
                  turns: expanded ? 0.25 : 0,
                  duration: const Duration(milliseconds: 150),
                  child: DuoIcon(
                    AppIcons.chevron,
                    size: 18,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (expanded && child != null) ...[
          const SizedBox(height: SsrSpace.sm),
          child!,
        ],
      ],
    );
  }
}

/// Chip saring tipe cepat ala mockup: Semua / Pengeluaran / Pemasukan.
/// Aktif = latar navy teks putih; nonaktif = kartu putih border mockup.
/// Memakai state filter yang sama dengan sheet filter (tanpa logika baru).
class _TxTypeChips extends StatelessWidget {
  final Set<String> types;
  final ValueChanged<Set<String>> onChanged;

  const _TxTypeChips({required this.types, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final all = types.isEmpty;
    final out = types.length == 1 && types.contains('out');
    final inc = types.length == 1 && types.contains('in');
    return Row(
      children: [
        _chip(context, tr('txf_all'), all, () => onChanged({})),
        const SizedBox(width: SsrSpace.sm),
        _chip(context, tr('tx_out'), out, () => onChanged({'out'})),
        const SizedBox(width: SsrSpace.sm),
        _chip(context, tr('tx_in'), inc, () => onChanged({'in'})),
      ],
    );
  }

  Widget _chip(
    BuildContext context,
    String label,
    bool on,
    VoidCallback onTap,
  ) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(SsrRadius.pill),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: SsrSpace.md,
          vertical: SsrSpace.sm,
        ),
        decoration: BoxDecoration(
          color: on ? DribTokens.navy : DribTokens.cardOf(context),
          borderRadius: BorderRadius.circular(SsrRadius.pill),
          border: Border.all(
            color: on ? DribTokens.navy : DribTokens.border,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: on
                ? Colors.white
                : (dark ? Colors.white : DribTokens.textSecondary),
          ),
        ),
      ),
    );
  }
}
