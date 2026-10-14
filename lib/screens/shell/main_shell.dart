import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ssr_space/utils/mask.dart';
import 'package:ssr_space/services/app_settings.dart';
import 'package:ssr_space/services/auto_saved_notify.dart';
import 'package:ssr_space/services/budget_alert_notify.dart';
import 'package:ssr_space/services/foreground_track.dart';
import 'package:ssr_space/services/notif_track_service.dart';
import 'package:ssr_space/services/offline_cache.dart';
import 'package:ssr_space/services/realtime_sync.dart';
import 'package:ssr_space/services/pin_link_verify.dart';
import 'package:ssr_space/services/session_service.dart';
import 'package:ssr_space/services/transaction_service.dart';
import 'package:ssr_space/theme/app_icons.dart';
import 'package:ssr_space/utils/org_prefs.dart';
import 'package:ssr_space/utils/strings.dart';
import 'package:ssr_space/widgets/tx_detail_sheet.dart';
import 'package:ssr_space/widgets/tx_input_sheet.dart';
import 'package:ssr_space/widgets/input_mode_sheet.dart';
import 'package:ssr_space/screens/auth/lock_screen.dart';
import 'package:ssr_space/screens/auth/set_password_screen.dart';
import 'package:ssr_space/screens/beranda/beranda_screen.dart';
import 'package:ssr_space/screens/budget/budgets_screen.dart';
import 'package:ssr_space/screens/lainnya/other_screen.dart';
import 'package:ssr_space/screens/laporan/reports_screen.dart';
import 'package:ssr_space/screens/transaksi/transactions_screen.dart';

class MainShell extends StatefulWidget {
  final SessionService session;
  const MainShell({super.key, required this.session});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with WidgetsBindingObserver {
  int index = 0;
  final berandaKey = GlobalKey<BerandaScreenState>();
  final budgetKey = GlobalKey<BudgetsScreenState>();
  final reportsKey = GlobalKey<ReportsScreenState>();
  final txKey = GlobalKey<TransactionsScreenState>();
  bool _resumed = true;
  bool _detailOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // force: resubscribe bila stream sempat error / app resume dari background
    NotifTrack.ensureListening(force: true);
    unawaited(ForegroundTrack.syncFromPrefs());
    unawaited(_ensureRealtime());
    netOnline.addListener(_onNetChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkDetail());
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkRecovery());
  }

  @override
  void dispose() {
    netOnline.removeListener(_onNetChanged);
    unawaited(RealtimeSync.stop());
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Internet kembali setelah offline: sinkron ulang semua tab.
  void _onNetChanged() {
    if (mounted && netOnline.value) _reloadAll();
  }

  /// Langganan realtime org aktif; ledakan event → muat ulang semua tab.
  /// Ganti workspace = MainShell baru → resubscribe otomatis.
  Future<void> _ensureRealtime() async {
    if (!mounted) return;
    try {
      final orgId = await activeOrgId();
      if (!mounted || orgId.isEmpty) return;
      await RealtimeSync.ensure(
        orgId,
        onBurst: () {
          if (mounted) _reloadAll();
        },
      );
    } catch (_) {}
  }

  /// Muat ulang semua tab (dipakai burst realtime).
  void _reloadAll() {
    berandaKey.currentState?.reload();
    txKey.currentState?.reload();
    budgetKey.currentState?.reload();
    reportsKey.currentState?.reload();
  }

  /// Alert budget baru (mis. dicatat perangkat lain). Idempoten.
  Future<void> _checkBudgetAlerts() async {
    try {
      final orgId = await activeOrgId();
      if (!mounted || orgId.isEmpty) return;
      await BudgetAlertNotify.check(orgId);
    } catch (_) {}
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _resumed = true;
      unawaited(_checkRelock());
      NotifTrack.ensureListening(force: true);
      unawaited(ForegroundTrack.syncFromPrefs());
      // Realtime bisa putus saat background: pastikan ulang + muat ulang
      // (reload ini juga fallback bila realtime mati total).
      unawaited(_ensureRealtime());
      // Alert budget baru dari perangkat lain (idempoten, fail-silent).
      unawaited(_checkBudgetAlerts());
      unawaited(_checkDetail());
      _checkRecovery();
      // Poll budget alerts tiap resume supaya banner/badge segar
      // walau tab Budget sedang tidak aktif.
      budgetKey.currentState?.reload();
      _reloadTab(index);
    } else {
      _resumed = false;
      widget.session.touch();
    }
  }

  /// Kunci ulang saat kembali dari background melewati timeout
  /// (hanya bila PIN terpasang). Sebelumnya shouldRelock tak dipanggil
  /// siapa pun — timeout 5 menit cuma tulisan.
  Future<void> _checkRelock() async {
    if (!mounted) return;
    final session = widget.session;
    if (!session.hasPin) return;
    if (!session.shouldRelock(
      timeout: Duration(minutes: lockTimeoutMinutes.value),
    )) {
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LockScreen(session: session),
      ),
    );
    session.touch();
  }

  /// Link lupa-password diketuk saat app sudah masuk (hangat): arahkan ke
  /// layar password baru. Flag di-reset layar itu setelah tersimpan.
  void _checkRecovery() {
    if (!mounted || !passwordRecovery.value) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SetPasswordScreen(session: widget.session),
      ),
    );
  }

  /// Buka detail read-only bila ada ketuk notif tersimpan.  /// Prefs ditulis AutoSavedNotify saat notif tampil maupun diketuk.
  Future<void> _checkDetail() async {
    if (_detailOpen || !_resumed || !mounted) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final txId = prefs.getString(AutoSavedNotify.lastDetailKey);
      if (txId == null || txId.isEmpty || !mounted) return;
      final orgId = await activeOrgId();
      if (orgId.isEmpty || !mounted) return;
      final tx = await TransactionService().getById(orgId, txId);
      await prefs.remove(AutoSavedNotify.lastDetailKey);
      if (!mounted) return;
      if (tx == null) return;
      _detailOpen = true;
      final go = await showTxDetailSheet(context, tx, orgId);
      _detailOpen = false;
      if (go == true && mounted) _select(1);
    } catch (_) {
      _detailOpen = false;
    }
  }

  Future<void> _openInput() async {
    final mode = await showInputModeSheet(context);
    if (mode == null || !mounted) return;
    if (await openTxInputSheet(
      context,
      initialMode: mode == TxInputMode.live ? null : mode,
    )) {
      berandaKey.currentState?.reload();
      txKey.currentState?.reload();
      budgetKey.currentState?.reload();
      reportsKey.currentState?.reload();
    }
  }

  /// Profil dibuka sebagai route (bukan tab): avatar kiri-atas Beranda.
  /// Kembali dari Profil = muat ulang tab aktif (pengaturan bisa berubah).
  Future<void> _openProfil() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => OtherScreen(session: widget.session),
      ),
    );
    if (mounted) _reloadTab(index);
  }

  void _select(int i) {
    setState(() => index = i);
    _reloadTab(i);
  }

  /// Muat ulang tab yang dibuka supaya data baru (otomatis/manual)
  /// langsung tampil tanpa keluar-masuk app.
  void _reloadTab(int i) {
    if (i == 0) berandaKey.currentState?.reload();
    if (i == 1) txKey.currentState?.reload();
    if (i == 2) budgetKey.currentState?.reload();
    if (i == 3) reportsKey.currentState?.reload();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Column(
        children: [
          ValueListenableBuilder<bool>(
            valueListenable: netOnline,
            builder: (context, online, _) => online
                ? const SizedBox.shrink()
                : _OfflineBar(onRetry: () => _reloadAll()),
          ),
          Expanded(
            child: ValueListenableBuilder<bool>(
              valueListenable: maskAmounts,
              builder: (context, masked, child) => IndexedStack(
                index: index,
                children: [
                  BerandaScreen(
                    key: berandaKey,
                    onCatat: () => _select(1),
                    onBudget: () => _select(2),
                    onLaporan: () => _select(3),
                    onProfil: _openProfil,
                  ),
                  TransactionsScreen(key: txKey),
                  BudgetsScreen(key: budgetKey),
                  ReportsScreen(key: reportsKey),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openInput,
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        tooltip: tr('act_catat'),
        child: const DuoIcon(AppIcons.add),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      bottomNavigationBar: _MainBottomBar(index: index, onSelect: _select),
    );
  }
}

/// Strip offline global: data terakhir tersimpan + tombol muat ulang.
/// Muncul bila panggilan jaringan gagal (tanpa plugin konektivitas).
class _OfflineBar extends StatelessWidget {
  final VoidCallback onRetry;

  const _OfflineBar({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      color: scheme.error.withValues(alpha: 0.12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            Expanded(
              child: Text(
                tr('off_s'),
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: scheme.error),
              ),
            ),
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
              ),
              child: Text(tr('off_retry')),
            ),
          ],
        ),
      ),
    );
  }
}

/// Navigasi bawah 4 tab: bar surface, aktif primer, nonaktif sekunder.
class _MainBottomBar extends StatelessWidget {
  final int index;
  final ValueChanged<int> onSelect;

  const _MainBottomBar({required this.index, required this.onSelect});

  static List<NavigationDestination> get _destinations => [
    NavigationDestination(
      icon: const DuoIcon(AppIcons.home),
      label: tr('nav_beranda'),
    ),
    NavigationDestination(
      icon: const DuoIcon(AppIcons.transactions),
      label: tr('nav_transaksi'),
    ),
    NavigationDestination(
      icon: const DuoIcon(AppIcons.budget),
      label: tr('nav_budget'),
    ),
    NavigationDestination(
      icon: const DuoIcon(AppIcons.reports),
      label: tr('nav_laporan'),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final unselected =
        Theme.of(context).textTheme.bodySmall?.color ?? scheme.onSurface;
    return NavigationBarTheme(
      data: NavigationBarThemeData(
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? scheme.primary : unselected,
          );
        }),
      ),
      child: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: onSelect,
        indicatorColor: scheme.primary.withValues(alpha: 0.16),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected ? scheme.primary : unselected,
          );
        }),
        destinations: _destinations,
      ),
    );
  }
}
