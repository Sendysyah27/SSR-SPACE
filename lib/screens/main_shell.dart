import 'package:flutter/material.dart';
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

  @override
  Widget build(BuildContext context) {
    final pages = [
      const BerandaScreen(),
      const TransactionsScreen(),
      const BudgetsScreen(),
      const ReportsScreen(),
      OtherScreen(session: widget.session),
    ];
    return Scaffold(
      body: IndexedStack(index: index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => setState(() => index = i),
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
