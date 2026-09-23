import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ssr_space/core/saas/supabase_config.dart';
import 'package:ssr_space/core/session/session_service.dart';
import 'package:ssr_space/screens/org_switcher_screen.dart';
import 'package:ssr_space/screens/splash_screen.dart';
import 'package:ssr_space/screens/wallets_screen.dart';
import 'package:ssr_space/screens/transactions_screen.dart';

class HomeScreen extends StatelessWidget {
  final SessionService session;
  const HomeScreen({super.key, required this.session});

  Future<String> _orgName() async {
    final p = await SharedPreferences.getInstance();
    return p.getString('active_org_name') ?? '-';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SSR SPACE'),
        actions: [
          IconButton(icon: const Icon(Icons.swap_horiz), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => OrgSwitcherScreen(session: session)))),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await SupabaseConfig.client.auth.signOut();
              final p = await SharedPreferences.getInstance();
              await p.remove('active_org_id');
              if (!context.mounted) return;
              Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => SplashScreen(session: session)), (_) => false);
            },
          ),
        ],
      ),
      body: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          FutureBuilder<String>(future: _orgName(), builder: (_, s) => Text('Org: ${s.data ?? '-'} | Sesi: ${session.sessionId.substring(0, 8)}...')),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WalletsScreen())), child: const Text('Dompet')),
          ElevatedButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TransactionsScreen())), child: const Text('Transaksi')),
        ]),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TransactionsScreen())),
        child: const Icon(Icons.add),
      ),
    );
  }
}
