import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ssr_space/utils/mask.dart';
import 'package:ssr_space/services/app_settings.dart';
import 'package:ssr_space/services/auto_saved_notify.dart';
import 'package:ssr_space/services/error_reporter.dart';
import 'package:ssr_space/services/foreground_track.dart';
import 'package:ssr_space/services/notif_track_service.dart';
import 'package:ssr_space/services/session_service.dart';
import 'package:ssr_space/services/transaction_service.dart';
import 'package:ssr_space/theme/app_icons.dart';
import 'package:ssr_space/utils/org_prefs.dart';
import 'package:ssr_space/utils/strings.dart';
import 'package:ssr_space/widgets/tx_detail_sheet.dart';
import 'package:ssr_space/widgets/tx_input_sheet.dart';
import 'package:ssr_space/screens/auth/lock_screen.dart';
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
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkDetail());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _resumed = true;
      unawaited(_checkRelock());
      NotifTrack.ensureListening(force: true);
      unawaited(ForegroundTrack.syncFromPrefs());
      unawaited(_checkDetail());
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
  /// (hanya bila PIN terpasang). Guard anti-tumpuk: resume cepat
  /// beruntun tak boleh menumpuk layar kunci.
  bool _lockOpen = false;

  Future<void> _checkRelock() async {
    if (!mounted || _lockOpen) return;
    final session = widget.session;
    if (!session.hasPin) return;
    if (!session.shouldRelock(
      timeout: Duration(minutes: lockTimeoutMinutes.value),
    )) {
      return;
    }
    _lockOpen = true;
    try {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => LockScreen(session: session),
        ),
      );
    } catch (err, st) {
      await ErrorReporter.capture(err, st, context: 'relock_nav');
    } finally {
      _lockOpen = false;
      session.touch();
    }
  }

  /// Buka detail read-only bila ada ketuk notif tersimpan.
  /// Prefs ditulis AutoSavedNotify saat notif tampil maupun diketuk.
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
    if (await openTxInputSheet(context)) {
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
      body: ValueListenableBuilder<bool>(
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
