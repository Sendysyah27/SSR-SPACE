import 'package:flutter/material.dart';
import 'package:ssr_space/core/saas/notif_track_service.dart';
import 'package:ssr_space/core/session/session_service.dart';
import 'package:ssr_space/screens/beranda_screen.dart';
import 'package:ssr_space/screens/budgets_screen.dart';
import 'package:ssr_space/screens/other_screen.dart';
import 'package:ssr_space/screens/reports_screen.dart';
import 'package:ssr_space/screens/transactions_screen.dart';

class MainShell extends StatefulWidget {
  final SessionService session;
  const MainShell({super.key, required this.session});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int index = 0;
  final berandaKey = GlobalKey<BerandaScreenState>();
  final budgetKey = GlobalKey<BudgetsScreenState>();
  final reportsKey = GlobalKey<ReportsScreenState>();

  @override
  void initState() {
    super.initState();
    // force: resubscribe bila stream sempat error / app resume dari background
    NotifTrack.ensureListening(force: true);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      NotifTrack.ensureListening(force: true);
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
      body: IndexedStack(index: index, children: [
        BerandaScreen(key: berandaKey),
        const TransactionsScreen(),
        BudgetsScreen(key: budgetKey),
        ReportsScreen(key: reportsKey),
        OtherScreen(session: widget.session),
      ]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: _select,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Beranda'),
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long), label: 'Transaksi'),
          NavigationDestination(icon: Icon(Icons.savings_outlined), selectedIcon: Icon(Icons.savings), label: 'Budget'),
          NavigationDestination(icon: Icon(Icons.bar_chart_outlined), selectedIcon: Icon(Icons.bar_chart), label: 'Laporan'),
          NavigationDestination(icon: Icon(Icons.grid_view_outlined), selectedIcon: Icon(Icons.grid_view), label: 'Lainnya'),
        ],
      ),
    );
  }
}
