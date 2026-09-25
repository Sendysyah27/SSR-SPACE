import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ssr_space/utils/mask.dart';
import 'package:ssr_space/services/foreground_track.dart';
import 'package:ssr_space/services/notif_track_service.dart';
import 'package:ssr_space/services/session_service.dart';
import 'package:ssr_space/theme/app_icons.dart';
import 'package:ssr_space/theme/app_theme.dart';
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // force: resubscribe bila stream sempat error / app resume dari background
    NotifTrack.ensureListening(force: true);
    unawaited(ForegroundTrack.syncFromPrefs());
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
      NotifTrack.ensureListening(force: true);
      unawaited(ForegroundTrack.syncFromPrefs());
    }
  }

  void _select(int i) {
    setState(() => index = i);
    if (i == 0) berandaKey.currentState?.reload();
    if (i == 2) budgetKey.currentState?.reload();
    if (i == 3) reportsKey.currentState?.reload();
  }

  @override
  Widget build(BuildContext context) {
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
            ),
            const TransactionsScreen(),
            BudgetsScreen(key: budgetKey),
            ReportsScreen(key: reportsKey),
            OtherScreen(session: widget.session),
          ],
        ),
      ),
      floatingActionButton: index == 1
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _select(1),
              backgroundColor: SsrColors.accent,
              foregroundColor: Colors.white,
              icon: const DuoIcon(AppIcons.add),
              label: const Text('Catat'),
            ),
      bottomNavigationBar: _MainBottomBar(index: index, onSelect: _select),
    );
  }
}

/// Navigasi bawah 5 tab dengan indikator & ikon zamrud saat aktif.
class _MainBottomBar extends StatelessWidget {
  final int index;
  final ValueChanged<int> onSelect;

  const _MainBottomBar({required this.index, required this.onSelect});

  static const List<NavigationDestination> _destinations = [
    NavigationDestination(icon: DuoIcon(AppIcons.home), label: 'Beranda'),
    NavigationDestination(
      icon: DuoIcon(AppIcons.transactions),
      label: 'Transaksi',
    ),
    NavigationDestination(icon: DuoIcon(AppIcons.budget), label: 'Budget'),
    NavigationDestination(icon: DuoIcon(AppIcons.reports), label: 'Laporan'),
    NavigationDestination(icon: DuoIcon(AppIcons.menu), label: 'Lainnya'),
  ];

  @override
  Widget build(BuildContext context) {
    return NavigationBarTheme(
      data: NavigationBarThemeData(
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? SsrColors.accent : SsrColors.secondary,
          );
        }),
      ),
      child: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: onSelect,
        backgroundColor: Colors.white,
        indicatorColor: SsrColors.accentSoft,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected ? SsrColors.accent : SsrColors.secondary,
          );
        }),
        destinations: _destinations,
      ),
    );
  }
}
